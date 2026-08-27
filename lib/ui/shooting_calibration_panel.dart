import 'package:flutter/material.dart';

import 'glass_panel.dart';

/// Glass instruction panel for shooting setup / calibration.
class ShootingCalibrationPanel extends StatefulWidget {
  const ShootingCalibrationPanel({
    super.key,
    required this.statusText,
    this.showCountdown = false,
    this.countdownSeconds = 0,
    this.showProgress = false,
    this.progress = 0,
    this.progressLabel,
    this.onPausePressed,
    this.onSkip,
    this.skipLabel,
  });

  final String statusText;
  final bool showCountdown;
  final int countdownSeconds;
  final bool showProgress;
  final double progress;
  final String? progressLabel;
  final VoidCallback? onPausePressed;
  final VoidCallback? onSkip;
  final String? skipLabel;

  static const _accent = Color(0xFF00E5FF);
  static const _readyGreen = Color(0xFF7CFF7C);

  /// Approximate height for layout calculations (top panel).
  static const double estimatedHeight = 200;

  @override
  State<ShootingCalibrationPanel> createState() =>
      _ShootingCalibrationPanelState();
}

class _ShootingCalibrationPanelState extends State<ShootingCalibrationPanel>
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
        color: ShootingCalibrationPanel._accent,
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
        color: Colors.white.withValues(alpha: 0.88),
      );

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onPausePressed != null) const SizedBox(height: 4),
              Text(
                'CALIBRATION',
                textAlign: TextAlign.center,
                style: _labelStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Position Your Lower Body',
                textAlign: TextAlign.center,
                style: _titleStyle,
              ),
              const SizedBox(height: 16),
              if (widget.showCountdown)
                _buildCountdownRow()
              else
                _buildStatusRow(),
              if (widget.showProgress) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    value: widget.progress > 0 ? widget.progress : null,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.white24,
                    color: ShootingCalibrationPanel._accent,
                  ),
                ),
                if (widget.progressLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.progressLabel!,
                    textAlign: TextAlign.center,
                    style: _statusStyle.copyWith(fontSize: 16),
                  ),
                ],
              ],
              if (widget.onSkip != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    widget.skipLabel ?? 'Skip',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.onPausePressed != null)
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.pause_rounded, color: Colors.white),
                  iconSize: 24,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: 'Pause',
                  onPressed: widget.onPausePressed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ShootingCalibrationPanel._accent.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color:
                      ShootingCalibrationPanel._accent.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.statusText,
          textAlign: TextAlign.center,
          style: _statusStyle,
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
          '${widget.countdownSeconds}',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: ShootingCalibrationPanel._readyGreen,
            height: 1,
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            widget.statusText,
            textAlign: TextAlign.center,
            style: _statusStyle,
          ),
        ),
      ],
    );
  }
}
