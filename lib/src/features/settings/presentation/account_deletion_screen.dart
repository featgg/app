import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import 'account_deletion_controller.dart';

/// Account-deletion flow screen. Three steps driven by
/// [AccountDeletionController]:
///   1. Idle — intent + confirm dialog → requestCode.
///   2. Awaiting code — 6-digit code entry + resend + confirm.
///   3. Scheduled — shows the target deletion date.
///
/// Navigation after a successful confirm stays on this screen (scheduled step);
/// the account is not deleted until the grace period expires and the session
/// remains valid. The auth-status stream drives a re-auth redirect if the
/// session is invalidated during the flow.
class AccountDeletionScreen extends ConsumerWidget {
  const AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(accountDeletionControllerProvider);
    final controller = ref.read(accountDeletionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: SafeArea(
        child: switch (s.step) {
          DeletionStep.idle => _IdleStep(
            l10n: l10n,
            submitting: s.submitting,
            requestCooldownActive: s.requestCooldownActive,
            failure: s.failure,
            onRequest: () => _showConfirmDialog(context, l10n, controller),
          ),
          DeletionStep.awaitingCode => _AwaitingCodeStep(
            l10n: l10n,
            submitting: s.submitting,
            requestCooldownActive: s.requestCooldownActive,
            requestCooldownSeconds: s.requestCooldownSeconds,
            requestCooldownTick: s.requestCooldownTick,
            failure: s.failure,
            onConfirm: controller.confirmCode,
            onResend: controller.requestCode,
          ),
          DeletionStep.scheduled => _ScheduledStep(
            l10n: l10n,
            scheduledAt: s.scheduledAt!,
            submitting: s.submitting,
            failure: s.failure,
            onCancel: controller.cancelDeletion,
          ),
          DeletionStep.cancelled => _CancelledStep(l10n: l10n),
        },
      ),
    );
  }

  Future<void> _showConfirmDialog(
    BuildContext context,
    AppLocalizations l10n,
    AccountDeletionController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmDialogTitle),
        content: Text(l10n.deleteAccountConfirmDialogBody),
        actions: [
          TextButton(
            key: const Key('deleteAccountConfirmDialogCancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.deleteAccountConfirmDialogCancel),
          ),
          TextButton(
            key: const Key('deleteAccountConfirmDialogConfirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteAccountConfirmDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.requestCode();
    }
  }
}

class _IdleStep extends StatelessWidget {
  const _IdleStep({
    required this.l10n,
    required this.submitting,
    required this.requestCooldownActive,
    required this.failure,
    required this.onRequest,
  });

  final AppLocalizations l10n;
  final bool submitting;
  final bool requestCooldownActive;
  final Failure? failure;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.deleteAccountIntroBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.smMd),
            Text(
              failure!.localizedMessage(l10n),
              key: const Key('deleteAccountIdleError'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            key: const Key('deleteAccountRequestButton'),
            onPressed: (submitting || requestCooldownActive) ? null : onRequest,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: submitting
                ? const _SubmitSpinner()
                : Text(l10n.deleteAccountRequestButton),
          ),
        ],
      ),
    );
  }
}

class _AwaitingCodeStep extends StatefulWidget {
  const _AwaitingCodeStep({
    required this.l10n,
    required this.submitting,
    required this.requestCooldownActive,
    required this.requestCooldownSeconds,
    required this.requestCooldownTick,
    required this.failure,
    required this.onConfirm,
    required this.onResend,
  });

  final AppLocalizations l10n;
  final bool submitting;
  final bool requestCooldownActive;
  final int requestCooldownSeconds;
  final int requestCooldownTick;
  final Failure? failure;
  final Future<void> Function(String code) onConfirm;
  final Future<void> Function() onResend;

  @override
  State<_AwaitingCodeStep> createState() => _AwaitingCodeStepState();
}

class _AwaitingCodeStepState extends State<_AwaitingCodeStep> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _remaining = 0;
  Timer? _displayTicker;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    _startCountdownIfNeeded(widget.requestCooldownSeconds);
  }

  @override
  void didUpdateWidget(_AwaitingCodeStep old) {
    super.didUpdateWidget(old);
    // Restart the display countdown when a new send succeeds. The tick
    // increments even though the seeded seconds are the same window (30 → 30),
    // so a tick change is the reliable signal for a fresh send.
    if (widget.requestCooldownTick != old.requestCooldownTick) {
      _startCountdownIfNeeded(widget.requestCooldownSeconds);
    }
  }

  @override
  void dispose() {
    _displayTicker?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() => setState(() {});

  void _startCountdownIfNeeded(int seconds) {
    _displayTicker?.cancel();
    _displayTicker = null;
    if (seconds <= 0) {
      setState(() => _remaining = 0);
      return;
    }
    setState(() => _remaining = seconds);
    _displayTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _remaining = 0;
          _displayTicker?.cancel();
          _displayTicker = null;
        }
      });
    });
  }

  String _formatRemaining(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _errorText(AppLocalizations l10n, Failure failure) {
    if (failure is InputFailure) return l10n.deleteAccountInvalidCode;
    return failure.localizedMessage(l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final code = _codeController.text;
    final codeReady = code.length == 6;
    final cooldownActive = widget.requestCooldownActive || _remaining > 0;
    final confirmBlocked = widget.submitting || !codeReady || cooldownActive;
    final resendBlocked = widget.submitting || cooldownActive;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const Key('deleteAccountCodeField'),
              controller: _codeController,
              enabled: !widget.submitting,
              decoration: InputDecoration(
                labelText: l10n.deleteAccountCodeLabel,
                hintText: l10n.deleteAccountCodeHint,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: confirmBlocked
                  ? null
                  : (_) async {
                      if (_formKey.currentState?.validate() ?? false) {
                        await widget.onConfirm(_codeController.text.trim());
                      }
                    },
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return l10n.deleteAccountCodeHint;
                }
                return null;
              },
            ),
            if (widget.failure != null) ...[
              const SizedBox(height: AppSpacing.smMd),
              Text(
                _errorText(l10n, widget.failure!),
                key: const Key('deleteAccountCodeError'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('deleteAccountConfirmButton'),
              onPressed: confirmBlocked
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        await widget.onConfirm(_codeController.text.trim());
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: widget.submitting
                  ? const _SubmitSpinner()
                  : Text(l10n.deleteAccountConfirmButton),
            ),
            const SizedBox(height: AppSpacing.smMd),
            TextButton(
              key: const Key('deleteAccountResendButton'),
              onPressed: resendBlocked ? null : widget.onResend,
              child: Text(
                _remaining > 0
                    ? l10n.deleteAccountResendCountdown(
                        _formatRemaining(_remaining),
                      )
                    : l10n.deleteAccountResend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledStep extends StatelessWidget {
  const _ScheduledStep({
    required this.l10n,
    required this.scheduledAt,
    required this.submitting,
    required this.failure,
    required this.onCancel,
  });

  final AppLocalizations l10n;
  final DateTime scheduledAt;
  final bool submitting;
  final Failure? failure;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final formattedDate = DateFormat.yMMMMd(locale).format(scheduledAt);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.deleteAccountScheduledTitle,
            key: const Key('deleteAccountScheduledTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.smMd),
          Text(
            l10n.deleteAccountScheduledBody(formattedDate),
            key: const Key('deleteAccountScheduledBody'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.smMd),
            Text(
              failure!.localizedMessage(l10n),
              key: const Key('deleteAccountCancelError'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('deleteAccountCancelButton'),
            onPressed: submitting ? null : onCancel,
            child: submitting
                ? const _SubmitSpinner()
                : Text(l10n.deleteAccountCancelButton),
          ),
        ],
      ),
    );
  }
}

class _CancelledStep extends StatelessWidget {
  const _CancelledStep({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.deleteAccountCancelledTitle,
            key: const Key('deleteAccountCancelledTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.smMd),
          Text(
            l10n.deleteAccountCancelledBody,
            key: const Key('deleteAccountCancelledBody'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SubmitSpinner extends StatelessWidget {
  const _SubmitSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: AppSpacing.md,
    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
  );
}
