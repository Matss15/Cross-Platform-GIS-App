part of '../../app.dart';

class MapPoint {
  const MapPoint({
    required this.title,
    required this.subtitle,
    required this.point,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final LatLng point;
  final IconData icon;
  final Color color;

  factory MapPoint.fromIncidentDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final priority = textField(data, 'priority', 'Medium');
    final status = textField(data, 'status', 'Pending');
    return MapPoint(
      title: textField(data, 'type', 'Fire incident'),
      subtitle:
          '${textField(data, 'barangayName', 'Rosario')} | ${status.toLowerCase()}',
      point: LatLng(
        doubleField(data, 'latitude', rosarioCenter.latitude),
        doubleField(data, 'longitude', rosarioCenter.longitude),
      ),
      icon: Icons.local_fire_department_rounded,
      color: colorForIncident(priority: priority, status: status),
    );
  }
}

const fireStationMapPoint = MapPoint(
  title: 'Rosario Fire Station',
  subtitle: 'BFP response base',
  point: LatLng(13.8450, 121.2000),
  icon: Icons.fire_truck_rounded,
  color: AppColors.blue,
);

const responseRoute = [
  LatLng(13.8450, 121.2000),
  LatLng(13.8462, 121.2020),
  LatLng(13.8483, 121.2036),
  LatLng(13.8497, 121.2048),
];
