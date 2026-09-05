part of '../app.dart';

class BFPGISApp extends StatelessWidget {
  const BFPGISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BFP Rosario GIS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.fire,
          brightness: Brightness.dark,
          surface: AppColors.panel,
        ),
        textTheme: Typography.whiteMountainView.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.text,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.field,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.fire, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 44),
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      initialRoute: UserRole.citizen.routePath,
      routes: {
        UserRole.citizen.routePath: (_) =>
            const RoleGate(role: UserRole.citizen),
        UserRole.barangay.routePath: (_) =>
            const RoleGate(role: UserRole.barangay),
        UserRole.bfp.routePath: (_) => const RoleGate(role: UserRole.bfp),
        UserRole.admin.routePath: (_) => const RoleGate(role: UserRole.admin),
      },
    );
  }
}
