part of '../../app.dart';

class AppDestination {
  const AppDestination(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class BfpEmergencyAlertListener extends StatefulWidget {
  const BfpEmergencyAlertListener({super.key, required this.child});

  final Widget child;

  @override
  State<BfpEmergencyAlertListener> createState() =>
      _BfpEmergencyAlertListenerState();
}

/// Spark-compatible alert path for newly submitted incident reports.
///
/// This deliberately listens to Firestore while the workspace is open. It
/// does not depend on Cloud Functions or Firebase Storage, so it remains
/// usable on the Spark plan. Background delivery when the app is closed still
/// requires a server-side push provider.
class SparkIncidentAlertListener extends StatefulWidget {
  const SparkIncidentAlertListener({
    super.key,
    required this.role,
    required this.child,
  });

  final UserRole role;
  final Widget child;

  @override
  State<SparkIncidentAlertListener> createState() =>
      _SparkIncidentAlertListenerState();
}

class _SparkIncidentAlertListenerState
    extends State<SparkIncidentAlertListener> {
  final Set<String> _knownIncidentIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _alarmTimer;
  bool _initialized = false;
  bool _showingAlert = false;

  bool get _isEmergencyWorkspace =>
      widget.role == UserRole.bfp || widget.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    if (!_isEmergencyWorkspace) return;

    _subscription = appDb
        .collection('incidents')
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .listen(_onIncidentsChanged);
  }

  void _onIncidentsChanged(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_initialized) {
      _knownIncidentIds.addAll(snapshot.docs.map((doc) => doc.id));
      _initialized = true;
      return;
    }

    final newReport = snapshot.docs
        .cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
        .firstWhere(
          (doc) => doc != null && !_knownIncidentIds.contains(doc.id),
          orElse: () => null,
        );
    _knownIncidentIds.addAll(snapshot.docs.map((doc) => doc.id));

    if (newReport != null && mounted && !_showingAlert) {
      unawaited(_showIncidentAlert(newReport));
    }
  }

  Future<void> _showIncidentAlert(
    QueryDocumentSnapshot<Map<String, dynamic>> incident,
  ) async {
    _showingAlert = true;
    if (widget.role == UserRole.bfp) _startAlarm();

    final data = incident.data();
    final priority = textField(data, 'priority', 'High');
    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(
            widget.role == UserRole.bfp
                ? Icons.notification_important_rounded
                : Icons.warning_rounded,
            color: AppColors.fire,
            size: 42,
          ),
          title: const Text('New incident report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(
                label: '$priority priority',
                icon: Icons.priority_high_rounded,
                color: AppColors.fire,
              ),
              const SizedBox(height: 14),
              Text(
                '${textField(data, 'type', 'Incident')} at '
                '${textField(data, 'barangayName', 'Rosario')}',
              ),
              const SizedBox(height: 6),
              Text(textField(data, 'address', 'Location unavailable')),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.visibility_rounded),
              label: Text(
                widget.role == UserRole.bfp ? 'Acknowledge' : 'Review report',
              ),
            ),
          ],
        ),
      );
    } finally {
      _stopAlarm();
      _showingAlert = false;
    }
  }

  void _startAlarm() {
    _playAlarmPulse();
    _alarmTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _playAlarmPulse(),
    );
  }

  void _playAlarmPulse() {
    unawaited(SystemSound.play(SystemSoundType.alert));
    HapticFeedback.heavyImpact();
  }

  void _stopAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
  }

  @override
  void dispose() {
    _stopAlarm();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BfpEmergencyAlertListenerState extends State<BfpEmergencyAlertListener> {
  final Set<String> _knownAlertIds = {};
  bool _initialized = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    final uid = appAuth.currentUser?.uid;
    if (uid == null) return;

    _subscription = appDb
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(_onAlertsChanged);
  }

  void _onAlertsChanged(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final emergencyDocs = snapshot.docs
        .where((doc) => textField(doc.data(), 'type') == 'emergency')
        .toList();

    if (!_initialized) {
      _knownAlertIds.addAll(emergencyDocs.map((doc) => doc.id));
      _initialized = true;
      return;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? newAlert;
    for (final doc in emergencyDocs) {
      if (!_knownAlertIds.contains(doc.id)) {
        newAlert = doc;
        break;
      }
    }
    _knownAlertIds.addAll(emergencyDocs.map((doc) => doc.id));
    if (newAlert != null && mounted) {
      unawaited(_showEmergencyAlert(newAlert));
    }
  }

  Future<void> _showEmergencyAlert(
    QueryDocumentSnapshot<Map<String, dynamic>> alert,
  ) async {
    await SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    final data = alert.data();
    final priority = textField(data, 'priority', 'Medium');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_rounded,
          color: AppColors.fire,
          size: 42,
        ),
        title: Text(textField(data, 'title', 'Emergency alert')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(
              label: '$priority priority',
              icon: Icons.priority_high_rounded,
              color: AppColors.fire,
            ),
            const SizedBox(height: 14),
            Text(
              textField(data, 'body', 'Review the incident in the GIS map.'),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await appDb.collection('notifications').doc(alert.id).update({
                'read': true,
                'acknowledged': true,
                'acknowledgedBy': appAuth.currentUser?.uid,
                'acknowledgedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Acknowledge alert'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

List<AppDestination> destinationsFor(UserRole role) {
  switch (role) {
    case UserRole.citizen:
      return const [
        AppDestination('home', 'Home', Icons.dashboard_rounded),
        AppDestination('report', 'Report', Icons.add_alert_rounded),
        AppDestination('map', 'Map', Icons.map_rounded),
        AppDestination('profile', 'Profile', Icons.person_rounded),
      ];
    case UserRole.barangay:
      return const [
        AppDestination('home', 'Dashboard', Icons.dashboard_rounded),
        AppDestination('reports', 'Verify', Icons.fact_check_rounded),
        AppDestination('map', 'Map', Icons.map_rounded),
        AppDestination('analytics', 'Analytics', Icons.pie_chart_rounded),
        AppDestination('profile', 'Profile', Icons.person_rounded),
      ];
    case UserRole.bfp:
      return const [
        AppDestination('home', 'Dashboard', Icons.dashboard_rounded),
        AppDestination('map', 'Live Map', Icons.map_rounded),
        AppDestination('incidents', 'Incidents', Icons.warning_amber_rounded),
        AppDestination('reports', 'Dispatch', Icons.local_shipping_rounded),
        AppDestination('analytics', 'Analytics', Icons.query_stats_rounded),
        AppDestination('profile', 'Profile', Icons.person_rounded),
      ];
    case UserRole.admin:
      return const [
        AppDestination('home', 'Overview', Icons.dashboard_rounded),
        AppDestination('barangays', 'Barangay', Icons.location_city_rounded),
        AppDestination('incidents', 'Incidents', Icons.table_rows_rounded),
        AppDestination(
          'verification',
          'Verification',
          Icons.verified_user_rounded,
        ),
        AppDestination('analytics', 'Analytics', Icons.query_stats_rounded),
        AppDestination('admins', 'Accounts', Icons.manage_accounts_rounded),
        AppDestination('logs', 'Logs', Icons.history_rounded),
      ];
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.role,
    required this.onSignOut,
    this.isVerified = true,
  });

  final UserRole role;
  final VoidCallback onSignOut;
  final bool isVerified;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String? _selectedIncidentId;

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(widget.role);
    final destination = destinations[_index];

    final shell = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final useDrawer =
            widget.role == UserRole.admin || destinations.length > 5;
        if (wide) {
          if (widget.role == UserRole.admin) {
            return Scaffold(
              body: Column(
                children: [
                  AdminTopNav(
                    destinations: destinations,
                    selectedIndex: _index,
                    onSelected: (index) => setState(() => _index = index),
                    onSignOut: _signOut,
                  ),
                  AdminPageHeader(destination: destination),
                  Expanded(
                    child: PageChrome(
                      role: widget.role,
                      destination: destination,
                      includeHeader: false,
                      child: pageFor(destination.key, widget.role),
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            body: Row(
              children: [
                SideNav(
                  role: widget.role,
                  destinations: destinations,
                  selectedIndex: _index,
                  onSelected: (index) => setState(() => _index = index),
                  onSignOut: _signOut,
                ),
                Expanded(
                  child: PageChrome(
                    role: widget.role,
                    destination: destination,
                    child: pageFor(destination.key, widget.role),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          drawer: useDrawer
              ? MobileNavDrawer(
                  role: widget.role,
                  destinations: destinations,
                  selectedIndex: _index,
                  onSelected: (index) {
                    Navigator.pop(context);
                    setState(() => _index = index);
                  },
                  onSignOut: _signOut,
                )
              : null,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: useDrawer
                ? Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Open menu',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  )
                : null,
            titleSpacing: useDrawer ? 0 : 16,
            title: const Text(
              'BFP Rosario GIS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: PageChrome(
            role: widget.role,
            destination: destination,
            includeHeader: false,
            child: pageFor(destination.key, widget.role),
          ),
          bottomNavigationBar: useDrawer
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (index) =>
                      setState(() => _index = index),
                  backgroundColor: AppColors.panel,
                  indicatorColor: widget.role.accent.withValues(alpha: 0.2),
                  destinations: destinations
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );

    final withIncidentAlerts = _isAlertWorkspace(widget.role)
        ? SparkIncidentAlertListener(role: widget.role, child: shell)
        : shell;

    return widget.role == UserRole.bfp
        ? BfpPresenceReporter(
            child: BfpEmergencyAlertListener(child: withIncidentAlerts),
          )
        : withIncidentAlerts;
  }

  /// BFP accounts are marked offline first, while still allowed to write.
  Future<void> _signOut() async {
    if (widget.role == UserRole.bfp) {
      try {
        await reportBfpPresence(
          online: false,
        ).timeout(const Duration(seconds: 3));
      } catch (_) {
        // The online window drops the account on its own.
      }
    }
    widget.onSignOut();
  }

  void _openDestination(UserRole role, String key) {
    final index = destinationsFor(role).indexWhere((item) => item.key == key);
    if (index >= 0) setState(() => _index = index);
  }

  bool _isAlertWorkspace(UserRole role) =>
      role == UserRole.bfp || role == UserRole.admin;

  Widget pageFor(String key, UserRole role) {
    switch (key) {
      case 'home':
        return RoleDashboard(
          role: role,
          onOpenIncident: role == UserRole.bfp || role == UserRole.admin
              ? (incidentId) {
                  final incidentIndex = destinationsFor(
                    role,
                  ).indexWhere((item) => item.key == 'incidents');
                  if (incidentIndex < 0) return;
                  setState(() {
                    _selectedIncidentId = incidentId;
                    _index = incidentIndex;
                  });
                }
              : null,
          onReportFire: () => _openDestination(role, 'report'),
        );
      case 'report':
        return role == UserRole.citizen && !widget.isVerified
            ? const VerificationRequiredPage()
            : IncidentReportPage(role: role);
      case 'map':
        return IncidentMapPage(role: role);
      case 'reports':
        return ReportsReviewPage(role: role);
      case 'profile':
        return ProfilePage(role: role, onSignOut: _signOut);
      case 'barangays':
        return const BarangaysPage();
      case 'incidents':
        return role == UserRole.bfp
            ? BfpIncidentsPage(selectedIncidentId: _selectedIncidentId)
            : ReportsReviewPage(role: role);
      case 'analytics':
        return AnalyticsPage(role: role);
      case 'admins':
        return const AdminAccountsPage();
      case 'verification':
        return const AdminVerificationPage();
      case 'logs':
        return const ActivityLogsPage();
      default:
        return RoleDashboard(role: role);
    }
  }
}

class AdminTopNav extends StatelessWidget {
  const AdminTopNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSignOut,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          BfpBadge(size: 44, accent: AppColors.success),
          const SizedBox(width: 12),
          const SizedBox(
            width: 145,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BFP ROSARIO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Emergency GIS | Web Control',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    _AdminTopNavItem(
                      destination: destinations[index],
                      selected: index == selectedIndex,
                      onTap: () => onSelected(index),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.success,
                size: 21,
              ),
              SizedBox(width: 7),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Admin',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  Text(
                    'Administrator',
                    style: TextStyle(color: AppColors.muted, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Rosario, Batangas | System Admin',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appAuth.currentUser == null
                ? null
                : appDb
                      .collection('notifications')
                      .where('uid', isEqualTo: appAuth.currentUser!.uid)
                      .where('read', isEqualTo: false)
                      .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.size ?? 0;
              return OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => const AlertsDialog(),
                ),
                icon: const Icon(Icons.notifications_active_rounded),
                label: Text('$count alerts'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminTopNavItem extends StatelessWidget {
  const _AdminTopNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected
            ? AppColors.success.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 18,
                  color: selected ? AppColors.success : AppColors.muted,
                ),
                const SizedBox(width: 7),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: selected ? AppColors.text : AppColors.muted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MobileNavDrawer extends StatelessWidget {
  const MobileNavDrawer({
    super.key,
    required this.role,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSignOut,
  });

  final UserRole role;
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.panel,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  BfpBadge(size: 44, accent: role.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BFP Rosario',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          role.label,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _NavTile(
                      destination: destination,
                      selected: index == selectedIndex,
                      accent: role.accent,
                      onTap: () => onSelected(index),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.role,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSignOut,
  });

  final UserRole role;
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BfpBadge(size: 56, accent: role.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BFP ROSARIO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Emergency GIS',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StatusPill(label: role.label, icon: role.icon, color: role.accent),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: destinations.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final selected = index == selectedIndex;
                return _NavTile(
                  destination: destination,
                  selected: selected,
                  accent: role.accent,
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),
          FilledButton.icon(
            onPressed: () => onSelected(0),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Active alerts'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.fire),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: selected ? accent : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.text : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageChrome extends StatelessWidget {
  const PageChrome({
    super.key,
    required this.role,
    required this.destination,
    required this.child,
    this.includeHeader = true,
  });

  final UserRole role;
  final AppDestination destination;
  final Widget child;
  final bool includeHeader;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (includeHeader) ...[
                  HeaderBar(role: role, destination: destination),
                  const SizedBox(height: 18),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, required this.role, required this.destination});

  final UserRole role;
  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.label,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rosario, Batangas | ${role.label}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (role == UserRole.bfp) ...[
          FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => const EmergencyModeDialog(),
            ),
            icon: const Icon(Icons.notifications_active_rounded, size: 16),
            label: const Text('Emergency Mode'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.fire.withValues(alpha: 0.22),
              foregroundColor: AppColors.fire,
              minimumSize: const Size(0, 40),
            ),
          ),
          const SizedBox(width: 10),
        ],
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: appAuth.currentUser == null
              ? null
              : appDb
                    .collection('notifications')
                    .where('uid', isEqualTo: appAuth.currentUser!.uid)
                    .where('read', isEqualTo: false)
                    .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.size ?? 0;
            return OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const AlertsDialog(),
              ),
              icon: const Icon(Icons.notifications_active_rounded),
              label: Text('$count alerts'),
            );
          },
        ),
      ],
    );
  }
}

class EmergencyModeDialog extends StatelessWidget {
  const EmergencyModeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.notification_important_rounded,
        color: AppColors.fire,
        size: 42,
      ),
      title: const Text('Emergency Mode'),
      content: const Text(
        'Emergency monitoring is active. New verified incidents will appear in the BFP response queue and trigger alerts.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue monitoring'),
        ),
      ],
    );
  }
}

class AlertsDialog extends StatelessWidget {
  const AlertsDialog({super.key});

  Future<void> _acknowledge(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> alert,
  ) async {
    await appDb.collection('notifications').doc(alert.id).update({
      'read': true,
      'acknowledged': true,
      'acknowledgedBy': appAuth.currentUser?.uid,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final uid = appAuth.currentUser?.uid;
    return AlertDialog(
      title: const Text('Incident alerts'),
      content: SizedBox(
        width: 460,
        child: uid == null
            ? const Text('No signed-in user.')
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: appDb
                    .collection('notifications')
                    .where('uid', isEqualTo: uid)
                    .where('read', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      safeErrorMessage(snapshot.error!),
                      style: const TextStyle(color: AppColors.fire),
                    );
                  }
                  final alerts = snapshot.data?.docs ?? [];
                  if (alerts.isEmpty) {
                    return const SizedBox(
                      height: 70,
                      child: Center(
                        child: Text(
                          'No unread incident alerts.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: alerts.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        final data = alert.data();
                        final priority = textField(data, 'priority', 'Medium');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.fire.withValues(
                              alpha: 0.18,
                            ),
                            child: const Icon(
                              Icons.warning_rounded,
                              color: AppColors.fire,
                            ),
                          ),
                          title: Text(
                            textField(data, 'title', 'Emergency alert'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${textField(data, 'body', 'Review incident details.')}\n$priority priority',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Acknowledge alert',
                            onPressed: () => _acknowledge(context, alert),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({
    super.key,
    required this.role,
    this.onOpenIncident,
    this.onReportFire,
  });

  final UserRole role;
  final ValueChanged<String>? onOpenIncident;
  final VoidCallback? onReportFire;

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case UserRole.citizen:
        return CitizenDashboard(onReportFire: onReportFire);
      case UserRole.barangay:
        return const BarangayDashboard();
      case UserRole.bfp:
        return BfpCommandDashboard(onOpenIncident: onOpenIncident);
      case UserRole.admin:
        return AdminOverviewPage(onOpenIncident: onOpenIncident);
    }
  }
}
