part of '../../app.dart';

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key, this.onOpenIncident});

  final ValueChanged<String>? onOpenIncident;

  @override
  Widget build(BuildContext context) {
    return DashboardCountsBuilder(
      builder: (context, counts) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveGrid(
            minTileWidth: 190,
            children: [
              MetricTile(
                title: 'Active incidents',
                value: (counts.pending + counts.verified).toString(),
                helper: 'High priority: ${counts.critical}',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.fire,
              ),
              MetricTile(
                title: 'Units dispatched',
                value: counts.fireTrucks.toString(),
                helper: 'Available: ${counts.fireTrucks}',
                icon: Icons.fire_truck_rounded,
                color: AppColors.blue,
              ),
              MetricTile(
                title: 'Personnel on duty',
                value: counts.responders.toString(),
                helper: 'Available responders',
                icon: Icons.groups_rounded,
                color: AppColors.success,
              ),
              MetricTile(
                title: 'Avg response time',
                value: '05:42',
                helper: 'Target: < 08:00',
                icon: Icons.timer_outlined,
                color: AppColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutSwitcher(
            leftFlex: 3,
            rightFlex: 1,
            left: const MapPreview(accent: AppColors.blue, height: 420),
            right: ActiveIncidentPanel(onOpenIncident: onOpenIncident),
          ),
          const SizedBox(height: 14),
          LayoutSwitcher(
            leftFlex: 1,
            rightFlex: 1,
            left: const IncidentPriorityPanel(),
            right: const UnitReadinessPanel(),
          ),
          const SizedBox(height: 14),
          LayoutSwitcher(
            leftFlex: 1,
            rightFlex: 1,
            left: const ResponsePerformancePanel(),
            right: const RecentDispatchPanel(),
          ),
          const SizedBox(height: 18),
          const AdminTablePanel(),
        ],
      ),
    );
  }
}

class AdminVerificationPage extends StatelessWidget {
  const AdminVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [CitizenVerificationPanel()],
    );
  }
}

class CitizenVerificationPanel extends StatelessWidget {
  const CitizenVerificationPanel({super.key});

  Future<void> _verify(BuildContext context, String userId, String name) async {
    final admin = appAuth.currentUser;
    if (admin == null) return;
    final profile = await appDb.collection('users').doc(userId).get();
    final data = profile.data() ?? const <String, dynamic>{};
    const acceptedIds = {
      'Philippine National ID',
      'Driver License',
      'Passport',
      'UMID',
      'PhilHealth ID',
    };
    final idType = textField(data, 'governmentIdType');
    final idImage = textField(data, 'governmentIdImage');
    if (!acceptedIds.contains(idType) || !idImage.startsWith('data:image/')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Approval blocked: valid government ID image is required.',
            ),
          ),
        );
      }
      return;
    }
    await appDb.collection('users').doc(userId).update({
      'isVerified': true,
      'verificationStatus': 'approved',
      'verificationMethod': 'admin_review',
      'verifiedBy': admin.uid,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await writeActivityLog(
      action: 'Verified citizen account',
      targetId: userId,
      targetLabel: name,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Citizen account verified.')));
  }

  Future<void> _reject(BuildContext context, String userId, String name) async {
    final admin = appAuth.currentUser;
    if (admin == null) return;
    await appDb.collection('users').doc(userId).update({
      'isVerified': false,
      'verificationStatus': 'rejected',
      'verificationMethod': 'admin_review',
      'verifiedBy': admin.uid,
      'rejectionReason': 'Please review your submitted details and try again.',
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await writeActivityLog(
      action: 'Rejected citizen account',
      targetId: userId,
      targetLabel: name,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Citizen account rejected.')));
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Citizen verification queue',
            subtitle: 'Review submitted identity details before approval.',
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb
                .collection('users')
                .where('role', isEqualTo: 'resident')
                .where('isVerified', isEqualTo: false)
                .limit(30)
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
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text(
                  'No pending citizen verifications.',
                  style: TextStyle(color: AppColors.muted),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final name = textField(data, 'fullName', 'Citizen');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_search_rounded),
                    ),
                    title: Text(name),
                    subtitle: Text(
                      '${textField(data, 'email', '-')} | '
                      '${textField(data, 'barangayName', '-')}\n'
                      '${textField(data, 'governmentIdType', 'Government ID')} | '
                      '${textField(data, 'governmentIdStatus', 'not submitted')}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _reject(context, doc.id, name),
                          child: const Text('Reject'),
                        ),
                        FilledButton(
                          onPressed: () => _verify(context, doc.id, name),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.citizen;
  String _selectedBarangay = rosarioBarangays.first;
  bool _isCreating = false;
  bool _obscurePassword = true;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    final validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!validEmail) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  Future<FirebaseAuth> _secondaryAuth() async {
    const appName = 'admin-account-creator';

    try {
      return FirebaseAuth.instanceFor(app: Firebase.app(appName));
    } on FirebaseException {
      final app = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
      return FirebaseAuth.instanceFor(app: app);
    }
  }

  Future<void> _createManagedAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _success = false;
        _message = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _message = null;
      _success = false;
    });

    FirebaseAuth? secondaryAuth;
    User? createdUser;

    try {
      final currentUser = appAuth.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Sign in as the super admin first.',
        );
      }

      final profile = await appDb
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (!isSuperAdminProfile(profile.data())) {
        throw FirebaseAuthException(
          code: 'permission-denied',
          message: 'Only the super admin can create managed accounts.',
        );
      }

      final fullName = _nameController.text.trim();
      final email = _emailController.text.trim();
      final roleName = firestoreRoleFor(_selectedRole);
      secondaryAuth = await _secondaryAuth();
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      createdUser = credential.user;

      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Unable to create auth account.',
        );
      }

      await createdUser.updateDisplayName(fullName);

      final userData = <String, dynamic>{
        'uid': createdUser.uid,
        'fullName': fullName,
        'email': email,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'role': roleName,
        'barangayId': barangayIdFor(_selectedBarangay),
        'barangayName': _selectedBarangay,
        'profileImage': '',
        'latitude': rosarioCenter.latitude,
        'longitude': rosarioCenter.longitude,
        'isVerified': true,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == UserRole.bfp) {
        userData['station'] = 'Rosario Fire Station';
      }

      await appDb.collection('users').doc(createdUser.uid).set(userData);

      await writeAccountEmailIndex(
        uid: createdUser.uid,
        email: email,
        fullName: fullName,
        role: roleName,
      );

      await writeActivityLog(
        action: 'Created managed account',
        targetId: createdUser.uid,
        targetLabel: fullName,
        metadata: {'email': email, 'role': roleName},
      );

      if (!mounted) return;
      _formKey.currentState!.reset();
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _success = true;
        _message = '${_selectedRole.shortLabel} account created.';
      });
    } on FirebaseAuthException catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = authErrorMessage(error);
      });
    } catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = safeErrorMessage(error);
      });
    } finally {
      await secondaryAuth?.signOut();
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Widget _createPanel(bool canCreate) {
    if (!canCreate) {
      return const Panel(
        child: SectionTitle(
          title: 'Account creation locked',
          subtitle:
              'Only the super admin can add citizen, barangay, and BFP accounts.',
        ),
      );
    }

    return Panel(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(
              title: 'Create account',
              subtitle:
                  'Super admin managed accounts for citizen, barangay, and BFP access.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<UserRole>(
              showSelectedIcon: false,
              selected: {_selectedRole},
              onSelectionChanged: (selection) {
                setState(() => _selectedRole = selection.single);
              },
              segments: const [
                ButtonSegment(value: UserRole.citizen, label: Text('Citizen')),
                ButtonSegment(
                  value: UserRole.barangay,
                  label: Text('Barangay'),
                ),
                ButtonSegment(value: UserRole.bfp, label: Text('BFP')),
              ],
            ),
            const SizedBox(height: 14),
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_rounded),
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
                setState(() => _selectedBarangay = value ?? _selectedBarangay);
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
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              validator: _validatePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _createManagedAccount(),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Confirm your password.';
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _success ? AppColors.success : AppColors.fire,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isCreating ? null : _createManagedAccount,
              icon: _isCreating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_selectedRole.icon),
              label: Text(_isCreating ? 'Creating...' : 'Create account'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountsPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Managed accounts',
            subtitle: 'Citizen, barangay, and BFP account profiles.',
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb.collection('users').snapshots(),
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

              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final role = roleFromFirestore(textField(doc.data(), 'role'));
                return role == UserRole.citizen ||
                    role == UserRole.barangay ||
                    role == UserRole.bfp;
              }).toList();
              docs.sort((a, b) {
                return textField(
                  a.data(),
                  'fullName',
                ).compareTo(textField(b.data(), 'fullName'));
              });

              if (docs.isEmpty) {
                return const Text(
                  'No managed profiles yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              return AppDataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Barangay')),
                  DataColumn(label: Text('Created')),
                ],
                rows: docs.map((doc) {
                  final data = doc.data();
                  final role =
                      roleFromFirestore(textField(data, 'role'))?.shortLabel ??
                      textField(data, 'role', '-');
                  return DataRow(
                    cells: [
                      DataCell(AppTableText(textField(data, 'fullName', '-'))),
                      DataCell(AppTableText(textField(data, 'email', '-'))),
                      DataCell(Text(role)),
                      DataCell(Text(textField(data, 'barangayName', '-'))),
                      DataCell(Text(formatTimestamp(data['createdAt']))),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = appAuth.currentUser;
    if (currentUser == null) {
      return const Panel(
        child: SectionTitle(
          title: 'Admin session required',
          subtitle: 'Sign in before managing admin accounts.',
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: appDb.collection('users').doc(currentUser.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Panel(child: Center(child: CircularProgressIndicator()));
        }

        final canCreate = isSuperAdminProfile(snapshot.data?.data());

        return LayoutSwitcher(
          leftFlex: 5,
          rightFlex: 7,
          left: _createPanel(canCreate),
          right: _accountsPanel(),
        );
      },
    );
  }
}

class BarangaysPage extends StatefulWidget {
  const BarangaysPage({super.key});

  @override
  State<BarangaysPage> createState() => _BarangaysPageState();
}

class _BarangaysPageState extends State<BarangaysPage> {
  bool _isSyncing = false;
  String? _message;
  bool _success = false;

  Future<void> _syncBarangays() async {
    setState(() {
      _isSyncing = true;
      _message = null;
      _success = false;
    });

    try {
      final batch = appDb.batch();
      final barangays = appDb.collection('barangays');

      for (final record in rosarioBarangayRecords) {
        final id = barangayIdFor(record.name);
        batch.set(barangays.doc(id), {
          'id': id,
          'name': record.name,
          'municipality': 'Rosario',
          'province': 'Batangas',
          'psgcCode': record.psgcCode,
          'correspondenceCode': record.correspondenceCode,
          'classification': record.classification,
          'population': record.population,
          'riskLevel': 'Unassigned',
          'activeIncidents': 0,
          'latitude': rosarioCenter.latitude,
          'longitude': rosarioCenter.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      await writeActivityLog(
        action: 'Synced Rosario barangays',
        targetLabel: '${rosarioBarangayRecords.length} barangays',
      );

      if (!mounted) return;
      setState(() {
        _success = true;
        _message = 'Synced ${rosarioBarangayRecords.length} barangays.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = safeErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appDb.collection('barangays').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final syncedIds = docs.map((doc) => doc.id).toSet();
        final syncedCount = rosarioBarangayRecords
            .where((record) => syncedIds.contains(barangayIdFor(record.name)))
            .length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: appDb.collection('incidents').snapshots(),
          builder: (context, incidentSnapshot) {
            final incidentDocs = incidentSnapshot.data?.docs ?? [];
            final incidentCounts = countIncidentsByBarangay(
              incidentDocs.map((doc) => doc.data()),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveGrid(
                  children: [
                    MetricTile(
                      title: 'Project barangays',
                      value: rosarioBarangayRecords.length.toString(),
                      helper: 'Rosario, Batangas list',
                      icon: Icons.location_city_rounded,
                      color: AppColors.fire,
                    ),
                    MetricTile(
                      title: 'Synced records',
                      value: syncedCount.toString(),
                      helper: syncedCount == rosarioBarangayRecords.length
                          ? 'All Rosario barangays are ready'
                          : '$syncedCount of ${rosarioBarangayRecords.length} ready',
                      icon: Icons.cloud_done_rounded,
                      color: AppColors.success,
                    ),
                    MetricTile(
                      title: 'Incident reports',
                      value: incidentDocs.length.toString(),
                      helper: 'Live reports across Rosario barangays',
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Panel(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final station = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.fire.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.local_phone_rounded,
                              color: AppColors.fire,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rosario Fire Station',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$rosarioFireStationPhoneDisplay / $rosarioFireStationMobileDisplay',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final action = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 46,
                            child: FilledButton.icon(
                              onPressed: _isSyncing ? null : _syncBarangays,
                              icon: _isSyncing
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              label: Text(
                                _isSyncing ? 'Syncing...' : 'Sync barangays',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                              ),
                            ),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _success
                                    ? AppColors.success
                                    : AppColors.fire,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      );

                      if (constraints.maxWidth < 760) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionTitle(
                              title: 'Barangay setup',
                              subtitle: 'Rosario coverage and station contact.',
                            ),
                            const SizedBox(height: 18),
                            station,
                            const SizedBox(height: 18),
                            action,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Expanded(
                            flex: 4,
                            child: SectionTitle(
                              title: 'Barangay setup',
                              subtitle: 'Rosario coverage and station contact.',
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(flex: 5, child: station),
                          const SizedBox(width: 28),
                          SizedBox(width: 210, child: action),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Barangay list',
                        subtitle: 'Rosario barangays available for reports.',
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.hasError)
                        Text(
                          safeErrorMessage(snapshot.error!),
                          style: const TextStyle(color: AppColors.fire),
                        )
                      else
                        AppDataTable(
                          columns: const [
                            DataColumn(label: Text('Barangay')),
                            DataColumn(label: Text('Incident reports')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: [
                            for (final record in rosarioBarangayRecords)
                              DataRow(
                                cells: [
                                  DataCell(AppTableText(record.name)),
                                  DataCell(
                                    Text(
                                      (incidentCounts[record.name] ?? 0)
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          syncedIds.contains(
                                                barangayIdFor(record.name),
                                              )
                                              ? Icons.check_circle_rounded
                                              : Icons.pending_rounded,
                                          size: 18,
                                          color:
                                              syncedIds.contains(
                                                barangayIdFor(record.name),
                                              )
                                              ? AppColors.success
                                              : AppColors.amber,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          syncedIds.contains(
                                                barangayIdFor(record.name),
                                              )
                                              ? 'Ready'
                                              : 'Not synced',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ActivityLogsPage extends StatelessWidget {
  const ActivityLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ActivityLogPanel(
      title: 'Logs and history',
      subtitle: 'Recent account, report, verification, and dispatch actions.',
      limit: 80,
    );
  }
}

class ActivityLogPanel extends StatelessWidget {
  const ActivityLogPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.limit = 20,
  });

  final String title;
  final String subtitle;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: title, subtitle: subtitle),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb
                .collection('activity_logs')
                .orderBy('createdAt', descending: true)
                .limit(limit)
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

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text(
                  'No activity logs yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  return ActivityLogRow(data: data);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ActivityLogRow extends StatelessWidget {
  const ActivityLogRow({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final target = textField(data, 'targetLabel');
    final actor = textField(data, 'actorEmail', 'System');
    final metadata = data['metadata'];
    final details = metadata is Map && metadata.isNotEmpty
        ? jsonEncode(metadata)
        : 'No extra details';

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
              color: AppColors.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textField(data, 'action', 'Activity'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    actor,
                    if (target.isNotEmpty) target,
                    formatTimestamp(data['createdAt']),
                  ].join(' | '),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminIncidentDetailsDialog extends StatelessWidget {
  const AdminIncidentDetailsDialog({super.key, required this.data});

  final Map<String, dynamic> data;

  Future<void> _routeToBfp(
    BuildContext context,
    String incidentId,
    String title,
  ) async {
    final admin = appAuth.currentUser;
    if (admin == null) return;
    await appDb.collection('incidents').doc(incidentId).update({
      'status': 'Routed to BFP',
      'assignedTo': 'BFP',
      'routedBy': admin.uid,
      'routedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await writeActivityLog(
      action: 'Routed incident to BFP',
      targetId: incidentId,
      targetLabel: title,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Incident routed to BFP.')));
  }

  @override
  Widget build(BuildContext context) {
    final status = textField(data, 'status', 'Pending');
    final priority = textField(data, 'priority', 'Medium');
    final latitude = doubleField(data, 'latitude', rosarioCenter.latitude);
    final longitude = doubleField(data, 'longitude', rosarioCenter.longitude);
    final statusColor = colorForIncident(priority: priority, status: status);
    final prediction = predictIncidentRisk(incident: data);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SectionTitle(
                      title: textField(data, 'type', 'Fire incident'),
                      subtitle: 'Citizen report details and evidence.',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatusPill(
                    label: priority,
                    icon: Icons.priority_high_rounded,
                    color: statusColor,
                  ),
                  StatusPill(
                    label: status,
                    icon: Icons.fact_check_rounded,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              StatusPill(
                label:
                    'Predicted risk: ${prediction.level} (${prediction.score})',
                icon: Icons.psychology_rounded,
                color: prediction.level == 'High'
                    ? AppColors.fire
                    : prediction.level == 'Medium'
                    ? AppColors.amber
                    : AppColors.success,
              ),
              const SizedBox(height: 6),
              Text(
                'Decision Tree: ${prediction.reason}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: data['status'] == 'Routed to BFP'
                    ? null
                    : () => _routeToBfp(
                        context,
                        textField(data, 'id'),
                        textField(data, 'type', 'Fire incident'),
                      ),
                icon: const Icon(Icons.local_shipping_rounded),
                label: Text(
                  data['status'] == 'Routed to BFP'
                      ? 'Already routed to BFP'
                      : 'Route to BFP',
                ),
              ),
              const SizedBox(height: 18),
              LayoutSwitcher(
                leftFlex: 5,
                rightFlex: 4,
                left: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveGrid(
                      minTileWidth: 170,
                      maxColumns: 2,
                      children: [
                        MiniFact(
                          label: 'Reporter',
                          value: textField(data, 'reporterName', '-'),
                        ),
                        MiniFact(
                          label: 'Contact',
                          value: textField(data, 'phone', '-'),
                        ),
                        MiniFact(
                          label: 'Barangay',
                          value: textField(data, 'barangayName', '-'),
                        ),
                        MiniFact(
                          label: 'Submitted',
                          value: formatTimestamp(data['createdAt']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      textField(data, 'address', 'No address provided.'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      textField(
                        data,
                        'description',
                        'No description provided.',
                      ),
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
                right: EvidencePanel(
                  readOnly: true,
                  fileName: textField(data, 'evidenceFileName', 'No file'),
                  dataUrl: textField(data, 'evidenceImage'),
                  locationText:
                      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IncidentEvidenceThumbnail extends StatelessWidget {
  const IncidentEvidenceThumbnail({super.key, required this.dataUrl});

  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromDataUrl(dataUrl);

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.muted,
            )
          : Image(image: image, fit: BoxFit.cover),
    );
  }
}

class AdminIncidentMobileRow extends StatelessWidget {
  const AdminIncidentMobileRow({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = textField(data, 'status', 'Pending');
    final priority = textField(data, 'priority', 'Medium');
    final color = colorForIncident(priority: priority, status: status);

    void openDetails() {
      showDialog<void>(
        context: context,
        builder: (context) => AdminIncidentDetailsDialog(data: data),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: openDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IncidentEvidenceThumbnail(
              dataUrl: textField(data, 'evidenceImage'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textField(data, 'type', 'Fire incident'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${textField(data, 'barangayName', '-')} | '
                    '${textField(data, 'address', '-')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$priority | $status',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        textField(data, 'reporterName', '-'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        formatTimestamp(data['createdAt']),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'View report',
              onPressed: openDetails,
              icon: const Icon(Icons.visibility_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarangayFilterChip extends StatelessWidget {
  const _BarangayFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Icon(
        Icons.location_city_rounded,
        size: 16,
        color: selected ? AppColors.text : AppColors.blue,
      ),
      label: Text('$label  $count'),
      selectedColor: AppColors.blue.withValues(alpha: 0.22),
      checkmarkColor: AppColors.blue,
      side: BorderSide(color: AppColors.line),
      labelStyle: TextStyle(
        color: selected ? AppColors.text : AppColors.muted,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class AdminTablePanel extends StatefulWidget {
  const AdminTablePanel({super.key});

  @override
  State<AdminTablePanel> createState() => _AdminTablePanelState();
}

class _AdminTablePanelState extends State<AdminTablePanel> {
  String _selectedBarangay = 'All barangays';

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Incident management',
            subtitle: 'Administrative table for reports, owners, and status.',
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb
                .collection('incidents')
                .orderBy('createdAt', descending: true)
                .limit(50)
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

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Text(
                  'No incident records yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              final barangayCounts = <String, int>{};
              for (final doc in docs) {
                final barangay = textField(
                  doc.data(),
                  'barangayName',
                  'Unassigned barangay',
                );
                barangayCounts[barangay] = (barangayCounts[barangay] ?? 0) + 1;
              }
              final visibleDocs = _selectedBarangay == 'All barangays'
                  ? docs
                  : docs
                        .where(
                          (doc) =>
                              textField(
                                doc.data(),
                                'barangayName',
                                'Unassigned barangay',
                              ) ==
                              _selectedBarangay,
                        )
                        .toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final filter = Panel(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _BarangayFilterChip(
                          label: 'All barangays',
                          count: docs.length,
                          selected: _selectedBarangay == 'All barangays',
                          onSelected: () => setState(
                            () => _selectedBarangay = 'All barangays',
                          ),
                        ),
                        ...barangayCounts.entries.map(
                          (entry) => _BarangayFilterChip(
                            label: entry.key,
                            count: entry.value,
                            selected: _selectedBarangay == entry.key,
                            onSelected: () =>
                                setState(() => _selectedBarangay = entry.key),
                          ),
                        ),
                      ],
                    ),
                  );

                  final records = constraints.maxWidth < 760
                      ? Column(
                          children: [
                            for (
                              var index = 0;
                              index < visibleDocs.length;
                              index++
                            ) ...[
                              AdminIncidentMobileRow(
                                data: visibleDocs[index].data(),
                              ),
                              if (index < visibleDocs.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        )
                      : AppDataTable(
                          columns: const [
                            DataColumn(label: Text('Evidence')),
                            DataColumn(label: Text('Incident')),
                            DataColumn(label: Text('Location')),
                            DataColumn(label: Text('Priority')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Reporter')),
                            DataColumn(label: Text('Submitted')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: visibleDocs.map((doc) {
                            final data = doc.data();
                            return DataRow(
                              cells: [
                                DataCell(
                                  IncidentEvidenceThumbnail(
                                    dataUrl: textField(data, 'evidenceImage'),
                                  ),
                                ),
                                DataCell(Text(textField(data, 'type', '-'))),
                                DataCell(
                                  AppTableText(
                                    '${textField(data, 'barangayName', '-')} | '
                                    '${textField(data, 'address', '-')}',
                                    maxWidth: 220,
                                  ),
                                ),
                                DataCell(
                                  Text(textField(data, 'priority', '-')),
                                ),
                                DataCell(Text(textField(data, 'status', '-'))),
                                DataCell(
                                  AppTableText(
                                    textField(data, 'reporterName', '-'),
                                    maxWidth: 170,
                                  ),
                                ),
                                DataCell(
                                  Text(formatTimestamp(data['createdAt'])),
                                ),
                                DataCell(
                                  IconButton(
                                    tooltip: 'View report',
                                    onPressed: () => showDialog<void>(
                                      context: context,
                                      builder: (context) =>
                                          AdminIncidentDetailsDialog(
                                            data: data,
                                          ),
                                    ),
                                    icon: const Icon(Icons.visibility_rounded),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      filter,
                      const SizedBox(height: 14),
                      if (visibleDocs.isEmpty)
                        const Text(
                          'No incidents in this barangay.',
                          style: TextStyle(color: AppColors.muted),
                        )
                      else
                        records,
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
