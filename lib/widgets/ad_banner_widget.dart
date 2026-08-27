import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// Self-contained banner ad slot with load lifecycle and safe disposal.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.placeholderHeight = 50,
    this.framed = true,
  });

  final AdSize adSize;
  final double placeholderHeight;

  /// When true, wraps the ad in a styled footer dock with a top separator.
  final bool framed;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  static const _backoffDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
  ];

  static const _cyan = Color(0xFF00E5FF);
  static const _lime = Color(0xFFC2FF1F);
  static const _purple = Color(0xFF9B30FF);

  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _loadAttempts = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  void _loadBanner() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;

    final banner = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _loadAttempts = 0;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdBannerWidget: load failed — $error');
          ad.dispose();
          if (!mounted) return;
          setState(() => _isLoaded = false);
          _scheduleRetry();
        },
      ),
    );

    _bannerAd = banner;
    banner.load();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delayIndex = _loadAttempts.clamp(0, _backoffDelays.length - 1);
    final delay = _backoffDelays[delayIndex];
    _loadAttempts = (_loadAttempts + 1) % _backoffDelays.length;

    _retryTimer = Timer(delay, () {
      if (mounted) _loadBanner();
    });
  }

  Widget _adContent() {
    final ad = _bannerAd;
    if (!_isLoaded || ad == null) {
      return SizedBox(
        width: widget.adSize.width.toDouble(),
        height: widget.placeholderHeight,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _adContent();

    if (!widget.framed) {
      return content;
    }

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.72),
            const Color(0xFF0C0620).withValues(alpha: 0.96),
          ],
        ),
        border: Border(
          top: BorderSide(color: _cyan.withValues(alpha: 0.35), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _lime.withValues(alpha: 0.55),
                  _cyan.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SPONSORED',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: content),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
