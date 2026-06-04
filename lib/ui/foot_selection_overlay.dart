import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';

/// Two large foot choices before calibration.
class FootSelectionOverlay extends StatelessWidget {
  const FootSelectionOverlay({
    super.key,
    required this.onFootSelected,
  });

  final ValueChanged<KickingFoot> onFootSelected;

  static const _shoeAsset = 'assets/images/shoe/top-right-shoe.png';

  @override
  Widget build(BuildContext context) {
    final buttonRowHeight =
        (MediaQuery.sizeOf(context).height * 0.30).clamp(180.0, 280.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: Colors.black54,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Which foot will you kick with?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: buttonRowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _FootChoiceBox(
                              label: 'Left foot',
                              mirrorShoe: true,
                              shoeRotation: -15,
                              onTap: () => onFootSelected(KickingFoot.left),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _FootChoiceBox(
                              label: 'Right foot',
                              mirrorShoe: false,
                              shoeRotation: 15,
                              onTap: () => onFootSelected(KickingFoot.right),
                            ),
                          ),
                        ],
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

class _FootChoiceBox extends StatelessWidget {
  const _FootChoiceBox({
    required this.label,
    required this.mirrorShoe,
    required this.shoeRotation,
    required this.onTap,
  });

  final String label;
  final bool mirrorShoe;
  final double shoeRotation;
  final VoidCallback onTap;

  static const _borderRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    Widget shoe = Image.asset(
      FootSelectionOverlay._shoeAsset,
      fit: BoxFit.contain,
    );

    if (mirrorShoe) {
      shoe = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: shoe,
      );
    }

    shoe = Transform.rotate(
      angle: shoeRotation * math.pi / 180,
      child: shoe,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.08),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(child: shoe),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
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
