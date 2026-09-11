part of '../../app.dart';

FirebaseAuth get appAuth => FirebaseAuth.instance;
FirebaseFirestore get appDb => FirebaseFirestore.instance;

/// Runs an advisory government-ID review from the client through Firebase AI
/// Logic. This uses the Gemini Developer API free tier and does not require
/// Firebase Cloud Functions or a Blaze plan. The result must never be treated
/// as an approval decision; only an admin can verify the account.
Future<Map<String, dynamic>> reviewCitizenIdWithGemini({
  required String idType,
  required List<int> imageBytes,
}) async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.0-flash',
    generationConfig: GenerationConfig(
      temperature: 0,
      responseMimeType: 'application/json',
    ),
  );
  final prompt = '''You are an advisory document-quality checker for a Philippine citizen registration app.
Review only the attached image and do not identify or authenticate the person.
Expected document type: $idType.
Return JSON only with exactly these fields:
{"documentType":"string","readable":true,"appearsGovernmentIssued":true,"confidence":0.0,"concerns":["string"],"recommendation":"manual_review"}
Use recommendation only: manual_review, request_clearer_id, likely_valid, or likely_invalid.
Flag unreadable, screenshot, edited-looking, expired-looking, non-government, or mismatched documents.
This is advisory and must not approve or reject an account.''';

  final response = await model.generateContent([
    Content.multi([
      TextPart(prompt),
      InlineDataPart('image/jpeg', Uint8List.fromList(imageBytes)),
    ]),
  ]);
  final raw = response.text?.trim() ?? '';
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) throw const FormatException('Invalid AI JSON');
  final decoded = jsonDecode(raw.substring(start, end + 1));
  if (decoded is! Map) throw const FormatException('Invalid AI result');
  return Map<String, dynamic>.from(decoded);
}

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
