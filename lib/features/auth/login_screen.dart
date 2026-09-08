part of '../../app.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.role,
    required this.onSignIn,
    this.notice,
  });

  final UserRole role;
  final VoidCallback onSignIn;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11171A), Color(0xFF1A2024), Color(0xFF11171A)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 40 : 18,
                  vertical: wide ? 34 : 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _LoginHero(role: role)),
                              const SizedBox(width: 36),
                              SizedBox(
                                width: 430,
                                child: _LoginPanel(
                                  role: role,
                                  onSignIn: onSignIn,
                                  notice: notice,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LoginHero(role: role),
                              const SizedBox(height: 22),
                              _LoginPanel(
                                role: role,
                                onSignIn: onSignIn,
                                notice: notice,
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.05,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            BfpBadge(size: 82, accent: role.accent),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BFP ROSARIO',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fire Incident Reporting and Emergency Response GIS',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(role.headline, style: titleStyle),
        const SizedBox(height: 14),
        const Text(
          'A cross-platform command experience for incident reports, barangay verification, BFP dispatch, and administrative analytics in Rosario, Batangas.',
          style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.45),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            StatusPill(
              label: 'Live GIS map',
              icon: Icons.map_rounded,
              color: AppColors.teal,
            ),
            StatusPill(
              label: 'Verified reports',
              icon: Icons.fact_check_rounded,
              color: AppColors.purple,
            ),
            StatusPill(
              label: 'Dispatch tracking',
              icon: Icons.emergency_share_rounded,
              color: AppColors.blue,
            ),
          ],
        ),
        const SizedBox(height: 28),
        MapPreview(accent: role.accent, height: 270),
      ],
    );
  }
}

class _LoginPanel extends StatefulWidget {
  const _LoginPanel({
    required this.role,
    required this.onSignIn,
    required this.notice,
  });

  final UserRole role;
  final VoidCallback onSignIn;
  final String? notice;

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _failedAttempts = 0;
  DateTime? _retryAfter;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final retryAfter = _retryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      final seconds = retryAfter.difference(DateTime.now()).inSeconds + 1;
      setState(() {
        _errorText = 'Too many attempts. Try again in $seconds seconds.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final credential = await appAuth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No account exists for that email.',
        );
      }

      final profile = await appDb.collection('users').doc(user.uid).get();
      final role = roleFromFirestore(textField(profile.data(), 'role'));

      if (!profile.exists || role == null) {
        await appAuth.signOut();
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No app profile found for this account.',
        );
      }

      if (role != widget.role) {
        await appAuth.signOut();
        final label = role.label;
        throw FirebaseAuthException(
          code: 'wrong-role',
          message: 'This is a $label account. Select ${role.segmentLabel}.',
        );
      }

      try {
        await writeAccountEmailIndex(
          uid: user.uid,
          email: textField(
            profile.data(),
            'email',
            user.email ?? _emailController.text.trim(),
          ),
          fullName: textField(
            profile.data(),
            'fullName',
            user.displayName ?? '',
          ),
          role: firestoreRoleFor(role),
          adminLevel: textField(profile.data(), 'adminLevel'),
        );
      } catch (_) {}

      await writeActivityLog(action: 'Signed in', targetLabel: role.label);

      if (!mounted) return;
      _failedAttempts = 0;
      _retryAfter = null;
      widget.onSignIn();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _retryAfter = DateTime.now().add(const Duration(seconds: 30));
        _failedAttempts = 0;
      }
      setState(() {
        _errorText = authErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = safeErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitSocial(
    Future<UserCredential> Function() signIn,
    String providerName,
  ) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final credential = await signIn();
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: '$providerName did not return an account.',
        );
      }

      final profile = await appDb.collection('users').doc(user.uid).get();
      var role = roleFromFirestore(textField(profile.data(), 'role'));
      final needsCitizenSetup =
          widget.role == UserRole.citizen &&
          (!profile.exists ||
              (textField(profile.data(), 'phone').trim().isEmpty &&
                  textField(profile.data(), 'address').trim().isEmpty));
      if (!profile.exists || role == null || needsCitizenSetup) {
        if (widget.role != UserRole.citizen) {
          await appAuth.signOut();
          throw FirebaseAuthException(
            code: 'missing-profile',
            message: 'A staff account must be provisioned by an administrator.',
          );
        }
        // RoleGate owns the profile setup screen because auth state changes
        // immediately after a social provider signs in.
        return;
      }
      if (role != widget.role) {
        await appAuth.signOut();
        throw FirebaseAuthException(
          code: 'wrong-role',
          message:
              'This is a ${role.label} account. Select ${role.segmentLabel}.',
        );
      }

      await writeActivityLog(action: 'Signed in with $providerName');
      if (!mounted) return;
      widget.onSignIn();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = authErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = safeErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  Future<void> _openCitizenRegisterDialog() async {
    final registered = await showDialog<bool>(
      context: context,
      builder: (context) => const CitizenRegisterDialog(),
    );

    if (registered == true && mounted) {
      widget.onSignIn();
    }
  }

  Future<void> _downloadAndroidApp() async {
    final downloadUrl = Uri.base.resolve(
      'downloads/bfp-rosario-gis-android.zip',
    );
    final opened = await launchUrl(
      downloadUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      setState(() {
        _errorText = 'Unable to start the Android app download.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(widget.role.icon, color: widget.role.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.role.label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<UserRole>(
              showSelectedIcon: false,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: UserRole.values
                  .map(
                    (item) => ButtonSegment<UserRole>(
                      value: item,
                      label: Text(
                        item.segmentLabel,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  )
                  .toList(),
              selected: {widget.role},
              onSelectionChanged: (selection) {
                final nextRole = selection.single;
                if (nextRole == widget.role) return;
                Navigator.pushReplacementNamed(context, nextRole.routePath);
              },
            ),
            if (widget.notice != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.notice!)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: _emailController,
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.account_circle_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              validator: _validatePassword,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
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
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(_isLoading ? 'Signing in...' : 'Sign in'),
              style: FilledButton.styleFrom(
                backgroundColor: widget.role.accent,
              ),
            ),
            if (widget.role == UserRole.citizen) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR CONTINUE WITH',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _submitSocial(signInWithGoogle, 'Google'),
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: const Text('Google'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _submitSocial(signInWithFacebook, 'Facebook'),
                      icon: const Icon(Icons.facebook_rounded),
                      label: const Text('Facebook'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : _openForgotPasswordDialog,
                  child: const Text('Forgot password?'),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _openCitizenRegisterDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Register citizen'),
                ),
              ],
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _downloadAndroidApp,
                icon: const Icon(Icons.android_rounded),
                label: const Text('Download Android APK (.zip)'),
              ),
            ],
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => showAppPolicyDialog(
                    context,
                    document: PolicyDocument.privacy,
                  ),
                  child: const Text('Privacy Notice'),
                ),
                TextButton(
                  onPressed: () => showAppPolicyDialog(
                    context,
                    document: PolicyDocument.terms,
                  ),
                  child: const Text('Terms of Use'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SocialCitizenProfileDialog extends StatefulWidget {
  const SocialCitizenProfileDialog({
    super.key,
    required this.user,
    required this.existingProfile,
  });

  final User user;
  final bool existingProfile;

  @override
  State<SocialCitizenProfileDialog> createState() =>
      _SocialCitizenProfileDialogState();
}

class CitizenProfileSetupScaffold extends StatefulWidget {
  const CitizenProfileSetupScaffold({
    super.key,
    required this.user,
    required this.existingProfile,
  });

  final User user;
  final bool existingProfile;

  @override
  State<CitizenProfileSetupScaffold> createState() =>
      _CitizenProfileSetupScaffoldState();
}

class _CitizenProfileSetupScaffoldState
    extends State<CitizenProfileSetupScaffold> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final completed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SocialCitizenProfileDialog(
          user: widget.user,
          existingProfile: widget.existingProfile,
        ),
      );
      if (completed != true && mounted) await appAuth.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScaffold(message: 'Complete your citizen profile...');
  }
}

class _SocialCitizenProfileDialogState
    extends State<SocialCitizenProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _barangay = rosarioBarangays.first;
  String _idType = 'Philippine National ID';
  XFile? _idCapture;
  bool _accepted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.displayName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      (value ?? '').trim().isEmpty ? '$label is required.' : null;

  Future<void> _captureId() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Scan with camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Choose ID photo'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final capture = await ImagePicker().pickImage(
      source: source,
      imageQuality: 55,
      maxWidth: 1400,
    );
    if (capture != null && mounted) setState(() => _idCapture = capture);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Accept the Privacy Notice and Terms of Use.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      final email = (widget.user.email ?? '').toLowerCase();
      final profileData = <String, dynamic>{
        'fullName': name,
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'governmentIdType': _idType,
        'governmentIdStatus': _idCapture == null ? 'not_submitted' : 'pending',
        'governmentIdFileName': _idCapture?.name ?? '',
        'barangayId': barangayIdFor(_barangay),
        'barangayName': _barangay,
        'profileImage': widget.user.photoURL ?? '',
        'latitude': rosarioCenter.latitude,
        'longitude': rosarioCenter.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!widget.existingProfile) {
        profileData.addAll({
          'uid': widget.user.uid,
          'email': email,
          'role': firestoreRoleFor(UserRole.citizen),
          'isVerified': false,
          'birthdate': '',
          'emergencyContactName': '',
          'emergencyContactPhone': '',
          'biodata': '',
          'createdAt': FieldValue.serverTimestamp(),
          'policyVersion': appPolicyVersion,
          'policyAcceptedAt': FieldValue.serverTimestamp(),
        });
      }
      await appDb
          .collection('users')
          .doc(widget.user.uid)
          .set(profileData, SetOptions(merge: widget.existingProfile));
      await writeAccountEmailIndex(
        uid: widget.user.uid,
        email: email,
        fullName: name,
        role: firestoreRoleFor(UserRole.citizen),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = safeErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete your citizen profile'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'One more step before you can report incidents.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  validator: (value) => _required(value, 'Full name'),
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  validator: (value) => _required(value, 'Contact number'),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _barangay,
                  decoration: const InputDecoration(
                    labelText: 'Barangay',
                    prefixIcon: Icon(Icons.location_city_rounded),
                  ),
                  items: rosarioBarangays
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _barangay = value ?? _barangay),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  validator: (value) => _required(value, 'Address'),
                  decoration: const InputDecoration(
                    labelText: 'Complete address',
                    prefixIcon: Icon(Icons.home_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _idType,
                  decoration: const InputDecoration(
                    labelText: 'Valid government ID',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Philippine National ID',
                      child: Text('Philippine National ID'),
                    ),
                    DropdownMenuItem(
                      value: 'Driver License',
                      child: Text('Driver License'),
                    ),
                    DropdownMenuItem(
                      value: 'Passport',
                      child: Text('Passport'),
                    ),
                    DropdownMenuItem(
                      value: 'Other government ID',
                      child: Text('Other government ID'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _idType = value ?? _idType),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _captureId,
                  icon: const Icon(Icons.document_scanner_rounded),
                  label: Text(
                    _idCapture == null
                        ? 'Scan or attach ID (optional for now)'
                        : 'ID captured: ${_idCapture!.name}',
                  ),
                ),
                CheckboxListTile(
                  value: _accepted,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) =>
                      setState(() => _accepted = value ?? false),
                  title: const Text(
                    'I accept the Privacy Notice and Terms of Use.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => showAppPolicyDialog(
                          context,
                          document: PolicyDocument.privacy,
                        ),
                        icon: const Icon(Icons.privacy_tip_outlined, size: 17),
                        label: const Text('Read Privacy Notice'),
                      ),
                      TextButton.icon(
                        onPressed: () => showAppPolicyDialog(
                          context,
                          document: PolicyDocument.terms,
                        ),
                        icon: const Icon(Icons.gavel_rounded, size: 17),
                        label: const Text('Read Terms of Use'),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.fire),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Saving...' : 'Continue'),
        ),
      ],
    );
  }
}
