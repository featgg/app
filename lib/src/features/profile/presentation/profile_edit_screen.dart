import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/profile.dart';
import 'avatar_picker.dart';
import 'avatar_upload_controller.dart';
import 'featured_platform_provider.dart';
import 'personalization_theme_palette.dart';
import 'profile_edit_controller.dart';

/// Edit form for the signed-in user's own profile.
///
/// Seeded from the [profile] passed via the router's extra parameter so the
/// form opens pre-filled without a redundant network read. On a successful
/// save, pops back to the profile view and shows a confirmation snackbar.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  /// The two text controllers are all the widget owns: a cursor and a selection
  /// are widget lifecycle, and nothing else here is. Every value the form can
  /// submit lives in [ProfileEditController].
  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');

    _displayNameController.addListener(_onDisplayNameChanged);
    _bioController.addListener(_onBioChanged);
  }

  ProfileEditController get _controller =>
      ref.read(profileEditControllerProvider(widget.profile).notifier);

  void _onDisplayNameChanged() =>
      _controller.editDisplayName(_displayNameController.text);

  void _onBioChanged() => _controller.editBio(_bioController.text);

  @override
  void dispose() {
    _displayNameController.removeListener(_onDisplayNameChanged);
    _bioController.removeListener(_onBioChanged);
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// The connected platforms plus [seeded], so a stored preference naming a
  /// platform the owner has since unlinked still has an item to select — a
  /// Material dropdown asserts on a value absent from its items.
  List<Platform> _selectableWith(List<Platform> connected, Platform? seeded) =>
      {
        ...connected,
        ...?(seeded != null ? [seeded] : null),
      }.toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editState = ref.watch(profileEditControllerProvider(widget.profile));
    final draft = editState.draft;
    final controller = _controller;
    final uploadState = ref.watch(avatarUploadControllerProvider);

    ref.listen(
      profileEditControllerProvider(widget.profile).select((s) => s.saved),
      (previous, next) {
        if (next) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
        }
      },
    );

    ref.listen(avatarUploadControllerProvider, (previous, next) {
      if (next.status == AvatarUploadStatus.success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('avatarUploadSuccessSnackBar'),
              content: Text(l10n.profileAvatarUpdated),
            ),
          );
      } else if (next.status == AvatarUploadStatus.error &&
          next.failure != null &&
          next.failure is! RateLimitFailure) {
        // Cooldown (RateLimitFailure) renders an inline countdown affordance
        // instead of a transient snackbar — do not snackbar on cooldown.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('avatarUploadErrorSnackBar'),
              content: Text(next.failure!.localizedMessage(l10n)),
            ),
          );
      } else if (next.status == AvatarUploadStatus.error &&
          next.failure is RateLimitFailure) {
        // Cooldown shows an inline countdown; dismiss any lingering snackbar so
        // a stale success/error message doesn't sit alongside the countdown.
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });

    final fieldErrors = editState.fieldErrors;

    // Popping while an avatar upload is in-flight would dispose the auto-dispose
    // controller before it can invalidate profileProvider on success, leaving
    // the view stale. Block Save until the upload pipeline settles.
    final avatarInFlight =
        uploadState.status == AvatarUploadStatus.picking ||
        uploadState.status == AvatarUploadStatus.uploading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileEditTitle),
        actions: [
          _SaveButton(
            key: const Key('profileSaveButton'),
            submitting: editState.submitting,
            onPressed:
                (editState.isDirty && !editState.submitting && !avatarInFlight)
                ? controller.submit
                : null,
            l10n: l10n,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AvatarUploadField(
                        key: const Key('avatarUploadField'),
                        avatarUrl:
                            uploadState.newAvatarUrl ??
                            widget.profile.avatarUrl,
                        uploadState: uploadState,
                        l10n: l10n,
                        onTap: () => ref
                            .read(avatarUploadControllerProvider.notifier)
                            .pickAndUpload(
                              () => ref
                                  .read(avatarPickerProvider)
                                  .pickAndCrop(context),
                            ),
                      ),
                      if (uploadState.onCooldown &&
                          uploadState.cooldownUntil != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        CooldownCountdown(
                          key: const Key('avatarCooldownCountdown'),
                          until: uploadState.cooldownUntil!,
                          label: (s) => l10n.profileAvatarCooldownCountdown(s),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('profileDisplayNameField'),
                        controller: _displayNameController,
                        enabled: !editState.submitting,
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: l10n.profileDisplayNameLabel,
                          errorText:
                              fieldErrors.contains(ProfileEditField.displayName)
                              ? l10n.profileDisplayNameInvalid
                              : null,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('profileBioField'),
                        controller: _bioController,
                        enabled: !editState.submitting,
                        maxLength: 150,
                        minLines: 4,
                        maxLines: 4,
                        inputFormatters: const [
                          _MaxLineBreaksFormatter(kMaxBioLineBreaks),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.profileBioLabel,
                          errorText: fieldErrors.contains(ProfileEditField.bio)
                              ? l10n.profileBioTooLong
                              : fieldErrors.contains(
                                  ProfileEditField.bioLineBreaks,
                                )
                              ? l10n.profileBioTooManyLines
                              : null,
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.profileThemeLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ThemeSwatchRow(
                        key: const Key('profileThemeSwatchRow'),
                        selected: draft.theme,
                        enabled: !editState.submitting,
                        onChanged: controller.selectTheme,
                        l10n: l10n,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // The header art stays here because it is visible on the
                      // profile; the feed preview moved to settings, which is
                      // where the choices about surfaces the owner cannot see
                      // from their own page belong.
                      AsyncValueWidget<List<Platform>>(
                        key: const Key('headerArtAsyncSection'),
                        value: ref.watch(connectedPlatformsProvider),
                        onRetry: () =>
                            ref.invalidate(connectedPlatformsProvider),
                        data: (platforms) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.profileHeaderArtLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _PlatformPreferenceSelector(
                              key: const Key('headerArtSelector'),
                              dropdownKey: const Key('headerArtDropdown'),
                              selected: draft.headerPlatform,
                              platforms: _selectableWith(
                                platforms,
                                draft.headerPlatform,
                              ),
                              enabled: !editState.submitting,
                              defaultLabel: l10n.profileHeaderArtDefault,
                              onChanged: controller.selectHeaderPlatform,
                            ),
                          ],
                        ),
                      ),
                      if (editState.failure != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          key: const Key('profileEditErrorText'),
                          editState.failure!.localizedMessage(l10n),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarUploadField extends StatelessWidget {
  const _AvatarUploadField({
    super.key,
    required this.avatarUrl,
    required this.uploadState,
    required this.l10n,
    required this.onTap,
  });

  final String? avatarUrl;
  final AvatarUploadState uploadState;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  bool get _inFlight =>
      uploadState.status == AvatarUploadStatus.picking ||
      uploadState.status == AvatarUploadStatus.uploading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = AppSpacing.xl * 2;

    Widget avatar;
    if (avatarUrl != null) {
      avatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (context, _) => _iconPlaceholder(colorScheme, size),
          errorWidget: (context, _, _) => _iconPlaceholder(colorScheme, size),
          imageBuilder: (_, imageProvider) => Semantics(
            label: l10n.profileAvatarLabel,
            image: true,
            child: Image(
              image: imageProvider,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else {
      avatar = Semantics(
        label: l10n.profileAvatarLabel,
        child: _iconPlaceholder(colorScheme, size),
      );
    }

    final bool disabled = _inFlight || uploadState.onCooldown;

    return Align(
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Tooltip(
          message: l10n.profileAvatarChange,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Semantics(
                label: _inFlight ? l10n.profileAvatarUploading : null,
                child: Opacity(opacity: _inFlight ? 0.5 : 1.0, child: avatar),
              ),
              if (_inFlight)
                const SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              else
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: AppSpacing.sm,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.edit,
                      size: AppSpacing.sm,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconPlaceholder(ColorScheme colorScheme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        Icons.person,
        size: size / 2,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    super.key,
    required this.submitting,
    required this.onPressed,
    required this.l10n,
  });

  final bool submitting;
  final VoidCallback? onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: submitting
        ? const SizedBox.square(
            dimension: AppSpacing.md,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : Text(l10n.profileSave),
  );
}

/// A display preference picked from the platforms the owner has linked, with a
/// leading option that clears it. Shared by the two such preferences on this
/// screen — which card fronts the profile in the feed, and which platform's art
/// sits behind the identity — so both read and behave identically.
class _PlatformPreferenceSelector extends StatelessWidget {
  const _PlatformPreferenceSelector({
    super.key,
    required this.dropdownKey,
    required this.selected,
    required this.platforms,
    required this.enabled,
    required this.defaultLabel,
    required this.onChanged,
  });

  final Key dropdownKey;
  final Platform? selected;
  final List<Platform> platforms;
  final bool enabled;

  /// Copy for the option that stores no preference.
  final String defaultLabel;

  final ValueChanged<Platform?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<Platform?>(
    key: dropdownKey,
    initialValue: selected,
    onChanged: enabled ? onChanged : null,
    items: [
      DropdownMenuItem<Platform?>(value: null, child: Text(defaultLabel)),
      ...platforms.map(
        (p) => DropdownMenuItem<Platform?>(
          value: p,
          child: Text(platformDescriptors[p]!.displayName),
        ),
      ),
    ],
  );
}

/// The theme picker: one accent-filled swatch per curated theme. The
/// selected swatch carries a Material ring; tapping another selects it. Swatch
/// fill is the theme's accent token, never a literal.
class _ThemeSwatchRow extends StatelessWidget {
  const _ThemeSwatchRow({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.l10n,
  });

  final ProfileTheme selected;
  final bool enabled;
  final ValueChanged<ProfileTheme> onChanged;
  final AppLocalizations l10n;

  /// Swatch diameter and the ring gap reserved around every swatch so selecting
  /// one does not shift the row.
  static const double _swatchSize = AppSpacing.xl;
  static const double _ringGap = AppSpacing.xs;

  String _label(ProfileTheme t) => switch (t) {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ProfileTheme.values.map((t) {
        final isSelected = t == selected;
        return Semantics(
          key: Key('profileThemeSwatch_${t.name}'),
          button: true,
          selected: isSelected,
          label: _label(t),
          child: InkWell(
            onTap: enabled ? () => onChanged(t) : null,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(_ringGap),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
              child: Container(
                width: _swatchSize,
                height: _swatchSize,
                decoration: BoxDecoration(
                  color: paletteForTheme(t).accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
