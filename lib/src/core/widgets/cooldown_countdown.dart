import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

/// A live countdown that ticks once per second and calls [label] with the
/// remaining seconds. Renders nothing (empty) once the deadline is reached.
///
/// The tick uses a widget-local [Timer.periodic] + [setState] — ephemeral
/// visual state, per the architecture ephemeral-state rule. The server-derived
/// [until] deadline comes from controller state and is injected by the caller.
///
/// Timer is cancelled in [dispose] and rescheduled in [didUpdateWidget] when
/// [until] changes. Uses [clock.now()] so FakeAsync drives it in tests.
class CooldownCountdown extends StatefulWidget {
  const CooldownCountdown({
    super.key,
    required this.until,
    required this.label,
    this.style,
  });

  /// The deadline after which the countdown stops.
  final DateTime until;

  /// Maps remaining seconds to the localized string to display.
  final String Function(int secondsRemaining) label;

  /// Optional text style; falls back to the ambient [TextTheme.bodySmall].
  final TextStyle? style;

  @override
  State<CooldownCountdown> createState() => _CooldownCountdownState();
}

class _CooldownCountdownState extends State<CooldownCountdown> {
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _scheduleTimer();
  }

  @override
  void didUpdateWidget(CooldownCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) {
      _timer?.cancel();
      _updateRemaining();
      _scheduleTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final diff = widget.until.difference(clock.now());
    _secondsRemaining = diff.isNegative ? 0 : diff.inSeconds;
  }

  void _scheduleTimer() {
    if (_secondsRemaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
      setState(() {});
      if (_secondsRemaining <= 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsRemaining <= 0) return const SizedBox.shrink();
    return Text(
      widget.label(_secondsRemaining),
      style: widget.style ?? Theme.of(context).textTheme.bodySmall,
    );
  }
}
