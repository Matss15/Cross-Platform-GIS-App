part of '../../app.dart';

class IncidentMapPage extends StatelessWidget {
  const IncidentMapPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            StatusPill(
              label: 'All incidents',
              icon: Icons.layers_rounded,
              color: role.accent,
            ),
            const StatusPill(
              label: 'Verified',
              icon: Icons.verified_rounded,
              color: AppColors.success,
            ),
            const StatusPill(
              label: 'Pending',
              icon: Icons.pending_actions_rounded,
              color: AppColors.amber,
            ),
            const StatusPill(
              label: 'Critical',
              icon: Icons.priority_high_rounded,
              color: AppColors.fire,
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutSwitcher(
          leftFlex: 7,
          rightFlex: 4,
          left: MapPreview(accent: role.accent, height: 510),
          right: const IncidentFeed(title: 'Map incident list'),
        ),
      ],
    );
  }
}

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return DashboardCountsBuilder(
      builder: (context, counts) {
        final verificationRate = counts.incidents == 0
            ? 0
            : ((counts.verified + counts.resolved) / counts.incidents * 100)
                  .round();

        return Column(
          children: [
            ResponsiveGrid(
              children: [
                MetricTile(
                  title: 'Verification rate',
                  value: '$verificationRate%',
                  helper: 'Validated from submitted reports',
                  icon: Icons.verified_rounded,
                  color: role.accent,
                ),
                MetricTile(
                  title: 'Pending reports',
                  value: counts.pending.toString(),
                  helper: 'Awaiting barangay validation',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.amber,
                ),
                MetricTile(
                  title: 'Critical',
                  value: counts.critical.toString(),
                  helper: 'Priority marked critical',
                  icon: Icons.priority_high_rounded,
                  color: AppColors.fire,
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutSwitcher(
              equalHeight: true,
              left: Panel(child: DashboardChart(values: counts.weeklyCounts)),
              right: CategoryPanel(categoryCounts: counts.categoryCounts),
            ),
            const SizedBox(height: 18),
            BarangayIncidentAnalyticsPanel(accent: role.accent),
          ],
        );
      },
    );
  }
}

class BarangayIncidentAnalyticsPanel extends StatelessWidget {
  const BarangayIncidentAnalyticsPanel({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Incidents per barangay',
            subtitle: 'Live report totals grouped by incident location.',
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb.collection('incidents').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Text(
                  'Unable to load barangay incident totals.',
                  style: TextStyle(color: AppColors.fire),
                );
              }

              final counts = countIncidentsByBarangay(
                (snapshot.data?.docs ?? const []).map((doc) => doc.data()),
              );
              final entries =
                  counts.entries.where((entry) => entry.value > 0).toList()
                    ..sort((a, b) {
                      final countOrder = b.value.compareTo(a.value);
                      return countOrder != 0
                          ? countOrder
                          : a.key.compareTo(b.key);
                    });
              final total = entries.fold<int>(
                0,
                (runningTotal, entry) => runningTotal + entry.value,
              );

              if (entries.isEmpty) {
                return const Text(
                  'No barangay incident reports yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              return AppDataTable(
                columns: const [
                  DataColumn(label: Text('Barangay')),
                  DataColumn(label: Text('Incident reports')),
                  DataColumn(label: Text('Share')),
                ],
                rows: [
                  for (final entry in entries)
                    DataRow(
                      cells: [
                        DataCell(AppTableText(entry.key)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 18,
                                color: accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text('${(entry.value / total * 100).round()}%'),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.role, required this.onSignOut});

  final UserRole role;
  final VoidCallback onSignOut;

  Future<void> _openEditDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditBiodataDialog(role: role, initialData: data),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Biodata updated.'),
          backgroundColor: role.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = appAuth.currentUser;
    if (user == null) {
      return const Panel(
        child: SectionTitle(
          title: 'Profile unavailable',
          subtitle: 'Sign in before viewing biodata.',
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: appDb.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Panel(child: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data?.data() ?? {};
        final fullName = textField(
          data,
          'fullName',
          user.displayName ?? role.label,
        );
        final email = textField(data, 'email', user.email ?? '-');
        final phone = textField(data, 'phone', '-');
        final address = textField(data, 'address', '-');
        final barangay = textField(data, 'barangayName', '-');
        final birthdate = textField(data, 'birthdate', '-');
        final emergencyName = textField(data, 'emergencyContactName', '-');
        final emergencyPhone = textField(data, 'emergencyContactPhone', '-');
        final biodata = textField(data, 'biodata', 'No biodata notes yet.');

        return LayoutSwitcher(
          left: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: role.accent.withValues(alpha: 0.2),
                      child: Icon(role.icon, color: role.accent, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role.label,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ProfileInfoRow(
                  icon: Icons.mail_rounded,
                  label: 'Email',
                  value: email,
                  color: role.accent,
                ),
                ProfileInfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Contact number',
                  value: phone,
                  color: AppColors.success,
                ),
                ProfileInfoRow(
                  icon: Icons.location_city_rounded,
                  label: 'Barangay',
                  value: barangay,
                  color: AppColors.amber,
                ),
                ProfileInfoRow(
                  icon: Icons.home_rounded,
                  label: 'Address',
                  value: address,
                  color: AppColors.teal,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openEditDialog(context, data),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit biodata'),
                  style: FilledButton.styleFrom(backgroundColor: role.accent),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
          right: Column(
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      title: 'Biodata',
                      subtitle: 'Personal and emergency details for this user.',
                    ),
                    const SizedBox(height: 14),
                    ProfileInfoRow(
                      icon: Icons.cake_rounded,
                      label: 'Birthdate',
                      value: birthdate,
                      color: AppColors.purple,
                    ),
                    ProfileInfoRow(
                      icon: Icons.contact_emergency_rounded,
                      label: 'Emergency contact',
                      value: emergencyName,
                      color: AppColors.fire,
                    ),
                    ProfileInfoRow(
                      icon: Icons.local_phone_rounded,
                      label: 'Emergency phone',
                      value: emergencyPhone,
                      color: AppColors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      biodata,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const IncidentFeed(title: 'My recent activity'),
            ],
          ),
        );
      },
    );
  }
}

class EditBiodataDialog extends StatefulWidget {
  const EditBiodataDialog({
    super.key,
    required this.role,
    required this.initialData,
  });

  final UserRole role;
  final Map<String, dynamic> initialData;

  @override
  State<EditBiodataDialog> createState() => _EditBiodataDialogState();
}

class _EditBiodataDialogState extends State<EditBiodataDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _biodataController = TextEditingController();

  late String _selectedBarangay;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _nameController.text = textField(data, 'fullName');
    _phoneController.text = textField(data, 'phone');
    _addressController.text = textField(data, 'address');
    _birthdateController.text = textField(data, 'birthdate');
    _emergencyNameController.text = textField(data, 'emergencyContactName');
    _emergencyPhoneController.text = textField(data, 'emergencyContactPhone');
    _biodataController.text = textField(data, 'biodata');
    final currentBarangay = textField(data, 'barangayName');
    _selectedBarangay = rosarioBarangays.contains(currentBarangay)
        ? currentBarangay
        : rosarioBarangays.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdateController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _biodataController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required.';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = appAuth.currentUser;
    if (user == null) {
      setState(() => _errorText = 'Sign in before editing biodata.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final fullName = _nameController.text.trim();
      await user.updateDisplayName(fullName);

      final roleName = textField(
        widget.initialData,
        'role',
        firestoreRoleFor(widget.role),
      );

      await appDb.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName,
        'email': textField(widget.initialData, 'email', user.email ?? ''),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'role': roleName,
        'barangayId': barangayIdFor(_selectedBarangay),
        'barangayName': _selectedBarangay,
        'birthdate': _birthdateController.text.trim(),
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
        'biodata': _biodataController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await writeAccountEmailIndex(
        uid: user.uid,
        email: textField(widget.initialData, 'email', user.email ?? ''),
        fullName: fullName,
        role: roleName,
        adminLevel: textField(widget.initialData, 'adminLevel'),
      );

      await writeActivityLog(
        action: 'Updated biodata',
        targetId: user.uid,
        targetLabel: fullName,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = safeErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(
                  title: 'Edit biodata',
                  subtitle: 'Update personal and emergency information.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _required(value, 'Full name'),
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _required(value, 'Contact number'),
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBarangay,
                  decoration: const InputDecoration(
                    labelText: 'Barangay',
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
                    setState(
                      () => _selectedBarangay = value ?? _selectedBarangay,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _required(value, 'Address'),
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.home_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthdateController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Birthdate',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.cake_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Emergency contact name',
                    prefixIcon: Icon(Icons.contact_emergency_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Emergency contact phone',
                    prefixIcon: Icon(Icons.local_phone_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _biodataController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Biodata notes',
                    alignLabelWithHint: true,
                  ),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving ? 'Saving...' : 'Save biodata'),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.role.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SafetyTipCard extends StatelessWidget {
  const SafetyTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fire.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.fire.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_rounded, color: AppColors.fire),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keep exits clear and turn off LPG tanks before leaving the house.',
              style: TextStyle(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

ImageProvider? imageProviderFromDataUrl(String? dataUrl) {
  if (dataUrl == null || !dataUrl.contains(',')) return null;
  try {
    return MemoryImage(base64Decode(dataUrl.split(',').last));
  } on FormatException {
    return null;
  }
}

class EvidencePanel extends StatelessWidget {
  const EvidencePanel({
    super.key,
    this.fileName,
    this.dataUrl,
    this.locationText,
    this.readOnly = false,
  });

  final String? fileName;
  final String? dataUrl;
  final String? locationText;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromDataUrl(dataUrl);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: readOnly ? 'Incident evidence' : 'Evidence preview',
            subtitle: readOnly
                ? 'Citizen-submitted photo and incident coordinates.'
                : 'Review the attachment before submission.',
          ),
          const SizedBox(height: 14),
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(
                image: image,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
          ],
          ResourceCard(
            icon: Icons.photo_camera_rounded,
            title: 'Photo evidence',
            subtitle: fileName ?? 'No file attached',
            color: AppColors.fire,
          ),
          const SizedBox(height: 10),
          ResourceCard(
            icon: Icons.my_location_rounded,
            title: 'Incident pin',
            subtitle: locationText ?? 'No exact incident pin selected',
            color: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

class IncidentFeed extends StatelessWidget {
  const IncidentFeed({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: title,
            subtitle: 'Prioritized incident feed from Rosario GIS.',
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb
                .collection('incidents')
                .orderBy('createdAt', descending: true)
                .limit(12)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text(
                  safeErrorMessage(snapshot.error!),
                  style: const TextStyle(color: AppColors.fire),
                );
              }

              final incidents =
                  snapshot.data?.docs.map(Incident.fromDocument).toList() ?? [];

              if (incidents.isEmpty) {
                return const Text(
                  'No incident records yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              return Column(
                children: incidents
                    .map(
                      (incident) => IncidentRow(
                        incident: incident,
                        actionLabel: 'Open',
                        color: incident.color,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class IncidentRow extends StatelessWidget {
  const IncidentRow({
    super.key,
    required this.incident,
    required this.actionLabel,
    required this.color,
    this.onAction,
  });

  final Incident incident;
  final String actionLabel;
  final Color color;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_fire_department_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  incident.location,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      label: incident.priority,
                      icon: Icons.flag_rounded,
                      color: color,
                      dense: true,
                    ),
                    StatusPill(
                      label: incident.status,
                      icon: Icons.task_alt_rounded,
                      color: AppColors.success,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
