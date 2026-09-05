part of '../../app.dart';

class AppDestination {
  const AppDestination(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
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
        AppDestination('analytics', 'Analytics', Icons.query_stats_rounded),
        AppDestination('admins', 'Accounts', Icons.manage_accounts_rounded),
        AppDestination('logs', 'Logs', Icons.history_rounded),
      ];
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.role, required this.onSignOut});

  final UserRole role;
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(widget.role);
    final destination = destinations[_index];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final useDrawer =
            widget.role == UserRole.admin || destinations.length > 5;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                SideNav(
                  role: widget.role,
                  destinations: destinations,
                  selectedIndex: _index,
                  onSelected: (index) => setState(() => _index = index),
                  onSignOut: widget.onSignOut,
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
                  onSignOut: widget.onSignOut,
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
                onPressed: widget.onSignOut,
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
  }

  Widget pageFor(String key, UserRole role) {
    switch (key) {
      case 'home':
        return RoleDashboard(role: role);
      case 'report':
        return IncidentReportPage(role: role);
      case 'map':
        return IncidentMapPage(role: role);
      case 'reports':
        return ReportsReviewPage(role: role);
      case 'profile':
        return ProfilePage(role: role, onSignOut: widget.onSignOut);
      case 'barangays':
        return const BarangaysPage();
      case 'incidents':
        return ReportsReviewPage(role: role);
      case 'analytics':
        return AnalyticsPage(role: role);
      case 'admins':
        return const AdminAccountsPage();
      case 'logs':
        return const ActivityLogsPage();
      default:
        return RoleDashboard(role: role);
    }
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
      width: 218,
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
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
            onPressed: () {},
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
              onPressed: () {},
              icon: const Icon(Icons.notifications_active_rounded),
              label: Text('$count alerts'),
            );
          },
        ),
      ],
    );
  }
}

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case UserRole.citizen:
        return const CitizenDashboard();
      case UserRole.barangay:
        return const BarangayDashboard();
      case UserRole.bfp:
        return const BfpCommandDashboard();
      case UserRole.admin:
        return const AdminOverviewPage();
    }
  }
}
