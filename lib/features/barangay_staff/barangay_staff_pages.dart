part of '../../app.dart';

class BarangayDashboard extends StatelessWidget {
  const BarangayDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCountsBuilder(
          builder: (context, counts) => ResponsiveGrid(
            children: [
              MetricTile(
                title: 'Pending checks',
                value: counts.pending.toString(),
                helper: 'Needs barangay validation',
                icon: Icons.fact_check_rounded,
                color: AppColors.purple,
              ),
              MetricTile(
                title: 'Resolved',
                value: counts.resolved.toString(),
                helper: 'Closed or contained reports',
                icon: Icons.task_alt_rounded,
                color: AppColors.success,
              ),
              MetricTile(
                title: 'Community alerts',
                value: counts.announcements.toString(),
                helper: 'Safety advisories published',
                icon: Icons.campaign_rounded,
                color: AppColors.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutSwitcher(
          left: const VerificationQueue(),
          right: Column(
            children: const [
              MapPreview(accent: AppColors.purple, height: 310),
              SizedBox(height: 14),
              BarangayAlertPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class ReportsReviewPage extends StatelessWidget {
  const ReportsReviewPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.admin) {
      return const AdminTablePanel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VerificationQueue(),
        const SizedBox(height: 14),
        LayoutSwitcher(
          left: const IncidentFeed(title: 'Escalated records'),
          right: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Verification checklist',
                  subtitle:
                      'Confirm location, duplicate reports, and media evidence.',
                ),
                const SizedBox(height: 14),
                ChecklistRow(
                  label: 'Location matches Rosario boundary',
                  checked: true,
                  color: role.accent,
                ),
                ChecklistRow(
                  label: 'Media or witness details attached',
                  checked: true,
                  color: role.accent,
                ),
                ChecklistRow(
                  label: 'Barangay officer note added',
                  checked: false,
                  color: role.accent,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VerificationQueue extends StatelessWidget {
  const VerificationQueue({super.key});

  Future<void> _verify(BuildContext context, Incident incident) async {
    final user = appAuth.currentUser;
    if (user == null) return;

    final incidentRef = appDb.collection('incidents').doc(incident.id);
    await incidentRef.update({
      'status': 'Verified',
      'verifiedBy': user.uid,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final incidentSnapshot = await incidentRef.get();
    await notifyBfpOfVerifiedIncident(
      incidentId: incident.id,
      incident: incidentSnapshot.data() ?? <String, dynamic>{},
    );

    await writeActivityLog(
      action: 'Verified incident',
      targetId: incident.id,
      targetLabel: incident.title,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Incident verified.')));
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Barangay verification queue',
            subtitle: 'Review reports before BFP dispatch receives them.',
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb
                .collection('incidents')
                .where('status', isEqualTo: 'Pending')
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
                  'No pending reports.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              incidents.sort((a, b) => b.priority.compareTo(a.priority));

              return Column(
                children: incidents
                    .map(
                      (incident) => IncidentRow(
                        incident: incident,
                        actionLabel: 'Verify',
                        color: AppColors.purple,
                        onAction: () => _verify(context, incident),
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

class BarangayAlertPanel extends StatelessWidget {
  const BarangayAlertPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Community advisories',
            subtitle: 'Broadcast safety notices to residents.',
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .limit(5)
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
                  'No community advisories yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ResourceCard(
                      icon: Icons.campaign_rounded,
                      title: textField(data, 'title', 'Advisory'),
                      subtitle: textField(data, 'message', 'No message'),
                      color: AppColors.amber,
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
