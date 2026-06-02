import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../core/error/failure.dart';
import 'otp_controller.dart';

/// Email OTP sign-in screen.
///
/// Renders two steps driven by [OtpController]:
///   1. Email step — user enters their address and taps "Send code".
///   2. Code step — user enters the 6-digit code, can resend or edit email.
///
/// Navigation after a successful verify is driven by the auth-status stream
/// (router redirect); this screen never calls go_router directly.
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: otpState.step == OtpStep.email
              ? _EmailStep(
                  l10n: l10n,
                  emailController: _emailController,
                  formKey: _emailFormKey,
                  failure: otpState.failure,
                  cooldownActive: otpState.cooldownActive,
                  onSubmit: () async {
                    if (_emailFormKey.currentState?.validate() ?? false) {
                      await controller.requestCode(
                        _emailController.text.trim(),
                      );
                    }
                  },
                )
              : _CodeStep(
                  l10n: l10n,
                  email: otpState.email,
                  codeController: _codeController,
                  formKey: _codeFormKey,
                  failure: otpState.failure,
                  cooldownActive: otpState.cooldownActive,
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
                ),
        ),
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.l10n,
    required this.emailController,
    required this.formKey,
    required this.failure,
    required this.cooldownActive,
    required this.onSubmit,
  });

  final AppLocalizations l10n;
  final TextEditingController emailController;
  final GlobalKey<FormState> formKey;
  final Failure? failure;

  /// True while backing off after a rate-limit; the send action is disabled.
  final bool cooldownActive;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
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
            decoration: InputDecoration(
              labelText: l10n.signInEmailLabel,
              hintText: l10n.signInEmailHint,
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: cooldownActive ? null : (_) => onSubmit(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.signInEmailHint;
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
            onPressed: cooldownActive ? null : onSubmit,
            child: Text(l10n.signInSendCode),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.l10n,
    required this.email,
    required this.codeController,
    required this.formKey,
    required this.failure,
    required this.cooldownActive,
    required this.onVerify,
    required this.onResend,
    required this.onEditEmail,
  });

  final AppLocalizations l10n;
  final String email;
  final TextEditingController codeController;
  final GlobalKey<FormState> formKey;
  final Failure? failure;

  /// True while backing off after a rate-limit; verify and resend are disabled.
  final bool cooldownActive;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onEditEmail;

  String _errorText(AppLocalizations l10n, Failure failure) {
    if (failure is InputFailure) return l10n.signInInvalidCode;
    return failure.localizedMessage(l10n);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
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
          Text(email, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: codeController,
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
            onFieldSubmitted: cooldownActive ? null : (_) => onVerify(),
            validator: (value) {
              if (value == null || value.trim().length != 6) {
                return l10n.signInCodeHint;
              }
              return null;
            },
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.smMd),
            Text(
              _errorText(l10n, failure!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: cooldownActive ? null : onVerify,
            child: Text(l10n.signInVerify),
          ),
          const SizedBox(height: AppSpacing.smMd),
          TextButton(
            onPressed: cooldownActive ? null : onResend,
            child: Text(l10n.signInResend),
          ),
          TextButton(onPressed: onEditEmail, child: Text(l10n.signInEditEmail)),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
