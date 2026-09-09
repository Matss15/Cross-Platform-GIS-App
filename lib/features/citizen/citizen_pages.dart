part of '../../app.dart';

class CitizenDashboard extends StatelessWidget {
  const CitizenDashboard({super.key});

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
                  onPressed: () {
                    DefaultTabController.maybeOf(context)?.animateTo(1);
                  },
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

  @override
  void dispose() {
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
    });
  }

  Future<void> _resolveBarangayFromPin(LatLng point) async {
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
        'type': _type,
        'priority': _urgency,
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
        targetLabel: _type,
        metadata: {
          'barangayName': _selectedBarangay,
          'priority': _urgency,
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
        _type = 'Structural fire';
        _urgency = 'High';
        _selectedBarangay = rosarioBarangays.first;
        _selectedIncidentPoint = null;
        _evidenceDataUrl = null;
        _evidenceName = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submitted $_urgency priority $_type report'),
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
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Incident type',
                  prefixIcon: Icon(Icons.local_fire_department_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Structural fire',
                    child: Text('Structural fire'),
                  ),
                  DropdownMenuItem(
                    value: 'Grass fire',
                    child: Text('Grass fire'),
                  ),
                  DropdownMenuItem(
                    value: 'Vehicle fire',
                    child: Text('Vehicle fire'),
                  ),
                  DropdownMenuItem(
                    value: 'Rescue assistance',
                    child: Text('Rescue assistance'),
                  ),
                ],
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
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Street, barangay, landmark',
                  prefixIcon: Icon(Icons.place_rounded),
                ),
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
                  setState(() => _urgency = value.first);
                },
                segments: const [
                  ButtonSegment(value: 'Low', label: Text('Low')),
                  ButtonSegment(value: 'High', label: Text('High')),
                  ButtonSegment(value: 'Critical', label: Text('Critical')),
                ],
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
          IncidentLocationPicker(
            selectedPoint: _selectedIncidentPoint,
            accent: AppColors.fire,
            height: 300,
            onChanged: (point) {
              setState(() {
                _selectedIncidentPoint = point;
                _selectedBarangay = '';
                _errorText = null;
              });
              _resolveBarangayFromPin(point);
            },
          ),
          const SizedBox(height: 14),
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
