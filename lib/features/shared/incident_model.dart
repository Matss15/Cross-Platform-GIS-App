part of '../../app.dart';

class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.priority,
    required this.color,
    this.reporterName = '',
    this.assignedTo = '',
    this.description = '',
  });

  final String id;
  final String title;
  final String location;
  final String status;
  final String priority;
  final Color color;
  final String reporterName;
  final String assignedTo;
  final String description;

  factory Incident.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final priority = textField(data, 'priority', 'Medium');
    final status = textField(data, 'status', 'Pending');
    final address = textField(data, 'address', 'No location');
    final barangay = textField(data, 'barangayName');
    final location = [if (barangay.isNotEmpty) barangay, address].join(' | ');

    return Incident(
      id: document.id,
      title: textField(data, 'type', 'Fire incident'),
      location: '$location | ${formatTimestamp(data['createdAt'])}',
      status: status,
      priority: priority,
      color: colorForIncident(priority: priority, status: status),
      reporterName: textField(data, 'reporterName'),
      assignedTo: textField(data, 'assignedTo'),
      description: textField(data, 'description'),
    );
  }
}

/// "AI: Critical" style label from the report's photo triage, or null when
/// the photo was not assessed.
String? aiAssessmentLabel(Map<String, dynamic>? incident) {
  final ai = incident?['aiAssessment'];
  if (ai is! Map || ai['status'] != 'completed') return null;
  final flag = ai['isEmergency'] == false ? ' (hindi mukhang emergency)' : '';
  return 'AI: ${ai['severity']}$flag';
}

Color colorForIncident({required String priority, required String status}) {
  final normalizedPriority = priority.toLowerCase();
  final normalizedStatus = status.toLowerCase();

  if (normalizedPriority == 'critical') return AppColors.fire;
  if (normalizedPriority == 'high') return AppColors.amber;
  if (normalizedStatus == 'resolved' || normalizedStatus == 'closed') {
    return AppColors.success;
  }
  if (normalizedStatus == 'verified') return AppColors.blue;
  return AppColors.teal;
}

Map<String, int> countIncidentsByBarangay(
  Iterable<Map<String, dynamic>> incidents,
) {
  final canonicalNames = {
    for (final record in rosarioBarangayRecords)
      barangayIdFor(record.name): record.name,
  };
  final counts = {for (final record in rosarioBarangayRecords) record.name: 0};

  for (final incident in incidents) {
    final reportedName = textField(incident, 'barangayName').trim();
    if (reportedName.isEmpty) continue;

    final canonicalName =
        canonicalNames[barangayIdFor(reportedName)] ?? reportedName;
    counts[canonicalName] = (counts[canonicalName] ?? 0) + 1;
  }

  return counts;
}
