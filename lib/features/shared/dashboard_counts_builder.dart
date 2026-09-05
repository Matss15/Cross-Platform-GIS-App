part of '../../app.dart';

class DashboardCountsBuilder extends StatefulWidget {
  const DashboardCountsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DashboardCounts counts) builder;

  @override
  State<DashboardCountsBuilder> createState() => _DashboardCountsBuilderState();
}

class _DashboardCountsBuilderState extends State<DashboardCountsBuilder> {
  late Future<DashboardCounts> _future;

  @override
  void initState() {
    super.initState();
    _future = loadDashboardCounts();
  }

  Future<void> _reload() async {
    setState(() {
      _future = loadDashboardCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardCounts>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Panel(child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Unable to load analytics',
                  subtitle: 'Check data permissions and connectivity.',
                ),
                const SizedBox(height: 12),
                Text(
                  safeErrorMessage(snapshot.error!),
                  style: const TextStyle(color: AppColors.fire),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return widget.builder(context, snapshot.data!);
      },
    );
  }
}
