import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] at every wall-clock minute boundary of [clock], and
/// when the app returns to the foreground.
class MinuteTicker extends StatefulWidget {
  const MinuteTicker({super.key, required this.clock, required this.builder});

  final DateTime Function() clock;
  final WidgetBuilder builder;

  @override
  State<MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<MinuteTicker>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextMinute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _scheduleNextMinute();
    setState(() {});
  }

  void _scheduleNextMinute() {
    _timer?.cancel();
    final now = widget.clock();
    final intoMinute = Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    _timer = Timer(const Duration(minutes: 1) - intoMinute, _onMinute);
  }

  void _onMinute() {
    if (!mounted) return;
    setState(() {});
    _scheduleNextMinute();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
