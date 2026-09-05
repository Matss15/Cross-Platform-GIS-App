part of '../../app.dart';

class BfpCommandDashboard extends StatelessWidget {
  const BfpCommandDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCountsBuilder(
          builder: (context, counts) => ResponsiveGrid(
            minTileWidth: 190,
            children: [
              MetricTile(
                title: 'Active incidents',
                value: (counts.pending + counts.verified).toString(),
                helper: 'High priority: ${counts.critical}',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.fire,
              ),
              MetricTile(
                title: 'Units dispatched',
                value: counts.fireTrucks.toString(),
                helper: 'Available: ${counts.fireTrucks}',
                icon: Icons.fire_truck_rounded,
                color: AppColors.blue,
              ),
              MetricTile(
                title: 'Personnel on duty',
                value: counts.responders.toString(),
                helper: 'Available responders',
                icon: Icons.groups_rounded,
                color: AppColors.success,
              ),
              MetricTile(
                title: 'Avg response time',
                value: '05:42',
                helper: 'Target: < 08:00',
                icon: Icons.timer_outlined,
                color: AppColors.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutSwitcher(
          leftFlex: 3,
          rightFlex: 1,
          left: const MapPreview(accent: AppColors.blue, height: 420),
          right: const ActiveIncidentPanel(),
        ),
        const SizedBox(height: 14),
        LayoutSwitcher(
          leftFlex: 1,
          rightFlex: 1,
          left: const IncidentPriorityPanel(),
          right: const UnitReadinessPanel(),
        ),
        const SizedBox(height: 14),
        LayoutSwitcher(
          leftFlex: 1,
          rightFlex: 1,
          left: const ResponsePerformancePanel(),
          right: const RecentDispatchPanel(),
        ),
      ],
    );
  }
}

class ActiveIncidentPanel extends StatelessWidget {
  const ActiveIncidentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: appDb.collection('incidents').snapshots(),
        builder: (context, snapshot) {
          final docs = [...?snapshot.data?.docs];
          docs.sort(
            (a, b) => (b.data()['createdAt'] is Timestamp ? 1 : 0).compareTo(
              a.data()['createdAt'] is Timestamp ? 1 : 0,
            ),
          );
          final visible = docs.take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeading(
                title: 'Active incidents',
                action: 'View all',
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Text(
                  'No active incidents.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                ...List.generate(visible.length, (index) {
                  final data = visible[index].data();
                  final priority = textField(data, 'priority', 'Medium');
                  final color = colorForIncident(
                    priority: priority,
                    status: textField(data, 'status'),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: color,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                textField(data, 'type', 'Fire incident'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                textField(data, 'barangayName', 'Rosario'),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: priority,
                          icon: Icons.circle,
                          color: color,
                          dense: true,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.title, required this.action});
  final String title;
  final String action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      Text(action, style: const TextStyle(color: AppColors.blue, fontSize: 11)),
    ],
  );
}

class IncidentPriorityPanel extends StatelessWidget {
  const IncidentPriorityPanel({super.key});
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PanelHeading(title: 'Incident priority', action: 'Today'),
        SizedBox(height: 18),
        SizedBox(
          height: 82,
          child: Center(
            child: DonutChart(
              entries: [
                MapEntry('High priority', 3),
                MapEntry('Medium priority', 3),
                MapEntry('Low priority', 2),
              ],
              total: 8,
            ),
          ),
        ),
        SizedBox(height: 12),
        LegendRow(
          label: 'High Priority',
          color: AppColors.fire,
          value: '3 (37.5%)',
        ),
        LegendRow(
          label: 'Medium Priority',
          color: AppColors.amber,
          value: '3 (37.5%)',
        ),
        LegendRow(
          label: 'Low Priority',
          color: AppColors.success,
          value: '2 (25%)',
        ),
      ],
    ),
  );
}

class ResponsePerformancePanel extends StatelessWidget {
  const ResponsePerformancePanel({super.key});
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PanelHeading(title: 'Response performance', action: 'Today'),
        SizedBox(height: 14),
        _PerformanceRow(
          icon: Icons.timer_outlined,
          label: 'Average Response Time',
          value: '05:42',
          delta: '-12%',
        ),
        _PerformanceRow(
          icon: Icons.query_stats_rounded,
          label: 'Incidents Resolved',
          value: '15',
          delta: '+25%',
        ),
        _PerformanceRow(
          icon: Icons.local_shipping_outlined,
          label: 'Units Utilization',
          value: '66%',
          delta: '+8%',
        ),
        _PerformanceRow(
          icon: Icons.groups_outlined,
          label: 'Personnel Efficiency',
          value: '94%',
          delta: '+5%',
        ),
      ],
    ),
  );
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
  });
  final IconData icon;
  final String label;
  final String value;
  final String delta;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Icon(icon, color: AppColors.blue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text(
          delta,
          style: const TextStyle(color: AppColors.success, fontSize: 11),
        ),
      ],
    ),
  );
}

class RecentDispatchPanel extends StatelessWidget {
  const RecentDispatchPanel({super.key});
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PanelHeading(title: 'Recent dispatches', action: 'View all'),
        SizedBox(height: 14),
        _DispatchRow(
          time: '10:21 AM',
          unit: 'Engine 1',
          incident: 'Structure Fire',
          area: 'Poblacion',
        ),
        _DispatchRow(
          time: '10:18 AM',
          unit: 'Ladder 1, Tank 1',
          incident: 'Vehicle Fire',
          area: 'Taal Rd',
        ),
        _DispatchRow(
          time: '10:15 AM',
          unit: 'Rescue 2',
          incident: 'Grass Fire',
          area: 'Antipolo',
        ),
        _DispatchRow(
          time: '10:10 AM',
          unit: 'Ambulance 1',
          incident: 'Medical Emergency',
          area: 'Lumbangan',
        ),
      ],
    ),
  );
}

class _DispatchRow extends StatelessWidget {
  const _DispatchRow({
    required this.time,
    required this.unit,
    required this.incident,
    required this.area,
  });
  final String time, unit, incident, area;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            time,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ),
        Expanded(
          child: Text(
            unit,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: Text(incident, style: const TextStyle(fontSize: 11))),
        Text(
          area,
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class IncidentCommandCard extends StatelessWidget {
  const IncidentCommandCard({super.key});

  Future<void> _markDispatched(
    BuildContext context,
    String incidentId,
    String title,
  ) async {
    await appDb.collection('incidents').doc(incidentId).update({
      'status': 'Dispatched',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await writeActivityLog(
      action: 'Marked incident dispatched',
      targetId: incidentId,
      targetLabel: title,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incident marked as dispatched.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: appDb
            .collection('incidents')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Text(
              safeErrorMessage(snapshot.error!),
              style: const TextStyle(color: AppColors.fire),
            );
          }

          final doc = snapshot.data?.docs.firstOrNull;
          if (doc == null) {
            return const SectionTitle(
              title: 'No active incident',
              subtitle: 'Submitted reports will appear here.',
            );
          }

          final data = doc.data();
          final title = textField(data, 'type', 'Fire incident');
          final status = textField(data, 'status', 'Pending');
          final priority = textField(data, 'priority', 'Medium');
          final color = colorForIncident(priority: priority, status: status);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(
                    label: priority,
                    icon: Icons.priority_high_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  StatusPill(
                    label: status,
                    icon: Icons.fire_truck_rounded,
                    color: AppColors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                textField(data, 'description', 'No description provided.'),
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              ResponsiveGrid(
                minTileWidth: 160,
                children: [
                  MiniFact(
                    label: 'Barangay',
                    value: textField(data, 'barangayName', '-'),
                  ),
                  MiniFact(
                    label: 'Reporter',
                    value: textField(data, 'reporterName', '-'),
                  ),
                  MiniFact(
                    label: 'Created',
                    value: formatTimestamp(data['createdAt']),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: status == 'Dispatched'
                    ? null
                    : () => _markDispatched(context, doc.id, title),
                icon: const Icon(Icons.radio_rounded),
                label: Text(
                  status == 'Dispatched'
                      ? 'Already dispatched'
                      : 'Mark dispatched',
                ),
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ResponseTimeline extends StatelessWidget {
  const ResponseTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Response timeline',
            subtitle: 'Incident activity from report to containment.',
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb
                .collection('incidents')
                .orderBy('updatedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text(
                  safeErrorMessage(snapshot.error!),
                  style: const TextStyle(color: AppColors.fire),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text(
                  'No incident history yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final status = textField(data, 'status', 'Pending');
                  final type = textField(data, 'type', 'Fire incident');
                  final barangay = textField(data, 'barangayName', 'Rosario');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 74,
                          child: Text(
                            formatTimestamp(
                              data['updatedAt'] ?? data['createdAt'],
                            ),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.circle,
                          size: 10,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text('$type in $barangay is $status.')),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class UnitReadinessPanel extends StatelessWidget {
  const UnitReadinessPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Unit readiness',
            subtitle: 'Station assets and response status.',
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appDb.collection('fire_trucks').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text(
                  safeErrorMessage(snapshot.error!),
                  style: const TextStyle(color: AppColors.fire),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text(
                  'No fire truck records yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }

              return ResponsiveGrid(
                minTileWidth: 170,
                children: docs.map((doc) {
                  final data = doc.data();
                  return ResourceCard(
                    icon: Icons.fire_truck_rounded,
                    title: textField(data, 'name', 'Fire truck'),
                    subtitle: textField(data, 'status', 'Unknown'),
                    color: AppColors.blue,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
