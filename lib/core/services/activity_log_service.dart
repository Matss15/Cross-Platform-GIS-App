part of '../../app.dart';

Future<void> writeActivityLog({
  required String action,
  String targetId = '',
  String targetLabel = '',
  Map<String, dynamic> metadata = const {},
}) async {
  final user = appAuth.currentUser;
  if (user == null) return;

  await appDb.collection('activity_logs').add({
    'actorUid': user.uid,
    'actorEmail': user.email ?? '',
    'action': action,
    'targetId': targetId,
    'targetLabel': targetLabel,
    'metadata': metadata,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
