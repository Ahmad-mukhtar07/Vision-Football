import 'dart:async';

import 'package:flutter/material.dart';

import '../pose/kick_detector.dart';

/// Large on-phone countdown while [KickDetector] is in cooldown.
class KickCooldownBanner extends StatefulWidget {
  const KickCooldownBanner({
    super.key,
    required this.kickDetector,
  });

  final KickDetector kickDetector;

  @override
  State<KickCooldownBanner> createState() => _KickCooldownBannerState();
}

class _KickCooldownBannerState extends State<KickCooldownBanner> {
  StreamSubscription<KickCooldownUpdate>? _subscription;
  KickCooldownUpdate _state = KickCooldownUpdate.inactive;

  @override
  void initState() {
    super.initState();
    _subscription = widget.kickDetector.cooldownUpdates.listen((update) {
      if (!mounted) return;
      setState(() => _state = update);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_state.active) return const SizedBox.shrink();

    final seconds = (_state.remainingMs / 1000).clamp(0.0, 99.9);
    final progress = _state.totalMs > 0
        ? 1.0 - (_state.remainingMs / _state.totalMs).clamp(0.0, 1.0)
        : 0.0;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 72),
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Wait — next kick in',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      seconds.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
