import 'dart:async';

import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';

/// Gives the player time to get into their kicking stance before calibration runs.
class PositioningOverlay extends StatefulWidget {
  const PositioningOverlay({
    super.key,
    required this.kickingFoot,
    required this.onBeginCalibration,
    this.countdownDuration = const Duration(seconds: 8),
  });

  final KickingFoot kickingFoot;
  final VoidCallback onBeginCalibration;
  final Duration countdownDuration;

  @override
  State<PositioningOverlay> createState() => _PositioningOverlayState();
}

class _PositioningOverlayState extends State<PositioningOverlay> {
  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.countdownDuration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    if (_secondsLeft <= 1) {
      timer.cancel();
      widget.onBeginCalibration();
      return;
    }
    setState(() => _secondsLeft--);
  }

  void _beginNow() {
    _timer?.cancel();
    widget.onBeginCalibration();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foot = widget.kickingFoot.bodyLabel.toLowerCase();

    return ColoredBox(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 52,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'Get into your kicking position',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Stand where you will take every penalty from — same distance, '
                'same angle, feet on the ground.\n\n'
                'Remember this spot. You should kick from here every time '
                '(your $foot is on the orange marker).\n\n'
                'Calibration starts in $_secondsLeft…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              Text(
                '$_secondsLeft',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'seconds until calibration',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _beginNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "I'm in position — calibrate now",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
