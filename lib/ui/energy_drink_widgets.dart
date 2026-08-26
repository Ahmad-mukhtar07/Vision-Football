import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/energy_drink_store.dart';
import 'glass_panel.dart';
import 'main_page_sound.dart';

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Stylized energy-drink can with a lightning bolt.
class EnergyDrinkIcon extends StatelessWidget {
  const EnergyDrinkIcon({
    super.key,
    this.size = 18,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _EnergyCanPainter(),
        size: Size(size, size * 1.15),
      ),
    );
  }
}

class _EnergyCanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.16, w * 0.72, h * 0.78),
      Radius.circular(w * 0.12),
    );

    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF8A50),
            const Color(0xFFFF3D00),
            const Color(0xFFD50000),
          ],
        ).createShader(bodyRect.outerRect),
    );

    final lidRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.04, w * 0.64, h * 0.14),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(
      lidRect,
      Paint()..color = const Color(0xFFECEFF1),
    );
    canvas.drawRRect(
      lidRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04,
    );

    final bolt = Path()
      ..moveTo(w * 0.54, h * 0.34)
      ..lineTo(w * 0.38, h * 0.56)
      ..lineTo(w * 0.48, h * 0.56)
      ..lineTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.62, h * 0.50)
      ..lineTo(w * 0.50, h * 0.50)
      ..close();
    canvas.drawPath(
      bolt,
      Paint()..color = const Color(0xFFFFF176),
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xFFFFD600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035,
    );

    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact cost badge, e.g. icon + "3x".
class EnergyDrinkCostBadge extends StatelessWidget {
  const EnergyDrinkCostBadge({
    super.key,
    required this.cost,
    this.iconSize = 14,
    this.fontSize = 12,
    this.color = Colors.black87,
  });

  final int cost;
  final double iconSize;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EnergyDrinkIcon(size: iconSize),
        const SizedBox(width: 3),
        Text(
          '${cost}x',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Top-right landing-page energy indicator (replaces the logo).
class EnergyDrinkHeaderBadge extends StatelessWidget {
  const EnergyDrinkHeaderBadge({
    super.key,
    required this.count,
    required this.max,
    required this.onTap,
  });

  final int count;
  final int max;
  final VoidCallback onTap;

  static const _accent = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent.withValues(alpha: 0.65), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EnergyDrinkIcon(size: 22),
            const SizedBox(width: 6),
            Text(
              '$count/$max',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatEnergyCountdown(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 86400);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Popup showing current stock and refill timer.
Future<void> showEnergyDrinkStatusDialog(
  BuildContext context, {
  required EnergyDrinkState initialState,
  bool allowEditing = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _EnergyDrinkStatusDialog(
      initialState: initialState,
      allowEditing: allowEditing,
    ),
  );
}

class _EnergyDrinkStatusDialog extends StatefulWidget {
  const _EnergyDrinkStatusDialog({
    required this.initialState,
    required this.allowEditing,
  });

  final EnergyDrinkState initialState;
  final bool allowEditing;

  @override
  State<_EnergyDrinkStatusDialog> createState() =>
      _EnergyDrinkStatusDialogState();
}

class _EnergyDrinkStatusDialogState extends State<_EnergyDrinkStatusDialog> {
  late EnergyDrinkState _state;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final next = await EnergyDrinkStore.loadState();
    if (!mounted) return;
    setState(() => _state = next);
  }

  Future<void> _adjustCount(int delta) async {
    final next = await EnergyDrinkStore.setCount(_state.count + delta);
    if (!mounted) return;
    setState(() => _state = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00E5FF);
    final countdown = _state.timeUntilNextRefill;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: EnergyDrinkIcon(size: 36)),
            const SizedBox(height: 12),
            const Text(
              'ENERGY DRINKS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 14),
            if (widget.allowEditing)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _state.count > 0
                        ? () {
                            _tap();
                            unawaited(_adjustCount(-1));
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: accent,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_state.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _state.count < _state.max
                        ? () {
                            _tap();
                            unawaited(_adjustCount(1));
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: accent,
                  ),
                ],
              )
            else
              Text(
                '${_state.count} of ${_state.max} remaining',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (widget.allowEditing) ...[
              const SizedBox(height: 4),
              Text(
                'of ${_state.max} (QA edit enabled)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _state.isFull
                  ? 'Your energy is full.'
                  : countdown == null
                      ? 'Next drink refilling soon.'
                      : 'Next drink in ${formatEnergyCountdown(countdown)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (!_state.isFull && countdown != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: math.max(
                    0,
                    1 -
                        (countdown.inSeconds /
                            EnergyDrinkStore.refillDuration.inSeconds),
                  ),
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  valueColor: const AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () {
                  _tap();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the player cannot afford a match entry cost.
Future<void> showInsufficientEnergyDialog(
  BuildContext context, {
  required int required,
  required int available,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: EnergyDrinkIcon(size: 36)),
              const SizedBox(height: 12),
              const Text(
                'NOT ENOUGH ENERGY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF6B00),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This match needs ${required}x energy drinks, but you only have $available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: () {
                    _tap();
                    Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
