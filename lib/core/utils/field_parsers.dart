part of '../../app.dart';

String textField(
  Map<String, dynamic>? data,
  String key, [
  String fallback = '',
]) {
  final value = data?[key];
  if (value == null) return fallback;
  return value.toString();
}

double doubleField(Map<String, dynamic>? data, String key, double fallback) {
  final value = data?[key];
  if (value is num) return value.toDouble();
  return fallback;
}

bool isSuperAdminProfile(Map<String, dynamic>? data) {
  if (data == null) return false;
  final role = textField(data, 'role').toLowerCase();
  final level = textField(data, 'adminLevel').toLowerCase();
  final email = textField(data, 'email').toLowerCase();
  return role == 'admin' && level == 'super' && email == superAdminEmail;
}

String formatTimestamp(dynamic value) {
  if (value is! Timestamp) return 'Pending sync';
  final date = value.toDate();
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} hr ago';
  return '${date.month}/${date.day}/${date.year}';
}
