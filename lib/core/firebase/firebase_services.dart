part of '../../app.dart';

FirebaseAuth get appAuth => FirebaseAuth.instance;
FirebaseFirestore get appDb => FirebaseFirestore.instance;

/// Creates a station-side alert for every registered BFP account.
///
/// This is intentionally triggered only after a report has been verified by
/// an authorized barangay user. The notification document is also the audit
/// record used by the BFP app to acknowledge the alert.
Future<void> notifyBfpOfVerifiedIncident({
  required String incidentId,
  required Map<String, dynamic> incident,
}) async {
  final bfpUsers = await appDb
      .collection('users')
      .where('role', isEqualTo: 'bfp')
      .get();

  if (bfpUsers.docs.isEmpty) return;

  final batch = appDb.batch();
  final type = textField(incident, 'type', 'Emergency incident');
  final barangay = textField(incident, 'barangayName', 'Rosario');
  final priority = textField(incident, 'priority', 'Medium');
  final address = textField(incident, 'address', 'Location unavailable');

  for (final user in bfpUsers.docs) {
    final ref = appDb.collection('notifications').doc();
    batch.set(ref, {
      'uid': user.id,
      'type': 'emergency',
      'incidentId': incidentId,
      'title': 'Verified $type report',
      'body': '$barangay | $address',
      'priority': priority,
      'read': false,
      'acknowledged': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}
