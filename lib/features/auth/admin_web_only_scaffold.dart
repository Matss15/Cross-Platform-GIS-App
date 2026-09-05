part of '../../app.dart';

class AdminWebOnlyScaffold extends StatelessWidget {
  const AdminWebOnlyScaffold({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  Future<void> _goToMobilePortal(BuildContext context) async {
    await onSignOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      UserRole.citizen.routePath,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BfpBadge(size: 58, accent: AppColors.success),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Web Only',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Open the web build at /admin.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'The Android APK is for mobile incident reporting, barangay verification, and BFP field operations. Admin management stays on the web portal.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _goToMobilePortal(context),
                      icon: const Icon(Icons.phone_android_rounded),
                      label: const Text('Go to mobile portal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.fire,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
