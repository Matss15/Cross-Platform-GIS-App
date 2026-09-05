part of '../../app.dart';

enum UserRole { citizen, barangay, bfp, admin }

extension UserRoleConfig on UserRole {
  String get label {
    switch (this) {
      case UserRole.citizen:
        return 'Citizen / User';
      case UserRole.barangay:
        return 'Barangay Staff';
      case UserRole.bfp:
        return 'BFP Personnel';
      case UserRole.admin:
        return 'System Admin';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.citizen:
        return 'Citizen';
      case UserRole.barangay:
        return 'Barangay';
      case UserRole.bfp:
        return 'BFP';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get segmentLabel {
    switch (this) {
      case UserRole.citizen:
        return 'Citizen';
      case UserRole.barangay:
        return 'Brgy';
      case UserRole.bfp:
        return 'BFP';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get headline {
    switch (this) {
      case UserRole.citizen:
        return 'Report fire incidents fast';
      case UserRole.barangay:
        return 'Verify and route community alerts';
      case UserRole.bfp:
        return 'Command response operations';
      case UserRole.admin:
        return 'Monitor the entire GIS platform';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.citizen:
        return Icons.person_pin_circle_rounded;
      case UserRole.barangay:
        return Icons.verified_user_rounded;
      case UserRole.bfp:
        return Icons.local_fire_department_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case UserRole.citizen:
        return AppColors.fire;
      case UserRole.barangay:
        return AppColors.purple;
      case UserRole.bfp:
        return AppColors.blue;
      case UserRole.admin:
        return AppColors.success;
    }
  }

  String get routePath {
    switch (this) {
      case UserRole.citizen:
        return '/';
      case UserRole.barangay:
        return '/barangay';
      case UserRole.bfp:
        return '/bfp';
      case UserRole.admin:
        return '/admin';
    }
  }
}
