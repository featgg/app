import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import 'otp_controller.dart';

/// Loose email format gate: one `@`, at least one dot in the domain, no
/// whitespace. The server is authoritative on address validity; this is fast
/// UX feedback only.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Email OTP sign-in screen.
///
/// Renders two steps driven by [OtpController]:
///   1. Email step — user enters their address and taps "Continue".
///   2. Code step — user enters the 6-digit code, can resend or edit email.
///
/// Navigation after a successful verify is driven by the auth-status stream
/// (router redirect); this screen never calls go_router directly. The content
/// scrolls so the soft keyboard never overflows it.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final otpState = ref.watch(otpControllerProvider);
    final controller = ref.read(otpControllerProvider.notifier);

    // A successful resend leaves the screen visually unchanged (still the code
    // step, countdown restarted), so confirm it with a transient snackbar. The
    // initial send is excluded — its feedback is the step change.
    ref.listen(otpControllerProvider.select((s) => s.resendSuccessTick), (
      previous,
      next,
    ) {
      if (previous != null && next > previous) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.signInResendSuccess)));
      }
    });

    final step = otpState.step == OtpStep.email
        ? _EmailStep(
            l10n: l10n,
            emailController: _emailController,
            formKey: _emailFormKey,
            failure: otpState.failure,
            submitting: otpState.submitting,
            sendCooldownActive: otpState.sendCooldownActive,
            onSubmit: () async {
              if (_emailFormKey.currentState?.validate() ?? false) {
                await controller.requestCode(_emailController.text.trim());
              }
            },
          )
        : _CodeStep(
            l10n: l10n,
            email: otpState.email,
            codeController: _codeController,
            formKey: _codeFormKey,
            failure: otpState.failure,
            submitting: otpState.submitting,
            sendCooldownActive: otpState.sendCooldownActive,
            verifyCooldownActive: otpState.verifyCooldownActive,
            resendSecondsRemaining: otpState.resendSecondsRemaining,
            onVerify: () async {
              if (_codeFormKey.currentState?.validate() ?? false) {
                await controller.verifyCode(_codeController.text.trim());
              }
            },
            onResend: controller.resendCode,
            onEditEmail: () {
              _emailController.clear();
              _codeController.clear();
              controller.editEmail();
            },
          );

    // Fill the viewport when there is room (Spacers center the content) and
    // scroll when the keyboard shrinks it, so the layout never overflows.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: step,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small adaptive spinner shown inside a primary button while a call is in
/// flight (design-system § 11.3: spinner for button submit state).
class _SubmitSpinner extends StatelessWidget {
  const _SubmitSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: AppSpacing.md,
    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
  );
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.l10n,
    required this.emailController,
    required this.formKey,
    required this.failure,
    required this.submitting,
    required this.sendCooldownActive,
    required this.onSubmit,
  });

  final AppLocalizations l10n;
  final TextEditingController emailController;
  final GlobalKey<FormState> formKey;
  final Failure? failure;
  final bool submitting;

  /// True while backing off after a send/resend rate-limit; the send action is
  /// disabled.
  final bool sendCooldownActive;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final blocked = submitting || sendCooldownActive;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            l10n.signInTitle,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: emailController,
            enabled: !submitting,
            decoration: InputDecoration(
              labelText: l10n.signInEmailLabel,
              hintText: l10n.signInEmailHint,
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: blocked ? null : (_) => onSubmit(),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return l10n.signInEmailHint;
              if (!_emailPattern.hasMatch(trimmed)) {
                return l10n.signInInvalidEmail;
              }
              return null;
            },
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.smMd),
            Text(
              failure!.localizedMessage(l10n),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: blocked ? null : onSubmit,
            child: submitting
                ? const _SubmitSpinner()
                : Text(l10n.signInContinue),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _CodeStep extends StatefulWidget {
  const _CodeStep({
    required this.l10n,
    required this.email,
    required this.codeController,
    required this.formKey,
    required this.failure,
    required this.submitting,
    required this.sendCooldownActive,
    required this.verifyCooldownActive,
    required this.resendSecondsRemaining,
    required this.onVerify,
    required this.onResend,
    required this.onEditEmail,
  });

  final AppLocalizations l10n;
  final String email;
  final TextEditingController codeController;
  final GlobalKey<FormState> formKey;
  final Failure? failure;
  final bool submitting;

  /// True while backing off after a send/resend rate-limit.
  final bool sendCooldownActive;

  /// True while backing off after a verify rate-limit; independent of the send
  /// cooldown.
  final bool verifyCooldownActive;

  /// Initial seconds remaining for the proactive resend window seeded on each
  /// successful send. When > 0 this widget starts a 1 s display ticker.
  final int resendSecondsRemaining;

  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onEditEmail;

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  // Remaining seconds for the proactive resend display countdown. The widget
  // owns the live decrement; the controller only seeds the initial value.
  int _remaining = 0;
  Timer? _displayTicker;

  @override
  void initState() {
    super.initState();
    widget.codeController.addListener(_onCodeChanged);
    _startCountdownIfNeeded(widget.resendSecondsRemaining);
  }

  @override
  void didUpdateWidget(_CodeStep old) {
    super.didUpdateWidget(old);
    if (widget.resendSecondsRemaining != old.resendSecondsRemaining) {
      _startCountdownIfNeeded(widget.resendSecondsRemaining);
    }
  }

  @override
  void dispose() {
    _displayTicker?.cancel();
    widget.codeController.removeListener(_onCodeChanged);
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

  String _errorText(AppLocalizations l10n, Failure failure) {
    if (failure is InputFailure) return l10n.signInInvalidCode;
    return failure.localizedMessage(l10n);
  }

  /// Formats remaining seconds as `m:ss` for the countdown label.
  String _formatRemaining(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final code = widget.codeController.text;
    final codeIsSubmittable = code.length == 6;
    final resendBlocked =
        widget.submitting || widget.sendCooldownActive || _remaining > 0;
    final verifyBlocked =
        widget.submitting || widget.verifyCooldownActive || !codeIsSubmittable;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            l10n.signInCodeTitle,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(widget.email, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: widget.codeController,
            enabled: !widget.submitting,
            decoration: InputDecoration(
              labelText: l10n.signInCodeLabel,
              hintText: l10n.signInCodeHint,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: verifyBlocked ? null : (_) => widget.onVerify(),
            validator: (value) {
              if (value == null || value.trim().length != 6) {
                return l10n.signInCodeHint;
              }
              return null;
            },
          ),
          if (widget.failure != null) ...[
            const SizedBox(height: AppSpacing.smMd),
            Text(
              _errorText(l10n, widget.failure!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: verifyBlocked ? null : widget.onVerify,
            child: widget.submitting
                ? const _SubmitSpinner()
                : Text(l10n.signInVerify),
          ),
          const SizedBox(height: AppSpacing.smMd),
          TextButton(
            onPressed: resendBlocked ? null : widget.onResend,
            child: Text(
              _remaining > 0
                  ? l10n.signInResendCountdown(_formatRemaining(_remaining))
                  : l10n.signInResend,
            ),
          ),
          TextButton(
            onPressed: (widget.submitting || widget.sendCooldownActive)
                ? null
                : widget.onEditEmail,
            child: Text(l10n.signInEditEmail),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
