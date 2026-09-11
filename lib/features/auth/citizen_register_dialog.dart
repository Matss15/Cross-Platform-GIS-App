part of '../../app.dart';

class CitizenRegisterDialog extends StatefulWidget {
  const CitizenRegisterDialog({super.key});

  @override
  State<CitizenRegisterDialog> createState() => _CitizenRegisterDialogState();
}

class _CitizenRegisterDialogState extends State<CitizenRegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedBarangay = rosarioBarangays.first;
  String _idType = 'Philippine National ID';
  XFile? _idCapture;
  bool _isCreating = false;
  bool _obscurePassword = true;
  bool _acceptedPolicies = false;
  String? _message;

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

  Future<void> _captureId() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo of valid ID'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Upload ID photo'),
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
    if (capture == null) return;
    final bytes = await capture.readAsBytes();
    if (bytes.length > 450 * 1024) {
      if (mounted) setState(() => _message = 'ID image must be under 450 KB.');
      return;
    }
    if (mounted) setState(() => _idCapture = capture);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _message = 'Passwords do not match.');
      return;
    }

    if (!_acceptedPolicies) {
      setState(() {
        _message = 'Accept the Privacy Notice and Terms of Use to continue.';
      });
      return;
    }
    if (_idCapture == null) {
      setState(
        () => _message =
            'Invalid ID: upload a valid government-issued ID to continue.',
      );
      return;
    }

    setState(() {
      _isCreating = true;
      _message = null;
    });

    User? createdUser;

    try {
      final fullName = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final idBytes = await _idCapture!.readAsBytes();
      final roleName = firestoreRoleFor(UserRole.citizen);
      final credential = await appAuth.createUserWithEmailAndPassword(
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

      await appDb.collection('users').doc(createdUser.uid).set({
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
        'isVerified': false,
        'birthdate': '',
        'emergencyContactName': '',
        'emergencyContactPhone': '',
        'biodata': '',
        'policyVersion': appPolicyVersion,
        'policyAcceptedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'governmentIdType': _idType,
        'governmentIdStatus': 'pending',
        'governmentIdFileName': _idCapture!.name,
        'governmentIdImage': 'data:image/jpeg;base64,${base64Encode(idBytes)}',
        'governmentIdAiReview': {'status': 'pending'},
      });

      // Gemini review is advisory only. It runs through Firebase AI Logic,
      // which supports the Gemini Developer API free tier without Functions.
      try {
        final ai = await reviewCitizenIdWithGemini(
          idType: _idType,
          imageBytes: idBytes,
        );
        final confidence = (ai['confidence'] as num?)?.toDouble() ?? 0;
        await appDb.collection('users').doc(createdUser.uid).update({
          'governmentIdAiReview': {
            'status': 'completed',
            'documentType': '${ai['documentType'] ?? 'unclear'}',
            'readable': ai['readable'] == true,
            'appearsGovernmentIssued': ai['appearsGovernmentIssued'] == true,
            'confidence': confidence.clamp(0, 1),
            'concerns': (ai['concerns'] is List)
                ? (ai['concerns'] as List).take(8).map((item) => '$item').toList()
                : <String>[],
            'recommendation': '${ai['recommendation'] ?? 'manual_review'}',
            'model': 'gemini-2.0-flash',
            'reviewedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Registration remains possible; Admin receives the ID for manual review.
        await appDb.collection('users').doc(createdUser.uid).update({
          'governmentIdAiReview': {
            'status': 'error',
            'recommendation': 'manual_review',
            'reviewedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await writeAccountEmailIndex(
        uid: createdUser.uid,
        email: email,
        fullName: fullName,
        role: roleName,
      );

      await writeActivityLog(
        action: 'Registered citizen account',
        targetId: createdUser.uid,
        targetLabel: fullName,
        metadata: {'policyVersion': appPolicyVersion},
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
        await appAuth.signOut();
      }
      if (!mounted) return;
      setState(() => _message = authErrorMessage(error));
    } catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
        await appAuth.signOut();
      }
      if (!mounted) return;
      setState(() => _message = safeErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                  title: 'Citizen registration',
                  subtitle: 'Create a resident account for incident reporting.',
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
                DropdownButtonFormField<String>(
                  initialValue: _idType,
                  decoration: const InputDecoration(
                    labelText: 'Valid government-issued ID',
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
                    DropdownMenuItem(value: 'UMID', child: Text('UMID')),
                    DropdownMenuItem(
                      value: 'PhilHealth ID',
                      child: Text('PhilHealth ID'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _idType = value ?? _idType),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isCreating ? null : _captureId,
                  icon: const Icon(Icons.document_scanner_rounded),
                  label: Text(
                    _idCapture == null
                        ? 'Upload valid ID (required)'
                        : 'ID attached: ${_idCapture!.name}',
                  ),
                ),
                const SizedBox(height: 8),
                const _GovernmentIdNotice(),
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
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
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
                  onFieldSubmitted: (_) => _register(),
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
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _acceptedPolicies,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _isCreating
                      ? null
                      : (value) {
                          setState(() {
                            _acceptedPolicies = value ?? false;
                            _message = null;
                          });
                        },
                  title: const Text(
                    'I agree to the Terms of Use and acknowledge the Privacy Notice.',
                  ),
                  subtitle: Wrap(
                    spacing: 8,
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
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: const TextStyle(
                      color: AppColors.fire,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isCreating
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Close'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isCreating ? null : _register,
                      icon: _isCreating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        _isCreating ? 'Creating...' : 'Create account',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.fire,
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
