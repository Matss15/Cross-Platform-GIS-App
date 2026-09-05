part of '../../app.dart';

Future<void> callRosarioFireStation(BuildContext context) async {
  final uri = Uri(scheme: 'tel', path: rosarioFireStationPhoneDial);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Unable to open dialer. Call $rosarioFireStationPhoneDisplay or $rosarioFireStationMobileDisplay.',
        ),
        backgroundColor: AppColors.fire,
      ),
    );
  }
}
