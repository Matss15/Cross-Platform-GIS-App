part of '../../app.dart';

FirebaseAuth get appAuth => FirebaseAuth.instance;
FirebaseFirestore get appDb => FirebaseFirestore.instance;

/// Gemini model for the advisory ID checks and incident photo triage.
/// gemini-2.x is closed to new projects; flash-lite answers in about 2 s.
const idReviewModel = 'gemini-3.5-flash-lite';

/// Runs an advisory government-ID review from the client through Firebase AI
/// Logic. This uses the Gemini Developer API free tier and does not require
/// Firebase Cloud Functions or a Blaze plan. The result must never be treated
/// as an approval decision; only an admin can verify the account.
Future<Map<String, dynamic>> reviewCitizenIdWithGemini({
  required String idType,
  required String citizenName,
  required List<int> imageBytes,
}) async {
  final prompt =
      '''You are an advisory document-quality checker for a Philippine citizen registration app.
Review only the attached image and do not identify or authenticate the person.
Expected document type: $idType.
Expected registered citizen name: $citizenName.
Return JSON only with exactly these fields:
{"documentType":"string","readable":true,"appearsGovernmentIssued":true,"confidence":0.0,"concerns":["string"],"recommendation":"manual_review"}
Use recommendation only: manual_review, request_clearer_id, likely_valid, or likely_invalid.
Flag unreadable, screenshot, edited-looking, expired-looking, non-government, or mismatched documents. Check whether the visible name is reasonably consistent with the registered citizen name, without extracting or storing any unnecessary personal data.
This is advisory and must not approve or reject an account.''';
  return _generateIdJson(prompt, imageBytes);
}

/// Quick advisory check run by the ID auto-scanner right after capture, so
/// obvious non-IDs or unreadable shots can be retaken immediately.
Future<Map<String, dynamic>> precheckIdCaptureWithGemini({
  required String idType,
  required List<int> imageBytes,
}) {
  final prompt =
      '''You check photos taken in a Philippine citizen registration app before submission.
Look only at the attached image. Do not identify the person and do not repeat any personal data.
Expected document type: $idType.
Return JSON only with exactly these fields:
{"isGovernmentId":true,"matchesExpectedType":true,"readable":true}
isGovernmentId: the image shows the front of a physical government-issued ID card or passport data page (not a screen, photocopy, or unrelated object).
matchesExpectedType: the document appears to be the expected document type.
readable: the name and main text are sharp and legible, without heavy glare or cut-off edges.''';
  return _generateIdJson(prompt, imageBytes);
}

/// Incident types the report form offers; the AI picks one of these.
const incidentTypes = [
  'Structural fire',
  'Grass fire',
  'Vehicle fire',
  'Rescue assistance',
];

/// Urgency levels from least to most severe, as stored in `priority`.
const incidentUrgencies = ['Low', 'High', 'Critical'];

int urgencyRank(String urgency) => incidentUrgencies.indexOf(urgency);

/// Labels an incident photo as soon as the citizen attaches it. The severity
/// becomes the minimum urgency the citizen can submit, so a prank or a
/// mistaken tap cannot quiet a serious report. Dispatchers still decide.
Future<Map<String, dynamic>> assessIncidentPhotoWithGemini({
  required List<int> imageBytes,
  String description = '',
}) {
  final prompt =
      '''You triage photos sent to the Bureau of Fire Protection (BFP) in Rosario, Batangas, Philippines.
Look at the attached photo${description.isEmpty ? '' : ' and the reporter\'s note: "$description"'}.
Do not identify any person and do not repeat personal data.
Return JSON only with exactly these fields:
{"isEmergency":true,"severity":"High","incidentType":"Structural fire","reason":"string"}
isEmergency: the photo plausibly shows a real fire, smoke, crash, or rescue situation happening now (false for selfies, memes, screenshots, drawings, unrelated or old-looking images).
severity, one of:
- "Critical": large or spreading fire, fire inside or engulfing a building, thick heavy smoke, explosion, people trapped or injured, fire near fuel or chemicals.
- "High": clearly active fire or smoke that could spread, vehicle fire, a person needing rescue.
- "Low": small contained fire, light smoke, aftermath with no active fire, or not an emergency.
incidentType: one of ${incidentTypes.map((t) => '"$t"').join(', ')}.
reason: one short sentence in Filipino explaining what you see.''';
  return _generateIdJson(prompt, imageBytes);
}

Future<Map<String, dynamic>> _generateIdJson(
  String prompt,
  List<int> imageBytes,
) async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: idReviewModel,
    generationConfig: GenerationConfig(
      temperature: 0,
      responseMimeType: 'application/json',
    ),
  );
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
