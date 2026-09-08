part of '../../app.dart';

class RoleGate extends StatefulWidget {
  const RoleGate({super.key, required this.role});

  final UserRole role;

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  String? _sessionNotice;

  Future<void> _signOut({bool timedOut = false}) async {
    try {
      await writeActivityLog(
        action: timedOut ? 'Session timed out' : 'Signed out',
      );
    } catch (_) {}

    await appAuth.signOut();
    if (!mounted) return;
    setState(() {
      _sessionNotice = timedOut
          ? 'Session expired after 30 minutes of inactivity. Sign in again.'
          : 'You have signed out securely.';
    });
  }

  Future<void> _userSignOut() => _signOut();

  @override
  Widget build(BuildContext context) {
    if (widget.role == UserRole.admin && !kIsWeb) {
      return AdminWebOnlyScaffold(onSignOut: _userSignOut);
    }

    return StreamBuilder<User?>(
      stream: appAuth.authStateChanges(),
      initialData: appAuth.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return LoginScreen(
            role: widget.role,
            notice: _sessionNotice,
            onSignIn: () => setState(() => _sessionNotice = null),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: appDb.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScaffold(message: 'Loading account...');
            }

            if (snapshot.hasError) {
              return ErrorScaffold(
                title: 'Unable to verify account',
                subtitle: 'Check data permissions and connectivity.',
                actionLabel: 'Sign out',
                onAction: _userSignOut,
              );
            }

            final data = snapshot.data?.data();
            final actualRole = roleFromFirestore(textField(data, 'role'));

            if (data == null || actualRole == null) {
              if (widget.role == UserRole.citizen) {
                return CitizenProfileSetupScaffold(
                  user: user,
                  existingProfile: snapshot.data?.exists ?? false,
                );
              }
              return MissingProfileScaffold(onSignOut: _userSignOut);
            }

            if (actualRole != widget.role) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, actualRole.routePath);
              });
              return const LoadingScaffold(message: 'Switching workspace...');
            }

            return SessionGuard(
              onTimeout: () => _signOut(timedOut: true),
              child: AppShell(
                role: actualRole,
                isVerified: data['isVerified'] == true,
                onSignOut: _userSignOut,
              ),
            );
          },
        );
      },
    );
  }
}
