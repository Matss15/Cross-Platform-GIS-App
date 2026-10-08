part of '../../app.dart';

bool _googleInitialized = false;

Future<UserCredential> signInWithGoogle() async {
  if (kIsWeb) {
    return appAuth.signInWithPopup(GoogleAuthProvider());
  }

  if (!_googleInitialized) {
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }
  final googleUser = await GoogleSignIn.instance.authenticate();
  final googleAuth = googleUser.authentication;
  final idToken = googleAuth.idToken;
  if (idToken == null || idToken.isEmpty) {
    throw FirebaseAuthException(
      code: 'invalid-credential',
      message: 'Google did not return a valid sign-in token.',
    );
  }
  return appAuth.signInWithCredential(
    GoogleAuthProvider.credential(idToken: idToken),
  );
}

Future<UserCredential> signInWithFacebook() async {
  if (kIsWeb) {
    final provider = FacebookAuthProvider()..addScope('email');
    return appAuth.signInWithPopup(provider);
  }

  // Android uses Firebase's browser flow (same as web), so the Facebook SDK
  // App ID / Client Token is not needed in the APK.
  if (defaultTargetPlatform == TargetPlatform.android) {
    final provider = FacebookAuthProvider()..addScope('email');
    return appAuth.signInWithProvider(provider);
  }

  final result = await FacebookAuth.instance.login(permissions: ['email']);
  if (result.status != LoginStatus.success || result.accessToken == null) {
    throw FirebaseAuthException(
      code: result.status == LoginStatus.cancelled
          ? 'sign-in-canceled'
          : 'invalid-credential',
      message: 'Facebook sign-in was not completed.',
    );
  }
  return appAuth.signInWithCredential(
    FacebookAuthProvider.credential(result.accessToken!.tokenString),
  );
}
