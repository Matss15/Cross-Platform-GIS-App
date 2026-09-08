part of '../../app.dart';

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class MissingProfileScaffold extends StatelessWidget {
  const MissingProfileScaffold({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Panel(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Account profile missing',
                  subtitle:
                      'The account exists but no matching user profile was found.',
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CitizenVerificationScaffold extends StatelessWidget {
  const CitizenVerificationScaffold({
    super.key,
    required this.status,
    required this.rejectionReason,
    required this.onSignOut,
  });

  final String status;
  final String rejectionReason;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final rejected = status == 'rejected';
    return Scaffold(
      body: Center(
        child: Panel(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  rejected
                      ? Icons.cancel_outlined
                      : Icons.hourglass_top_rounded,
                  size: 48,
                  color: rejected ? AppColors.fire : AppColors.amber,
                ),
                const SizedBox(height: 16),
                SectionTitle(
                  title: rejected
                      ? 'Profile needs correction'
                      : 'Waiting for admin approval',
                  subtitle: rejected
                      ? 'Your citizen profile was not approved yet.'
                      : 'Your details were submitted and are being reviewed.',
                ),
                if (rejected && rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Admin note: $rejectionReason',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VerificationRequiredPage extends StatelessWidget {
  const VerificationRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.amber,
            size: 48,
          ),
          const SizedBox(height: 16),
          const SectionTitle(
            title: 'Admin verification required',
            subtitle:
                'You may explore the citizen workspace, but you must be verified before submitting an incident report.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: AppColors.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your profile is pending review by an administrator.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorScaffold extends StatelessWidget {
  const ErrorScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Panel(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(title: title, subtitle: subtitle),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
