import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game_settings.dart';
import '../data/user_profile_store.dart';
import '../models/user_profile.dart';
import 'glass_panel.dart';
import 'main_page_sound.dart';

/// Bottom sheet for editing display name, country, and preferred position.
class ProfileSettingsSheet extends StatefulWidget {
  const ProfileSettingsSheet({super.key, required this.initial});

  final UserProfile initial;

  @override
  State<ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends State<ProfileSettingsSheet> {
  static const _accent = Color(0xFF9B30FF);
  static const _lime = Color(0xFFC2FF1F);
  static const _cyan = Color(0xFF00E5FF);
  static const _chipTextDark = Color(0xFF0C0620);

  late final TextEditingController _nameController;
  late final TextEditingController _countryController;
  late String _position;
  late DifficultyMode _difficulty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.displayName);
    _countryController =
        TextEditingController(text: widget.initial.countryName);
    _position = widget.initial.position;
    _difficulty = GameSettings.difficulty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final country = _countryController.text.trim();
    if (name.isEmpty || country.isEmpty) return;

    final profile = UserProfile(
      displayName: name,
      countryName: country,
      position: _position,
    );
    await UserProfileStore.save(profile);
    await GameSettings.setDifficulty(_difficulty);
    if (!mounted) return;
    MainPageSound.playButtonClick();
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    // Cap sheet height to whatever is left above the keyboard so content
    // scrolls instead of overflowing when a field is focused.
    final maxSheetHeight = media.size.height -
        keyboardInset -
        media.padding.top -
        media.padding.bottom -
        36;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          media.padding.bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxSheetHeight.clamp(280.0, media.size.height),
          ),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SETTINGS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Display name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    maxLength: 20,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _inputDecoration(hint: 'Your name'),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(20)],
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Country'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _countryController,
                    maxLength: 40,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _inputDecoration(hint: 'Argentina'),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Position'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kFootballPositions.map((pos) {
                      final selected = pos == _position;
                      return ChoiceChip(
                        label: Text(pos),
                        selected: selected,
                        onSelected: (_) => setState(() => _position = pos),
                        labelStyle: const TextStyle(
                          color: _chipTextDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        selectedColor: _lime,
                        backgroundColor: Colors.white.withValues(alpha: 0.88),
                        side: BorderSide(
                          color: selected
                              ? _lime
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  _buildDifficultySection(),
                  const SizedBox(height: 22),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _save,
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [_accent, _accent.withValues(alpha: 0.75)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.45),
                              blurRadius: 14,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'SAVE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _FieldLabel('Game mode'),
            const SizedBox(width: 4),
            InkWell(
              onTap: _showModeInfo,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _cyan.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DifficultyMode.values.map((mode) {
            final selected = mode == _difficulty;
            final label = mode == DifficultyMode.easy ? 'Easy' : 'Hard';
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _difficulty = mode),
              labelStyle: const TextStyle(
                color: _chipTextDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              selectedColor: _lime,
              backgroundColor: Colors.white.withValues(alpha: 0.88),
              side: BorderSide(
                color:
                    selected ? _lime : Colors.white.withValues(alpha: 0.35),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showModeInfo() {
    MainPageSound.playButtonClick();
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF15102A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _cyan.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GAME MODES',
                style: TextStyle(
                  color: _cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              _modeInfoRow(
                'Easy',
                'Your shot never goes wide or high of the goal.'
                    'Keeping is easier, shots are easier to save',
              ),
              const SizedBox(height: 12),
              _modeInfoRow(
                'Hard',
                'Full accuracy: aim too wide and the ball misses the post, '
                    'Keeping is harder, shots are harder to save',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'GOT IT',
                    style: TextStyle(
                      color: _lime,
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

  Widget _modeInfoRow(String title, String body) {
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

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _cyan.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _cyan.withValues(alpha: 0.85)),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}
