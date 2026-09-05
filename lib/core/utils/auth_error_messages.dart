part of '../../app.dart';

String authErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'user-not-found':
      return 'No account exists for that email.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Wrong email or password.';
    case 'email-already-in-use':
      return 'That email is already registered.';
    case 'weak-password':
      return 'Use a stronger password with at least 6 characters.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'wrong-role':
      return error.message ?? 'Select the correct role for this account.';
    case 'missing-profile':
      return error.message ??
          'Complete your account profile before signing in.';
    case 'sign-in-canceled':
      return 'Sign-in was canceled.';
    default:
      return 'Authentication failed. Please try again.';
  }
}

String safeErrorMessage(Object error) {
  if (error is FirebaseAuthException) return authErrorMessage(error);
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to perform that action.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'deadline-exceeded':
        return 'The request took too long. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
