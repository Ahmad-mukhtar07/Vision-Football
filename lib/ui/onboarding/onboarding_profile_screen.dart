import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/user_profile_store.dart';
import '../../models/user_profile.dart';
import '../main_page_sound.dart';

/// First-run, full-screen version of the profile editor. Collects the player's
/// name, country, and position, saves them, then hands control back so the
/// onboarding flow can move on to the tutorials.
class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key, required this.onComplete});

  /// Invoked once the profile has been saved.
  final VoidCallback onComplete;

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  static const _bgTop = Color(0xFF24104A);
  static const _bgMid = Color(0xFF170A30);
  static const _bgBottom = Color(0xFF0C0620);
  static const _accent = Color(0xFF9B30FF);
  static const _lime = Color(0xFFC2FF1F);
  static const _cyan = Color(0xFF00E5FF);
  static const _chipTextDark = Color(0xFF0C0620);

  final _nameController = TextEditingController();
  final _countryController =
      TextEditingController(text: UserProfile.defaultCountryName);
  String _position = UserProfile.defaultPosition;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      _countryController.text.trim().isNotEmpty;

  Future<void> _continue() async {
    if (_saving || !_canContinue) return;
    setState(() => _saving = true);
    final profile = UserProfile(
      displayName: _nameController.text.trim(),
      countryName: _countryController.text.trim(),
      position: _position,
    );
    await UserProfileStore.save(profile);
    MainPageSound.playButtonClick();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgMid, _bgBottom],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'WELCOME',
                style: TextStyle(
                  color: _lime.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create Your Player',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us who you are. You can change this later in Settings.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              const _FieldLabel('Display name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                maxLength: 20,
                onChanged: (_) => setState(() {}),
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
                onChanged: (_) => setState(() {}),
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
              const SizedBox(height: 30),
              _ContinueButton(
                enabled: _canContinue && !_saving,
                accent: _accent,
                onTap: _continue,
              ),
            ],
          ),
        ),
      ),
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

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.75)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'CONTINUE',
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
