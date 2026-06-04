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
    return ColoredBox(
      color: Colors.black87,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: const Text(
                  'Which foot will you kick with?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.28,
                  child: Row(
                    children: [
                      Expanded(
                        child: _FootChoiceBox(
                          label: 'Left foot',
                          mirrorShoe: true,
                          onTap: () => onFootSelected(KickingFoot.left),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FootChoiceBox(
                          label: 'Right foot',
                          mirrorShoe: false,
                          onTap: () => onFootSelected(KickingFoot.right),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FootChoiceBox extends StatelessWidget {
  const _FootChoiceBox({
    required this.label,
    required this.mirrorShoe,
    required this.onTap,
  });

  final String label;
  final bool mirrorShoe;
  final VoidCallback onTap;

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

    return Material(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: shoe,
                ),
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
    );
  }
}
