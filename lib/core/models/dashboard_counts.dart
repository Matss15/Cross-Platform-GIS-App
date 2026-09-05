part of '../../app.dart';

class DashboardCounts {
  const DashboardCounts({
    required this.users,
    required this.barangays,
    required this.responders,
    required this.fireTrucks,
    required this.announcements,
    required this.incidents,
    required this.pending,
    required this.verified,
    required this.resolved,
    required this.critical,
    required this.today,
    required this.categoryCounts,
    required this.weeklyCounts,
  });

  final int users;
  final int barangays;
  final int responders;
  final int fireTrucks;
  final int announcements;
  final int incidents;
  final int pending;
  final int verified;
  final int resolved;
  final int critical;
  final int today;
  final Map<String, int> categoryCounts;
  final List<int> weeklyCounts;
}

Future<DashboardCounts> loadDashboardCounts() async {
  final snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
    appDb.collection('users').get(),
    appDb.collection('barangays').get(),
    appDb.collection('responders').get(),
    appDb.collection('fire_trucks').get(),
    appDb.collection('announcements').get(),
    appDb.collection('incidents').get(),
  ]);

  final incidents = snapshots[5].docs;
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final weekly = List<int>.filled(7, 0);
  final categories = <String, int>{};
  var pending = 0;
  var verified = 0;
  var resolved = 0;
  var critical = 0;
  var today = 0;

  for (final doc in incidents) {
    final data = doc.data();
    final status = textField(data, 'status').toLowerCase();
    final priority = textField(data, 'priority').toLowerCase();
    final category = textField(data, 'type', 'Fire incident');

    if (status == 'pending') pending += 1;
    if (status == 'verified') verified += 1;
    if (status == 'resolved' || status == 'contained' || status == 'closed') {
      resolved += 1;
    }
    if (priority == 'critical') critical += 1;

    categories[category] = (categories[category] ?? 0) + 1;

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      if (!date.isBefore(startOfToday)) today += 1;

      final daysAgo = now
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        weekly[6 - daysAgo] += 1;
      }
    }
  }

  return DashboardCounts(
    users: snapshots[0].size,
    barangays: snapshots[1].size,
    responders: snapshots[2].size,
    fireTrucks: snapshots[3].size,
    announcements: snapshots[4].size,
    incidents: incidents.length,
    pending: pending,
    verified: verified,
    resolved: resolved,
    critical: critical,
    today: today,
    categoryCounts: categories,
    weeklyCounts: weekly,
  );
}
