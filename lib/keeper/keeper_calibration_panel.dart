import 'package:flutter/material.dart';

import '../ui/glass_panel.dart';

/// Glass instruction content for keeper calibration (positioned by parent).
class KeeperCalibrationPanel extends StatefulWidget {
  const KeeperCalibrationPanel({
    super.key,
    required this.waitingForHands,
    required this.secondsLeft,
  });

  final bool waitingForHands;
  final int secondsLeft;

  static const _accent = Color(0xFF00E5FF);
  static const _readyGreen = Color(0xFF7CFF7C);

  /// Approximate height used by parent to reserve space above the panel.
  static const double estimatedHeight = 168;

  @override
  State<KeeperCalibrationPanel> createState() => _KeeperCalibrationPanelState();
}

class _KeeperCalibrationPanelState extends State<KeeperCalibrationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  TextStyle get _labelStyle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.4,
        color: KeeperCalibrationPanel._accent,
      );

  TextStyle get _titleStyle => const TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: Colors.white,
        height: 1.2,
      );

  TextStyle get _statusStyle => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.85),
        letterSpacing: 0.2,
      );

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'CALIBRATION',
            textAlign: TextAlign.center,
            style: _labelStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Position Your Upper Body',
            textAlign: TextAlign.center,
            style: _titleStyle,
          ),
          const SizedBox(height: 16),
          if (widget.waitingForHands) _buildWaitingRow() else _buildCountdownRow(),
        ],
      ),
    );
  }

  Widget _buildWaitingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KeeperCalibrationPanel._accent.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: KeeperCalibrationPanel._accent.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Waiting for hands…',
          textAlign: TextAlign.center,
          style: _statusStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${widget.secondsLeft}',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: KeeperCalibrationPanel._readyGreen,
            height: 1,
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Hold position',
            textAlign: TextAlign.center,
            style: _statusStyle,
          ),
        ),
      ],
    );
  }
}
