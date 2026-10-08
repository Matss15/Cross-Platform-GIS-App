part of '../../app.dart';

/// How often an open BFP workspace reports that it is still online.
const presenceHeartbeatInterval = Duration(seconds: 60);

/// A BFP account counts as online if it checked in within this window, so a
/// closed tab or a phone that lost signal drops off on its own.
const presenceOnlineWindow = Duration(seconds: 150);

CollectionReference<Map<String, dynamic>> get _presence =>
    appDb.collection('presence');

Future<void> reportBfpPresence({required bool online}) async {
  final user = appAuth.currentUser;
  if (user == null) return;
  await _presence.doc(user.uid).set({
    'uid': user.uid,
    'role': 'bfp',
    'online': online,
    'lastSeen': FieldValue.serverTimestamp(),
  });
}

/// Live number of BFP personnel with the app open right now.
///
/// Re-counts every 30 seconds as well, because an account that silently
/// went away (closed tab, no signal) sends no update of its own.
Stream<int> watchOnlineBfpCount() {
  late StreamController<int> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
  Timer? recount;
  var docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  void emit() {
    final cutoff = DateTime.now().subtract(presenceOnlineWindow);
    final count = docs.where((doc) {
      final lastSeen = doc.data()['lastSeen'];
      // A pending server timestamp is this device's own fresh check-in.
      if (lastSeen == null) return true;
      return lastSeen is Timestamp && lastSeen.toDate().isAfter(cutoff);
    }).length;
    if (!controller.isClosed) controller.add(count);
  }

  controller = StreamController<int>(
    onListen: () {
      subscription = _presence
          .where('online', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
            docs = snapshot.docs;
            emit();
          }, onError: controller.addError);
      recount = Timer.periodic(const Duration(seconds: 30), (_) => emit());
    },
    onCancel: () async {
      recount?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}

/// Keeps a BFP account marked online while its workspace is open and in the
/// foreground.
class BfpPresenceReporter extends StatefulWidget {
  const BfpPresenceReporter({super.key, required this.child});

  final Widget child;

  @override
  State<BfpPresenceReporter> createState() => _BfpPresenceReporterState();
}

class _BfpPresenceReporterState extends State<BfpPresenceReporter>
    with WidgetsBindingObserver {
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _goOnline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A browser tab in the background still gets incident alerts, so on web
    // the account stays online until the tab closes or the user signs out.
    if (kIsWeb) return;
    if (state == AppLifecycleState.resumed) {
      _goOnline();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _heartbeat?.cancel();
      _heartbeat = null;
      _send(online: false);
    }
  }

  void _goOnline() {
    _send(online: true);
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      presenceHeartbeatInterval,
      (_) => _send(online: true),
    );
  }

  Future<void> _send({required bool online}) async {
    try {
      await reportBfpPresence(online: online);
    } catch (_) {
      // Presence is best effort; the online window covers missed beats.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Dashboard tile with the live count of online BFP personnel.
class OnlineBfpPersonnelTile extends StatefulWidget {
  const OnlineBfpPersonnelTile({super.key});

  @override
  State<OnlineBfpPersonnelTile> createState() => _OnlineBfpPersonnelTileState();
}

class _OnlineBfpPersonnelTileState extends State<OnlineBfpPersonnelTile> {
  late final Stream<int> _count = watchOnlineBfpCount();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _count,
      builder: (context, snapshot) => MetricTile(
        title: 'Personnel on duty',
        value: snapshot.hasData ? '${snapshot.data}' : '–',
        helper: snapshot.hasError
            ? 'Hindi makuha ang online status'
            : 'BFP personnel online ngayon',
        icon: Icons.groups_rounded,
        color: AppColors.success,
      ),
    );
  }
}
