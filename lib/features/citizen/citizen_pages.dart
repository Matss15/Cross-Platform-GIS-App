part of '../../app.dart';

class CitizenDashboard extends StatelessWidget {
  const CitizenDashboard({super.key, this.onReportFire});

  /// Opens the Report tab.
  final VoidCallback? onReportFire;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Panel(
          child: SectionTitle(
            title: 'Citizen Emergency Dashboard',
            subtitle:
                'Report emergencies with your location and help responders act quickly.',
          ),
        ),
        const SizedBox(height: 18),
        const CitizenStatusSummary(),
        const SizedBox(height: 18),
        LayoutSwitcher(
          left: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Emergency actions',
                  subtitle: 'Start a report with location and evidence.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onReportFire,
                  icon: const Icon(Icons.local_fire_department_rounded),
                  label: const Text('Report Fire'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.fire,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => callRosarioFireStation(context),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call Rosario Fire Station'),
                ),
                const SizedBox(height: 18),
                const SafetyTipCard(),
              ],
            ),
          ),
          right: Column(
            children: [
              MapPreview(accent: AppColors.fire, height: 380, ownOnly: true),
              const SizedBox(height: 14),
              const IncidentFeed(title: 'My incident reports', ownOnly: true),
            ],
          ),
        ),
      ],
    );
  }
}

class CitizenStatusSummary extends StatelessWidget {
  const CitizenStatusSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = appAuth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appDb
          .collection('incidents')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        var pending = 0;
        var verified = 0;
        var resolved = 0;
        for (final doc in docs) {
          final status = textField(doc.data(), 'status').toLowerCase();
          if (status == 'pending') pending++;
          if (status == 'verified') verified++;
          if (status == 'resolved' ||
              status == 'contained' ||
              status == 'closed') {
            resolved++;
          }
        }

        return ResponsiveGrid(
          minTileWidth: 190,
          children: [
            MetricTile(
              title: 'My reports',
              value: docs.length.toString(),
              helper: 'Submitted incidents',
              icon: Icons.receipt_long_rounded,
              color: AppColors.fire,
            ),
            MetricTile(
              title: 'Pending review',
              value: pending.toString(),
              helper: 'Awaiting validation',
              icon: Icons.hourglass_top_rounded,
              color: AppColors.amber,
            ),
            MetricTile(
              title: 'Verified reports',
              value: verified.toString(),
              helper: 'Confirmed by responders',
              icon: Icons.verified_rounded,
              color: AppColors.blue,
            ),
            MetricTile(
              title: 'Resolved',
              value: resolved.toString(),
              helper: 'Closed incidents',
              icon: Icons.task_alt_rounded,
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }
}

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({super.key, required this.role});

  final UserRole role;

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'Structural fire';
  String _urgency = 'High';
  String _selectedBarangay = rosarioBarangays.first;
  LatLng? _selectedIncidentPoint;
  String? _evidenceDataUrl;
  String? _evidenceName;
  bool _isSubmitting = false;
  bool _isResolvingBarangay = false;
  String? _errorText;

  // AI photo triage. The AI severity is the lowest urgency allowed.
  bool _urgencyTouched = false;
  bool _isAssessing = false;
  int _assessmentRun = 0;
  Future<void>? _assessment;
  Map<String, dynamic>? _aiAssessment;

  // Where the pin came from: none, manual (map drag or tap), gps, or search.
  String _pinSource = 'none';
  bool _isLocating = false;
  String? _locationHint;
  Timer? _addressSearchDebounce;
  List<PlaceSuggestion> _placeSuggestions = const [];
  bool _isSearchingPlaces = false;

  @override
  void initState() {
    super.initState();
    // Pins silently when location access was granted before; never prompts.
    _locateWithGps(askPermission: false);
  }

  String? get _aiFloor {
    final ai = _aiAssessment;
    return ai != null && ai['status'] == 'completed'
        ? ai['severity'] as String
        : null;
  }

  @override
  void dispose() {
    _addressSearchDebounce?.cancel();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required.';
    return null;
  }

  Future<void> _chooseEvidenceSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: const Text('Use camera'),
                  subtitle: const Text('Take a new incident photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Attach photo'),
                  subtitle: const Text('Choose an existing photo'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;
    await _pickEvidence(source);
  }

  Future<void> _pickEvidence(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 55,
      maxWidth: 1400,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    // Keep the encoded image well below Firestore's 1 MiB document limit.
    if (bytes.length > 450 * 1024) {
      if (!mounted) return;
      setState(() {
        _errorText =
            'Selected image is too large. Please choose a photo under 450 KB.';
      });
      return;
    }

    setState(() {
      _evidenceName = picked.name;
      _evidenceDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _errorText = null;
      _isAssessing = true;
      _aiAssessment = null;
    });
    _assessment = _assessPhoto(++_assessmentRun, bytes);
  }

  /// Runs while the citizen finishes the form, so submitting is not delayed.
  Future<void> _assessPhoto(int run, Uint8List bytes) async {
    Map<String, dynamic> assessment;
    try {
      final ai = await assessIncidentPhotoWithGemini(
        imageBytes: bytes,
        description: _descriptionController.text.trim(),
      ).timeout(const Duration(seconds: 20));
      final severity = ai['severity'];
      final type = ai['incidentType'];
      final reason = '${ai['reason'] ?? ''}'.trim();
      assessment = {
        'status': 'completed',
        // An unreadable severity errs on the loud side.
        'severity': incidentUrgencies.contains(severity) ? severity : 'High',
        'isEmergency': ai['isEmergency'] != false,
        'incidentType': incidentTypes.contains(type) ? type : '',
        'reason': reason.length > 300 ? reason.substring(0, 300) : reason,
        'model': idReviewModel,
      };
    } catch (_) {
      // No AI (offline, quota, bad reply): the citizen's own choice is used.
      assessment = {'status': 'error'};
    }
    if (!mounted || run != _assessmentRun) return;
    setState(() {
      _isAssessing = false;
      _aiAssessment = assessment;
      final floor = _aiFloor;
      if (floor == null) return;
      if (!_urgencyTouched || urgencyRank(_urgency) < urgencyRank(floor)) {
        _urgency = floor;
      }
      final type = assessment['incidentType'] as String;
      if (type.isNotEmpty) _type = type;
    });
  }

  void _setPin(LatLng point, String source, {bool fillAddress = false}) {
    setState(() {
      _selectedIncidentPoint = point;
      _selectedBarangay = '';
      _pinSource = source;
      _errorText = null;
    });
    _resolveBarangayFromPin(point, fillAddress: fillAddress);
  }

  Future<void> _locateWithGps({bool askPermission = true}) async {
    void hint(String text) {
      if (askPermission && mounted) setState(() => _locationHint = text);
    }

    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied && askPermission) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        hint('Payagan ang location access para ma-auto pin.');
        return;
      }
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        hint('I-on ang Location/GPS ng phone.');
        return;
      }
      if (mounted) setState(() => _isLocating = true);
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      if (!rosarioBounds.contains(point)) {
        hint(
          'Nasa labas ng Rosario ang location mo. Hanapin ang lugar o '
          'i-drag ang mapa.',
        );
        return;
      }
      // The silent startup attempt must not replace a pin placed meanwhile.
      if (!askPermission && _pinSource != 'none') return;
      _setPin(point, 'gps', fillAddress: true);
      setState(() {
        _locationHint =
            'Na-pin gamit ang GPS (±${position.accuracy.round()} m). '
            'I-drag ang mapa para ayusin.';
      });
    } catch (_) {
      hint(
        'Hindi makuha ang GPS location. Hanapin ang lugar o i-drag ang mapa.',
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Looks up places as the citizen types, e.g. "mcdo rosario", and lists
  /// them under the field. Nothing is pinned until one is picked.
  void _onLocationTextChanged(String value) {
    _addressSearchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _placeSuggestions = const [];
        _isSearchingPlaces = false;
      });
      return;
    }
    setState(() => _isSearchingPlaces = true);
    _addressSearchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    final results = await searchRosarioPlaces(query);
    // Ignore replies for text the citizen has already changed.
    if (!mounted || _locationController.text.trim() != query) return;
    setState(() {
      _isSearchingPlaces = false;
      _placeSuggestions = results;
      _locationHint = results.isEmpty
          ? 'Walang nahanap. Subukan ang ibang pangalan o i-drag ang mapa.'
          : null;
    });
  }

  void _pickPlace(PlaceSuggestion place) {
    _addressSearchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    _locationController.text = place.addressText;
    _setPin(place.point, 'search');
    setState(() {
      _placeSuggestions = const [];
      _isSearchingPlaces = false;
      _locationHint =
          'Na-pin: ${place.title}. I-drag ang mapa kung hindi eksakto.';
    });
  }

  /// Enter picks the top suggestion.
  Future<void> _onLocationSubmitted(String value) async {
    final query = value.trim();
    if (query.length < 3) return;
    if (_placeSuggestions.isNotEmpty) {
      _pickPlace(_placeSuggestions.first);
      return;
    }
    _addressSearchDebounce?.cancel();
    setState(() => _isSearchingPlaces = true);
    await _searchPlaces(query);
    if (mounted && _placeSuggestions.isNotEmpty) {
      _pickPlace(_placeSuggestions.first);
    }
  }

  Widget _buildPlaceSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.muted.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          for (final place in _placeSuggestions)
            ListTile(
              dense: true,
              leading: const Icon(Icons.place_rounded, color: AppColors.fire),
              title: Text(
                place.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: place.subtitle.isEmpty
                  ? null
                  : Text(
                      place.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => _pickPlace(place),
            ),
        ],
      ),
    );
  }

  Future<void> _resolveBarangayFromPin(
    LatLng point, {
    bool fillAddress = false,
  }) async {
    setState(() => _isResolvingBarangay = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toStringAsFixed(6),
        'lon': point.longitude.toStringAsFixed(6),
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'BFP-Rosario-GIS/1.0'},
      );
      if (response.statusCode != 200) return;

      final payload = jsonDecode(response.body);
      final address = payload is Map<String, dynamic>
          ? payload['address']
          : null;
      if (address is! Map) return;

      if (fillAddress && mounted && _locationController.text.trim().isEmpty) {
        // Setting the text programmatically does not fire onChanged, so this
        // cannot trigger an address search that moves the GPS pin.
        _locationController.text = [
          address['road'],
          address['village'] ?? address['suburb'] ?? address['neighbourhood'],
          'Rosario, Batangas',
        ].whereType<String>().join(', ');
      }

      final candidates = [
        address['village'],
        address['suburb'],
        address['neighbourhood'],
        address['town'],
      ].whereType<String>().map((value) => value.trim().toLowerCase());
      final match = rosarioBarangays.firstWhere(
        (barangay) => candidates.contains(barangay.toLowerCase()),
        orElse: () => '',
      );
      if (!mounted || match.isEmpty) return;
      setState(() => _selectedBarangay = match);
    } catch (_) {
      // A temporary geocoder/network failure must not discard the selected pin.
    } finally {
      if (mounted) setState(() => _isResolvingBarangay = false);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final incidentPoint = _selectedIncidentPoint;
    if (incidentPoint == null) {
      setState(() {
        _errorText = 'Select the exact incident location on the map.';
      });
      return;
    }
    if (_selectedBarangay.isEmpty) {
      setState(() {
        _errorText =
            'Hindi pa matukoy ang barangay ng pin. Ilipat nang kaunti ang pin at subukan muli.';
      });
      return;
    }

    final user = appAuth.currentUser;
    if (user == null) {
      setState(() {
        _errorText = 'Sign in before submitting a report.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // Wait for a photo check still in progress (it times out by itself).
      if (_isAssessing) await _assessment;
      final floor = _aiFloor;
      final priority =
          floor != null && urgencyRank(floor) > urgencyRank(_urgency)
          ? floor
          : _urgency;
      final type = _type;

      final profile = await appDb.collection('users').doc(user.uid).get();
      final data = profile.data();
      final reporterName = textField(
        data,
        'fullName',
        user.displayName ?? 'Reporter',
      );
      final phone = textField(data, 'phone');
      final address = _locationController.text.trim();

      final doc = appDb.collection('incidents').doc();
      await doc.set({
        'id': doc.id,
        'uid': user.uid,
        'reporterId': user.uid,
        'reporterName': reporterName,
        'phone': phone,
        'address': address,
        'description': _descriptionController.text.trim(),
        'latitude': incidentPoint.latitude,
        'longitude': incidentPoint.longitude,
        'barangayId': barangayIdFor(_selectedBarangay),
        'barangayName': _selectedBarangay,
        'type': type,
        'priority': priority,
        'aiAssessment': _aiAssessment ?? {'status': 'none'},
        'status': 'Pending',
        'assignedTo': '',
        'assignedResponder': '',
        'verifiedBy': '',
        'evidenceImage': _evidenceDataUrl ?? '',
        'evidenceFileName': _evidenceName ?? '',
        'hasEvidence': _evidenceDataUrl != null,
        'evidenceUploadedAt': _evidenceDataUrl == null
            ? null
            : FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await writeActivityLog(
        action: 'Created incident report',
        targetId: doc.id,
        targetLabel: type,
        metadata: {
          'barangayName': _selectedBarangay,
          'priority': priority,
          'aiSeverity': floor ?? '',
          'latitude': incidentPoint.latitude,
          'longitude': incidentPoint.longitude,
          'hasEvidence': _evidenceDataUrl != null,
        },
      );

      if (!mounted) return;
      _formKey.currentState!.reset();
      _locationController.clear();
      _descriptionController.clear();
      setState(() {
        _placeSuggestions = const [];
        _type = 'Structural fire';
        _urgency = 'High';
        _selectedBarangay = rosarioBarangays.first;
        _selectedIncidentPoint = null;
        _pinSource = 'none';
        _locationHint = null;
        _evidenceDataUrl = null;
        _evidenceName = null;
        _urgencyTouched = false;
        _isAssessing = false;
        _assessmentRun++;
        _assessment = null;
        _aiAssessment = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submitted $priority priority $type report'),
          backgroundColor: widget.role.accent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = safeErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildAiAssessment() {
    if (_isAssessing) {
      return const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sinusuri ng AI ang litrato...',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      );
    }
    final ai = _aiAssessment!;
    final severity = _aiFloor;
    if (severity == null) {
      return const Text(
        'Hindi nasuri ng AI ang litrato. Piliin ang urgency nang manu-mano.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    final color = colorForIncident(priority: severity, status: 'Pending');
    final reason = ai['reason'] as String;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI label: $severity',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[const SizedBox(height: 6), Text(reason)],
          if (ai['isEmergency'] == false) ...[
            const SizedBox(height: 6),
            const Text(
              'Hindi mukhang totoong emergency ang litrato. Mamarkahan ito '
              'para masuri ng BFP.',
              style: TextStyle(
                color: AppColors.fire,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Puwede mong itaas ang urgency, pero hindi ibaba sa $severity.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutSwitcher(
      leftFlex: 7,
      rightFlex: 5,
      left: Panel(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'Create incident report',
                subtitle:
                    'Capture the location, fire type, and supporting notes.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                // Rebuilt when the AI fills in the type.
                key: ValueKey('incident-type-$_type'),
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Incident type',
                  prefixIcon: Icon(Icons.local_fire_department_rounded),
                ),
                items: incidentTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBarangay.isEmpty
                    ? null
                    : _selectedBarangay,
                decoration: const InputDecoration(
                  labelText: 'Barangay detected from pin',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: rosarioBarangays
                    .map(
                      (barangay) => DropdownMenuItem(
                        value: barangay,
                        child: Text(barangay),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (_selectedIncidentPoint != null) return;
                  setState(
                    () => _selectedBarangay = value ?? _selectedBarangay,
                  );
                },
              ),
              if (_isResolvingBarangay) ...[
                const SizedBox(height: 6),
                const Text(
                  'Detecting barangay from the selected pin...',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                validator: (value) => _required(value, 'Location'),
                onChanged: _onLocationTextChanged,
                onFieldSubmitted: _onLocationSubmitted,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Location',
                  hintText: 'Hanapin: mcdo rosario, palengke, kalye...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _isSearchingPlaces
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (_placeSuggestions.isNotEmpty) _buildPlaceSuggestions(),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _isLocating || _isSubmitting
                        ? null
                        : () => _locateWithGps(),
                    icon: _isLocating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      _isLocating ? 'Hinahanap ka...' : 'Gamitin ang GPS ko',
                    ),
                  ),
                  if (_locationHint != null)
                    Text(
                      _locationHint!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              IncidentLocationPicker(
                selectedPoint: _selectedIncidentPoint,
                accent: AppColors.fire,
                height: 320,
                onChanged: (point) {
                  _addressSearchDebounce?.cancel();
                  _setPin(point, 'manual', fillAddress: true);
                  setState(() {
                    _placeSuggestions = const [];
                    _isSearchingPlaces = false;
                    _locationHint = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                validator: (value) => _required(value, 'Description'),
                minLines: 4,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'Describe visible smoke, hazards, trapped persons...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _chooseEvidenceSource,
                icon: const Icon(Icons.add_a_photo_rounded),
                label: Text(
                  _evidenceName == null
                      ? 'Camera or attach photo'
                      : 'Change photo',
                ),
              ),
              if (_evidenceName != null) ...[
                const SizedBox(height: 8),
                Text(
                  _evidenceName!,
                  style: const TextStyle(color: AppColors.success),
                ),
              ],
              if (_isAssessing || _aiAssessment != null) ...[
                const SizedBox(height: 10),
                _buildAiAssessment(),
              ],
              const SizedBox(height: 16),
              Text(
                'Urgency',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                selected: {_urgency},
                showSelectedIcon: false,
                onSelectionChanged: (value) {
                  setState(() {
                    _urgency = value.first;
                    _urgencyTouched = true;
                  });
                },
                segments: [
                  for (final urgency in incidentUrgencies)
                    ButtonSegment(
                      value: urgency,
                      label: Text(urgency),
                      // Below the AI label is locked: raise only, never lower.
                      enabled:
                          _aiFloor == null ||
                          urgencyRank(urgency) >= urgencyRank(_aiFloor!),
                    ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppColors.fire,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitReport,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit report'),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.role.accent,
                ),
              ),
            ],
          ),
        ),
      ),
      right: Column(
        children: [
          EvidencePanel(
            fileName: _evidenceName,
            dataUrl: _evidenceDataUrl,
            locationText: _selectedIncidentPoint == null
                ? null
                : '${_selectedIncidentPoint!.latitude.toStringAsFixed(6)}, '
                      '${_selectedIncidentPoint!.longitude.toStringAsFixed(6)}',
          ),
        ],
      ),
    );
  }
}
