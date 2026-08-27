import 'dart:async';

import 'package:flutter/material.dart';

import '../data/game_settings.dart';
import '../data/keeper_stadium.dart';
import '../data/player_stats_store.dart';
import '../data/stadium_ad_unlock_store.dart';
import '../data/stadium_unlock_store.dart';
import 'main_page_sound.dart';
import 'stadium_unlock_dialog.dart';

class DifficultyModeSelector extends StatefulWidget {
  const DifficultyModeSelector({
    super.key,
    this.accent = const Color(0xFF00E5FF),
    this.selectedColor = const Color(0xFFC2FF1F),
    this.chipTextDark = const Color(0xFF0C0620),
    this.showHeading = true,
    this.compact = false,
  });

  final Color accent;
  final Color selectedColor;
  final Color chipTextDark;
  final bool showHeading;
  final bool compact;

  @override
  State<DifficultyModeSelector> createState() =>
      _DifficultyModeSelectorState();
}

class _DifficultyModeSelectorState extends State<DifficultyModeSelector> {
  late DifficultyMode _difficulty;

  @override
  void initState() {
    super.initState();
    _difficulty = GameSettings.difficulty;
  }

  Future<void> _select(DifficultyMode mode) async {
    if (mode == _difficulty) return;
    MainPageSound.playButtonClick();
    setState(() => _difficulty = mode);
    await GameSettings.setDifficulty(mode);
  }

  String _label(DifficultyMode mode) => switch (mode) {
        DifficultyMode.easy => 'Easy',
        DifficultyMode.moderate => 'Moderate',
        DifficultyMode.hard => 'Hard',
      };

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final chipHeight = compact ? 38.0 : 48.0;
    final chipRadius = compact ? 12.0 : 28.0;
    final fontSize = compact ? 12.5 : 15.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeading) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'GAME MODE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 4),
              DifficultyModeInfoButton(
                accent: widget.accent,
                selectedColor: widget.selectedColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            for (var i = 0; i < DifficultyMode.values.length; i++) ...[
              if (i > 0) SizedBox(width: compact ? 8 : 7),
              Expanded(
                child: _ModeChip(
                  label: _label(DifficultyMode.values[i]),
                  selected: DifficultyMode.values[i] == _difficulty,
                  onTap: () => _select(DifficultyMode.values[i]),
                  height: chipHeight,
                  radius: chipRadius,
                  fontSize: fontSize,
                  selectedColor: widget.selectedColor,
                  chipTextDark: widget.chipTextDark,
                  compact: compact,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Swipeable stadium previews for the pre-match setup dialog.
class KeeperStadiumSelector extends StatefulWidget {
  const KeeperStadiumSelector({
    super.key,
    this.accent = const Color(0xFF00E5FF),
    this.selectedColor = const Color(0xFFC2FF1F),
    this.previewHeight = 118,
    this.showHeading = true,
    this.expandPreview = false,
  });

  final Color accent;
  final Color selectedColor;
  final double previewHeight;
  final bool showHeading;
  final bool expandPreview;

  @override
  State<KeeperStadiumSelector> createState() => _KeeperStadiumSelectorState();
}

class _KeeperStadiumSelectorState extends State<KeeperStadiumSelector> {
  static const _locations = KeeperStadiumLocation.values;

  late final PageController _pageController;
  late KeeperStadiumLocation _selected;
  int _focusedIndex = 0;
  PlayerStats _stats = PlayerStats.empty;
  Set<KeeperStadiumLocation> _adUnlockedStadiums = {
    KeeperStadiumLocation.brazil,
  };
  bool _loadingUnlocks = true;
  bool _suppressPageSound = true;

  bool _isUnlocked(KeeperStadiumLocation location) =>
      StadiumUnlockStore.prerequisitesMet(location, _stats);

  bool _isUsableSync(KeeperStadiumLocation location) {
    if (location == KeeperStadiumLocation.brazil) return true;
    if (!_isUnlocked(location)) return false;
    return _adUnlockedStadiums.contains(location);
  }

  bool _needsAdSync(KeeperStadiumLocation location) =>
      _isUnlocked(location) && !_isUsableSync(location);

  @override
  void initState() {
    super.initState();
    _selected = GameSettings.keeperStadium;
    _focusedIndex =
        _locations.indexOf(_selected).clamp(0, _locations.length - 1);
    _pageController = PageController(
      initialPage: _focusedIndex,
      viewportFraction: 0.86,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressPageSound = false;
    });
    _loadUnlockState();
  }

  Future<void> _loadUnlockState() async {
    final stats = await PlayerStatsStore.load();
    if (!mounted) return;

    final adUnlocked = <KeeperStadiumLocation>{KeeperStadiumLocation.brazil};
    for (final location in _locations) {
      if (await StadiumAdUnlockStore.hasWatchedAd(location)) {
        adUnlocked.add(location);
      }
    }

    var selected = GameSettings.keeperStadium;
    if (!await StadiumUnlockStore.isUsable(selected, stats)) {
      selected = KeeperStadiumLocation.brazil;
      await GameSettings.setKeeperStadium(selected);
    }

    final pageIndex =
        _locations.indexOf(selected).clamp(0, _locations.length - 1);
    setState(() {
      _stats = stats;
      _adUnlockedStadiums = adUnlocked;
      _selected = selected;
      _focusedIndex = pageIndex;
      _loadingUnlocks = false;
    });

    if (_pageController.hasClients &&
        _pageController.page?.round() != pageIndex) {
      _pageController.jumpToPage(pageIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectUnlocked(KeeperStadiumLocation location) async {
    if (location == _selected) return;
    setState(() => _selected = location);
    await GameSettings.setKeeperStadium(location);
  }

  Future<void> _trySelectLocation(KeeperStadiumLocation location) async {
    if (!_isUnlocked(location)) {
      showStadiumUnlockDialog(
        context,
        location: location,
        stats: _stats,
      );
      return;
    }

    if (_needsAdSync(location)) {
      final unlocked = await showStadiumAdUnlockDialog(
        context,
        location: location,
      );
      if (!mounted || !unlocked) return;
      setState(() => _adUnlockedStadiums.add(location));
    }

    await _selectUnlocked(location);
    if (mounted) setState(() {});
  }

  void _onPageChanged(int index) {
    final location = _locations[index];
    setState(() => _focusedIndex = index);
    if (!_suppressPageSound) MainPageSound.playButtonClick();
    if (_isUsableSync(location)) {
      unawaited(_selectUnlocked(location));
    }
  }

  void _jumpToPage(int index) {
    final location = _locations[index];
    if (!_isUnlocked(location)) {
      MainPageSound.playButtonClick();
      showStadiumUnlockDialog(
        context,
        location: location,
        stats: _stats,
      );
      return;
    }
    if (_pageController.page?.round() == index) {
      unawaited(_trySelectLocation(location));
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  KeeperStadiumLocation get _focusedLocation => _locations[_focusedIndex];

  @override
  Widget build(BuildContext context) {
    if (_loadingUnlocks) {
      return SizedBox(
        height: widget.expandPreview ? null : widget.previewHeight,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    final focused = _focusedLocation;
    final focusedLocked = !_isUnlocked(focused);
    final focusedNeedsAd = _needsAdSync(focused);
    final progressHint = focusedLocked
        ? StadiumUnlockStore.progressHint(focused, _stats)
        : focusedNeedsAd
            ? 'Watch an ad to unlock ${focused.label}.'
            : null;

    final pageView = PageView.builder(
      controller: _pageController,
      itemCount: _locations.length,
      physics: const BouncingScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final location = _locations[index];
        final locked = !_isUnlocked(location);
        final needsAd = _needsAdSync(location);
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            final page = _pageController.hasClients
                ? (_pageController.page ?? index.toDouble())
                : index.toDouble();
            final delta = (page - index).abs().clamp(0.0, 1.0);
            final scale = 1.0 - delta * 0.08;
            final opacity = 1.0 - delta * 0.35;
            return Transform.scale(
              scale: scale,
              child: Opacity(opacity: opacity, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _StadiumPreviewCard(
              location: location,
              selected: _isUsableSync(location) && location == _selected,
              locked: locked,
              needsAd: needsAd,
              accent: widget.accent,
              selectedColor: widget.selectedColor,
              onTap: () => _jumpToPage(index),
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeading) ...[
          Text(
            'STADIUM',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.expandPreview)
          Expanded(child: pageView)
        else
          SizedBox(height: widget.previewHeight, child: pageView),
        const SizedBox(height: 10),
        Text(
          focusedLocked
              ? '${focused.label} — LOCKED'
              : focusedNeedsAd
                  ? '${focused.label} — WATCH AD'
                  : _selected.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: focusedLocked
                ? Colors.white.withValues(alpha: 0.72)
                : widget.selectedColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        if (focusedLocked || focusedNeedsAd) ...[
          const SizedBox(height: 4),
          Text(
            progressHint ??
                StadiumUnlockStore.unlockRequirement(focused, _stats),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.accent.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _locations.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _StadiumPageDot(
                active: _locations[i] == focused,
                locked: !_isUnlocked(_locations[i]) ||
                    _needsAdSync(_locations[i]),
                selectedColor: widget.selectedColor,
                onTap: () => _jumpToPage(i),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          focusedLocked
              ? 'Complete the challenge to unlock this stadium'
              : focusedNeedsAd
                  ? 'Tap to watch an ad and use this stadium'
                  : 'Swipe for more stadiums',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class _StadiumPreviewCard extends StatelessWidget {
  const _StadiumPreviewCard({
    required this.location,
    required this.selected,
    required this.locked,
    required this.needsAd,
    required this.accent,
    required this.selectedColor,
    required this.onTap,
  });

  final KeeperStadiumLocation location;
  final bool selected;
  final bool locked;
  final bool needsAd;
  final Color accent;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: 0.9)
                  : locked
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  location.assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  color: locked || needsAd ? Colors.black54 : null,
                  colorBlendMode: locked || needsAd ? BlendMode.darken : null,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: locked || needsAd ? 0.55 : 0.35),
                      ],
                    ),
                  ),
                ),
                if (locked || needsAd)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          needsAd
                              ? Icons.play_circle_outline_rounded
                              : Icons.lock_rounded,
                          color: selectedColor.withValues(alpha: 0.95),
                          size: 34,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          needsAd ? 'WATCH AD' : 'LOCKED',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
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
    );
  }
}

class _StadiumPageDot extends StatelessWidget {
  const _StadiumPageDot({
    required this.active,
    required this.locked,
    required this.selectedColor,
    required this.onTap,
  });

  final bool active;
  final bool locked;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: active ? 18 : 7,
        height: 7,
        decoration: BoxDecoration(
          color: active
              ? (locked
                  ? Colors.white.withValues(alpha: 0.45)
                  : selectedColor)
              : Colors.white.withValues(alpha: locked ? 0.16 : 0.28),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.selectedColor,
    required this.chipTextDark,
    required this.compact,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final double fontSize;
  final Color selectedColor;
  final Color chipTextDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: selected && !compact
                ? LinearGradient(
                    colors: [
                      selectedColor,
                      selectedColor.withValues(alpha: 0.75),
                    ],
                  )
                : null,
            color: selected
                ? (compact
                    ? selectedColor.withValues(alpha: 0.22)
                    : null)
                : Colors.white.withValues(alpha: compact ? 0.06 : 0.08),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: compact ? 0.85 : 1.0)
                  : Colors.white.withValues(alpha: 0.18),
              width: selected ? (compact ? 1.5 : 2) : 1,
            ),
            boxShadow: selected && !compact
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? (compact ? selectedColor : chipTextDark)
                    : Colors.white.withValues(alpha: 0.82),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? 0.2 : 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showDifficultyModeInfoDialog(
  BuildContext context, {
  Color accent = const Color(0xFF00E5FF),
  Color selectedColor = const Color(0xFFC2FF1F),
}) {
  MainPageSound.playButtonClick();
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF15102A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GAME MODES',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const _DifficultyModeInfoRow(
              'Easy',
              'Your shot never goes wide or high of the goal. '
                  'Keeping is easier, shots are easier to save.',
            ),
            const SizedBox(height: 12),
            const _DifficultyModeInfoRow(
              'Moderate',
              'Shots may go wide or high. '
                  'Need to extend your reach for keeping.',
            ),
            const SizedBox(height: 12),
            const _DifficultyModeInfoRow(
              'Hard',
              'Full accuracy: aim too wide and the ball misses the post. '
                  'Keeping is harder, shots are harder to save.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'GOT IT',
                  style: TextStyle(
                    color: selectedColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DifficultyModeInfoButton extends StatelessWidget {
  const DifficultyModeInfoButton({
    super.key,
    required this.accent,
    required this.selectedColor,
  });

  final Color accent;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDifficultyModeInfoDialog(
        context,
        accent: accent,
        selectedColor: selectedColor,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: accent.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _DifficultyModeInfoRow extends StatelessWidget {
  const _DifficultyModeInfoRow(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
