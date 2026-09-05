part of '../../app.dart';

class SessionGuard extends StatefulWidget {
  const SessionGuard({super.key, required this.child, required this.onTimeout});

  final Widget child;
  final Future<void> Function() onTimeout;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  bool _hasTimedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleTimeout(sessionInactivityTimeout);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleTimeout(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, _expireSession);
  }

  void _recordActivity() {
    if (_hasTimedOut) return;
    _lastActivity = DateTime.now();
    _scheduleTimeout(sessionInactivityTimeout);
  }

  Future<void> _expireSession() async {
    if (_hasTimedOut) return;
    _hasTimedOut = true;
    _timer?.cancel();
    await widget.onTimeout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _hasTimedOut) return;

    final elapsed = DateTime.now().difference(_lastActivity);
    if (elapsed >= sessionInactivityTimeout) {
      unawaited(_expireSession());
      return;
    }

    _scheduleTimeout(sessionInactivityTimeout - elapsed);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) _recordActivity();
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _recordActivity(),
        onPointerSignal: (_) => _recordActivity(),
        child: widget.child,
      ),
    );
  }
}
