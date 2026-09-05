part of '../../app.dart';

enum PolicyDocument { privacy, terms }

Future<void> showAppPolicyDialog(
  BuildContext context, {
  required PolicyDocument document,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _AppPolicyDialog(document: document),
  );
}

class _AppPolicyDialog extends StatelessWidget {
  const _AppPolicyDialog({required this.document});

  final PolicyDocument document;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return DefaultTabController(
      initialIndex: document == PolicyDocument.privacy ? 0 : 1,
      length: 2,
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: screenHeight * 0.82,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 10, 8),
                child: Row(
                  children: [
                    const Icon(Icons.policy_rounded, color: AppColors.teal),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Legal and privacy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Privacy Notice'),
                  Tab(text: 'Terms of Use'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _PolicyPage(
                      sections: [
                        _PolicySectionData(
                          'Information collected',
                          'Account details, contact information, barangay and address, incident descriptions, selected map coordinates, evidence files, and security activity records.',
                        ),
                        _PolicySectionData(
                          'How information is used',
                          'Information is used to authenticate users, verify and respond to incidents, coordinate emergency resources, maintain accountability, and improve public-safety operations.',
                        ),
                        _PolicySectionData(
                          'Access and disclosure',
                          'Access is limited by assigned role. Incident information may be shared with authorized barangay staff, BFP personnel, administrators, and emergency partners when needed for response or required by law.',
                        ),
                        _PolicySectionData(
                          'Storage and security',
                          'Passwords are handled by the managed authentication service and are not stored in the GIS database. Operational records are protected by authenticated access and role-based database rules.',
                        ),
                        _PolicySectionData(
                          'Your choices',
                          'You may review and update profile information in the app. For access, correction, or privacy concerns, contact BFP Rosario through its official station channels.',
                        ),
                      ],
                    ),
                    _PolicyPage(
                      sections: [
                        _PolicySectionData(
                          'Proper use',
                          'Use the service only for legitimate fire, rescue, and public-safety purposes. Do not submit false reports, impersonate another person, or attempt unauthorized access.',
                        ),
                        _PolicySectionData(
                          'Account responsibility',
                          'Keep your credentials confidential and provide accurate registration and incident information. Report suspected account misuse promptly.',
                        ),
                        _PolicySectionData(
                          'Emergency reports',
                          'A digital report does not guarantee immediate response. For an urgent or life-threatening emergency, call the Rosario Fire Station directly after submitting the report when safe to do so.',
                        ),
                        _PolicySectionData(
                          'Location and evidence',
                          'By submitting an incident, you authorize use of the selected location, description, and attached evidence for verification, dispatch, investigation, and official reporting.',
                        ),
                        _PolicySectionData(
                          'Availability and changes',
                          'The service may be unavailable during maintenance or connectivity interruptions. Material policy changes may require acceptance of a new policy version.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 10, 22, 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Policy version $appPolicyVersion',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyPage extends StatelessWidget {
  const _PolicyPage({required this.sections});

  final List<_PolicySectionData> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(22),
      itemCount: sections.length,
      separatorBuilder: (_, index) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final section = sections[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              section.body,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ],
        );
      },
    );
  }
}

class _PolicySectionData {
  const _PolicySectionData(this.title, this.body);

  final String title;
  final String body;
}
