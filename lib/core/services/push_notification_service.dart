part of '../../app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;

  static bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<void> initialize() async {
    if (!_supportedPlatform || _initialized) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _saveTokenForCurrentUser(await messaging.getToken());
    messaging.onTokenRefresh.listen(_saveTokenForCurrentUser);
    appAuth.authStateChanges().listen((_) async {
      await _saveTokenForCurrentUser(await messaging.getToken());
    });
  }

  static Future<void> _saveTokenForCurrentUser(String? token) async {
    final uid = appAuth.currentUser?.uid;
    if (uid == null || token == null || token.isEmpty) return;
    await appDb.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
