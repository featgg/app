import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import '../domain/profile.dart';
import 'avatar_picker.dart';
import 'avatar_upload_controller.dart';
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
  late ProfileTheme _selectedTheme;
  late ProfilePrivacy _selectedPrivacy;

  late final ProfileEdit _seed;

  void _onFieldChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _selectedTheme = widget.profile.theme;
    _selectedPrivacy = widget.profile.privacy;
    _seed = _editFrom(widget.profile);

    _displayNameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Builds a [ProfileEdit] from a seed [Profile].
  ProfileEdit _editFrom(Profile p) {
    final bioRaw = (p.bio ?? '').trim();
    return ProfileEdit(
      displayName: p.displayName.trim(),
      bio: bioRaw.isEmpty ? null : bioRaw,
      theme: p.theme,
      privacy: p.privacy,
    );
  }

  ProfileEdit _buildEdit() {
    final bioRaw = _bioController.text.trim();
    return ProfileEdit(
      displayName: _displayNameController.text.trim(),
      bio: bioRaw.isEmpty ? null : bioRaw,
      theme: _selectedTheme,
      privacy: _selectedPrivacy,
    );
  }

  bool get _isDirty => _buildEdit() != _seed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editState = ref.watch(profileEditControllerProvider);
    final controller = ref.read(profileEditControllerProvider.notifier);
    final uploadState = ref.watch(avatarUploadControllerProvider);

    ref.listen(profileEditControllerProvider.select((s) => s.saved), (
      previous,
      next,
    ) {
      if (next) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      }
    });

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
            onPressed: (_isDirty && !editState.submitting && !avatarInFlight)
                ? () => controller.submit(_buildEdit())
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
                        decoration: InputDecoration(
                          labelText: l10n.profileBioLabel,
                          errorText: fieldErrors.contains(ProfileEditField.bio)
                              ? l10n.profileBioTooLong
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
                      _ThemeSelector(
                        selected: _selectedTheme,
                        enabled: !editState.submitting,
                        onChanged: (t) => setState(() => _selectedTheme = t),
                        l10n: l10n,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.profilePrivacyLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _PrivacySelector(
                        selected: _selectedPrivacy,
                        enabled: !editState.submitting,
                        onChanged: (p) => setState(() => _selectedPrivacy = p),
                        l10n: l10n,
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

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.l10n,
  });

  final ProfileTheme selected;
  final bool enabled;
  final ValueChanged<ProfileTheme> onChanged;
  final AppLocalizations l10n;

  String _label(ProfileTheme t) => switch (t) {
    ProfileTheme.classic => l10n.profileThemeClassic,
    ProfileTheme.immersive => l10n.profileThemeImmersive,
    ProfileTheme.retro => l10n.profileThemeRetro,
    ProfileTheme.analyst => l10n.profileThemeAnalyst,
  };

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<ProfileTheme>(
    initialValue: selected,
    onChanged: enabled ? (v) => onChanged(v!) : null,
    items: ProfileTheme.values
        .map((t) => DropdownMenuItem(value: t, child: Text(_label(t))))
        .toList(),
  );
}

class _PrivacySelector extends StatelessWidget {
  const _PrivacySelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.l10n,
  });

  final ProfilePrivacy selected;
  final bool enabled;
  final ValueChanged<ProfilePrivacy> onChanged;
  final AppLocalizations l10n;

  String _label(ProfilePrivacy p) => switch (p) {
    ProfilePrivacy.public => l10n.profilePrivacyPublic,
    ProfilePrivacy.private => l10n.profilePrivacyPrivate,
  };

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<ProfilePrivacy>(
    initialValue: selected,
    onChanged: enabled ? (v) => onChanged(v!) : null,
    items: ProfilePrivacy.values
        .map((p) => DropdownMenuItem(value: p, child: Text(_label(p))))
        .toList(),
  );
}
