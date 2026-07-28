import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/profile.dart';
import 'cards/art_card.dart';
import 'cards/card_data.dart';
import 'personalization_theme_palette.dart';
import 'profile_composition_controller.dart';

/// Opens the name-and-bio editor over the profile. Both fields apply to the
/// session's draft, not the network: the profile behind the sheet shows the new
/// name the moment it closes, and Done in the app bar is what writes it.
Future<void> showProfileIdentitySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _IdentitySheet(),
    );

/// Opens the cover chooser: automatic, or one linked platform's art.
Future<void> showProfileCoverSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _CoverSheet(),
    );

/// The theme picker, shown on the profile while editing it: one accent-filled
/// swatch per curated theme, re-tinting everything above and below it on tap.
/// A color decision belongs where the colors are, so this sits on the render
/// rather than in a form the profile is not visible from.
class ProfileThemeStrip extends ConsumerWidget {
  const ProfileThemeStrip({super.key});

  /// Swatch diameter and the ring gap reserved around every swatch, so
  /// selecting one does not shift the row.
  static const double _swatchSize = AppSpacing.lg;
  static const double _ringGap = AppSpacing.xs;

  static String _label(AppLocalizations l10n, ProfileTheme theme) =>
      switch (theme) {
        ProfileTheme.crimson => l10n.profileThemeCrimson,
        ProfileTheme.ember => l10n.profileThemeEmber,
        ProfileTheme.solar => l10n.profileThemeSolar,
        ProfileTheme.chak => l10n.profileThemeChak,
        ProfileTheme.frost => l10n.profileThemeFrost,
        ProfileTheme.abyss => l10n.profileThemeAbyss,
        ProfileTheme.arcane => l10n.profileThemeArcane,
        ProfileTheme.rose => l10n.profileThemeRose,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(
      profileCompositionProvider.select(
        (s) => (theme: s.draft?.theme, saving: s.saving),
      ),
    );
    final selected = session.theme;
    if (selected == null) return const SizedBox.shrink();

    return Padding(
      key: const Key('profileEditThemeStrip'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileThemeLabel,
            style: textTheme.labelSmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final theme in ProfileTheme.values)
                Semantics(
                  key: Key('profileEditThemeSwatch_${theme.name}'),
                  button: true,
                  selected: theme == selected,
                  label: _label(l10n, theme),
                  child: InkWell(
                    onTap: session.saving
                        ? null
                        : () => ref
                              .read(profileCompositionProvider.notifier)
                              .selectTheme(theme),
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(_ringGap),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: theme == selected
                            ? Border.all(
                                color: palette.text,
                                width: AppSpacing.hairline,
                              )
                            : null,
                      ),
                      child: Container(
                        width: _swatchSize,
                        height: _swatchSize,
                        decoration: BoxDecoration(
                          color: paletteForTheme(theme).accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.muted),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Name and bio, validated here so the session's draft only ever holds an edit
/// the backend would accept.
class _IdentitySheet extends ConsumerStatefulWidget {
  const _IdentitySheet();

  @override
  ConsumerState<_IdentitySheet> createState() => _IdentitySheetState();
}

class _IdentitySheetState extends ConsumerState<_IdentitySheet> {
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  Set<ProfileEditField> _errors = const {};

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCompositionProvider).draft;
    _displayName = TextEditingController(text: draft?.displayName ?? '');
    _bio = TextEditingController(text: draft?.bio ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _apply() {
    final draft = ref.read(profileCompositionProvider).draft;
    if (draft == null) {
      Navigator.of(context).pop();
      return;
    }
    final bio = _bio.text.trim();
    final candidate = draft.copyWith(
      displayName: _displayName.text.trim(),
      bio: () => bio.isEmpty ? null : bio,
    );
    final errors = candidate.validate();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    ref
        .read(profileCompositionProvider.notifier)
        .editIdentity(displayName: candidate.displayName, bio: candidate.bio);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      key: const Key('profileEditIdentitySheet'),
      // Lifts the fields clear of the keyboard the first tap raises.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.profileEditIdentity, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('profileDisplayNameField'),
                controller: _displayName,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.profileDisplayNameLabel,
                  errorText: _errors.contains(ProfileEditField.displayName)
                      ? l10n.profileDisplayNameInvalid
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('profileBioField'),
                controller: _bio,
                maxLength: 150,
                minLines: 3,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                inputFormatters: const [
                  _MaxLineBreaksFormatter(kMaxBioLineBreaks),
                ],
                decoration: InputDecoration(
                  labelText: l10n.profileBioLabel,
                  errorText: _errors.contains(ProfileEditField.bio)
                      ? l10n.profileBioTooLong
                      : _errors.contains(ProfileEditField.bioLineBreaks)
                      ? l10n.profileBioTooManyLines
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('profileEditIdentityDoneButton'),
                  onPressed: _apply,
                  child: Text(l10n.profileComposeDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cover chooser. Only platforms that publish art are offered — an option
/// that would leave the cover exactly as it is answers nothing. The stored
/// choice is always listed even when its platform publishes nothing today, so a
/// preference the owner made stays visible and clearable.
class _CoverSheet extends ConsumerWidget {
  const _CoverSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(
      profileCompositionProvider.select((s) => s.draft?.headerPlatform),
    );
    final cards = <Platform, GameCard?>{
      for (final platform in Platform.values)
        platform: resolveCard(ref, null, platform),
    };
    final offered = [
      for (final platform in Platform.values)
        if (artOf(cards[platform]) != null || platform == selected) platform,
    ];

    void choose(Platform? platform) {
      ref
          .read(profileCompositionProvider.notifier)
          .selectHeaderPlatform(platform);
      Navigator.of(context).pop();
    }

    return SafeArea(
      key: const Key('profileEditCoverSheet'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.profileEditCover,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            key: const Key('profileEditCoverOption_auto'),
            title: Text(l10n.profileHeaderArtDefault),
            trailing: selected == null ? const Icon(Icons.check) : null,
            onTap: () => choose(null),
          ),
          for (final platform in offered)
            ListTile(
              key: Key('profileEditCoverOption_${platform.name}'),
              title: Text(platformDescriptors[platform]!.displayName),
              trailing: selected == platform ? const Icon(Icons.check) : null,
              onTap: () => choose(platform),
            ),
        ],
      ),
    );
  }
}

/// Rejects edits that would push the bio past [max] line breaks, so the user
/// cannot enter a bio that drives their profile cards far down the screen.
class _MaxLineBreaksFormatter extends TextInputFormatter {
  const _MaxLineBreaksFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => '\n'.allMatches(newValue.text).length > max ? oldValue : newValue;
}
