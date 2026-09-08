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
        cardTheme: CardThemeData(
          color: AppColors.panel,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.line),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.line,
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panelHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: AppColors.panel,
          indicatorColor: AppColors.fire.withValues(alpha: 0.18),
          labelTextStyle: WidgetStatePropertyAll(
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.text,
          surfaceTintColor: Colors.transparent,
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
