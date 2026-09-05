part of '../../app.dart';

String accountEmailLookupId(String email) {
  return base64UrlEncode(
    utf8.encode(email.trim().toLowerCase()),
  ).replaceAll('=', '');
}

Future<void> writeAccountEmailIndex({
  required String uid,
  required String email,
  required String fullName,
  required String role,
  String adminLevel = '',
}) async {
  await appDb
      .collection('account_email_index')
      .doc(accountEmailLookupId(email))
      .set({
        'uid': uid,
        'email': email.trim().toLowerCase(),
        'fullName': fullName,
        'role': role,
        'adminLevel': adminLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
