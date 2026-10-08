part of '../../app.dart';

Future<void> callRosarioFireStation(BuildContext context) => callPhoneNumber(
  context,
  dial: rosarioFireStationPhoneDial,
  fallback:
      '$rosarioFireStationPhoneDisplay or $rosarioFireStationMobileDisplay',
);

/// Opens the phone dialer, or tells the user which number to call when the
/// device has none (for example a desktop browser).
Future<void> callPhoneNumber(
  BuildContext context, {
  required String dial,
  required String fallback,
}) async {
  final uri = Uri(scheme: 'tel', path: dial);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Handled below with the same message as a refused launch.
  }

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to open dialer. Call $fallback.'),
        backgroundColor: AppColors.fire,
      ),
    );
  }
}
