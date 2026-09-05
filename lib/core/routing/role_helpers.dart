part of '../../app.dart';

String firestoreRoleFor(UserRole role) {
  switch (role) {
    case UserRole.citizen:
      return 'resident';
    case UserRole.barangay:
      return 'barangay';
    case UserRole.bfp:
      return 'bfp';
    case UserRole.admin:
      return 'admin';
  }
}

UserRole? roleFromFirestore(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'resident':
    case 'citizen':
      return UserRole.citizen;
    case 'barangay':
      return UserRole.barangay;
    case 'bfp':
      return UserRole.bfp;
    case 'admin':
    case 'super_admin':
    case 'sub_admin':
      return UserRole.admin;
    default:
      return null;
  }
}
