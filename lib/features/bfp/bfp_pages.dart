part of '../../app.dart';

class BfpCommandDashboard extends StatelessWidget {
  const BfpCommandDashboard({super.key, this.onOpenIncident});

  final ValueChanged<String>? onOpenIncident;

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
          right: ActiveIncidentPanel(onOpenIncident: onOpenIncident),
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

class BfpIncidentsPage extends StatefulWidget {
  const BfpIncidentsPage({super.key, this.selectedIncidentId});

  final String? selectedIncidentId;

  @override
  State<BfpIncidentsPage> createState() => _BfpIncidentsPageState();
}

class _BfpIncidentsPageState extends State<BfpIncidentsPage> {
  late String? _selectedIncidentId = widget.selectedIncidentId;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: appDb
            .collection('incidents')
            .orderBy('createdAt', descending: true)
            .limit(50)
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'BFP incident response',
                subtitle:
                    'Select an incident to monitor and update its response status.',
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                const Text(
                  'No incident reports yet.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data();
                  final status = textField(data, 'status', 'Pending');
                  final priority = textField(data, 'priority', 'Medium');
                  final selected = doc.id == _selectedIncidentId;
                  final color = colorForIncident(
                    priority: priority,
                    status: status,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: selected
                          ? AppColors.blue.withValues(alpha: 0.12)
                          : AppColors.field,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            setState(() => _selectedIncidentId = doc.id),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      textField(data, 'type', 'Fire incident'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${textField(data, 'barangayName', 'Rosario')} | $status',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                label: priority,
                                icon: Icons.flag_rounded,
                                color: color,
                                dense: true,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Update response status',
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => _IncidentStatusDialog(
                                    incidentId: doc.id,
                                    title: textField(
                                      data,
                                      'type',
                                      'Fire incident',
                                    ),
                                    status: status,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                color: AppColors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
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

class ActiveIncidentPanel extends StatelessWidget {
  const ActiveIncidentPanel({super.key, this.onOpenIncident});

  final ValueChanged<String>? onOpenIncident;

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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onOpenIncident == null
                          ? null
                          : () => onOpenIncident!(visible[index].id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
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
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Open incident details',
                              onPressed: onOpenIncident == null
                                  ? null
                                  : () => onOpenIncident!(visible[index].id),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              color: AppColors.blue,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
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

class _IncidentStatusDialog extends StatelessWidget {
  const _IncidentStatusDialog({
    required this.incidentId,
    required this.title,
    required this.status,
  });

  final String incidentId;
  final String title;
  final String status;

  static const statusOptions = [
    'Pending',
    'Verified',
    'Dispatched',
    'On Scene',
    'Contained',
    'Resolved',
    'Closed',
  ];

  @override
  Widget build(BuildContext context) {
    final command = const IncidentCommandCard();
    return AlertDialog(
      title: const Text('Update response status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Current status: $status'),
          const SizedBox(height: 16),
          const Text(
            'Update status to:',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in statusOptions)
                if (option != status)
                  OutlinedButton(
                    onPressed: () async {
                      await command._advanceStatus(
                        context,
                        incidentId,
                        title,
                        option,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(option),
                  )
                else
                  StatusPill(
                    label: '$option (current)',
                    icon: Icons.radio_button_checked_rounded,
                    color: AppColors.blue,
                  ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
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
          height: 150,
          child: Center(
            child: DonutChart(
              dimension: 150,
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

  Future<void> _advanceStatus(
    BuildContext context,
    String incidentId,
    String title,
    String nextStatus,
  ) async {
    String? note;
    if (nextStatus == 'Resolved' || nextStatus == 'Closed') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('$nextStatus incident'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Response summary',
              hintText: 'Describe the action taken and outcome.',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: Text(nextStatus),
            ),
          ],
        ),
      );
      controller.dispose();
      if (note == null || note.isEmpty) return;
    }

    final user = appAuth.currentUser;
    if (user == null) return;
    final update = <String, dynamic>{
      'status': nextStatus,
      'statusUpdatedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (nextStatus == 'Dispatched') update['assignedTo'] = user.uid;
    if (note != null) update['responseNotes'] = note;
    if (nextStatus == 'Resolved') {
      update['resolvedAt'] = FieldValue.serverTimestamp();
    }
    if (nextStatus == 'Closed') {
      update['closedAt'] = FieldValue.serverTimestamp();
    }
    await appDb.collection('incidents').doc(incidentId).update(update);

    final metadata = <String, dynamic>{'status': nextStatus};
    if (note != null) metadata['summary'] = note;
    await writeActivityLog(
      action: 'Marked incident $nextStatus',
      targetId: incidentId,
      targetLabel: title,
      metadata: metadata,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Incident marked as $nextStatus.')));
  }

  String? _nextStatus(String status) {
    switch (status) {
      case 'Pending':
      case 'Verified':
      case 'Routed to BFP':
        return 'Dispatched';
      case 'Dispatched':
        return 'On Scene';
      case 'On Scene':
        return 'Contained';
      case 'Contained':
        return 'Resolved';
      case 'Resolved':
        return 'Closed';
      default:
        return null;
    }
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
          final nextStatus = _nextStatus(status);

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
              if (textField(data, 'responseNotes').isNotEmpty)
                Panel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded, color: AppColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          textField(data, 'responseNotes'),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (nextStatus != null)
                FilledButton.icon(
                  onPressed: () =>
                      _advanceStatus(context, doc.id, title, nextStatus),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Mark $nextStatus'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                  ),
                )
              else
                const StatusPill(
                  label: 'Response closed',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
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
