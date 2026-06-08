import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/auth.dart';
import '../theme.dart';
import 'shell.dart';

enum _Mode { signIn, signUp }

int _extractRetrySeconds(String message) {
  final lower = message.toLowerCase();
  final match = RegExp(r'(\d+)').firstMatch(lower);
  final value = int.tryParse(match?.group(1) ?? '');
  if (value == null || value <= 0) return 90;
  if (lower.contains('minute')) return value * 60;
  return value;
}

String _friendlyAuthMessage(AuthException e) {
  final status = e.statusCode ?? '';
  final message = e.message.toLowerCase();
  if (status == '429') {
    return 'Too many attempts right now. Please wait a minute and try again.';
  }
  if (message.contains('email not confirmed') ||
      message.contains('not confirmed')) {
    return 'Email not confirmed yet. Enter the verification code from your email.';
  }
  if (status == '400' &&
      (message.contains('invalid login') ||
          message.contains('invalid credentials'))) {
    return 'Incorrect email or password.';
  }
  return e.message;
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.popOnSuccess = true,
  });

  final bool popOnSuccess;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  _Mode _mode = _Mode.signIn;
  bool _loading = false;
  String? _error;
  bool _showPassword = false;
  int _failedAttempts = 0;
  DateTime? _blockedUntil;
  Timer? _cooldownTicker;

  void _startCooldownTicker() {
    if (_cooldownTicker?.isActive == true) return;
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopCooldownTicker();
        return;
      }
      if (!_isBlocked) {
        _stopCooldownTicker();
      }
      setState(() {});
    });
  }

  void _stopCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = null;
  }

  void _setBlockedUntil(DateTime until) {
    if (_blockedUntil == null || until.isAfter(_blockedUntil!)) {
      _blockedUntil = until;
      _startCooldownTicker();
    }
  }

  bool _isRateLimited(AuthException e) {
    final message = e.message.toLowerCase();
    return e.statusCode == '429' || message.contains('too many requests');
  }

  void _applyRateLimit(AuthException e) {
    final seconds = math.max(_extractRetrySeconds(e.message), 30);
    _setBlockedUntil(DateTime.now().add(Duration(seconds: seconds)));
  }

  @override
  void dispose() {
    _stopCooldownTicker();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_isBlocked) {
      setState(
        () =>
            _error = 'Requests are temporarily limited. Try again in ${_remainingBlock}s.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    if (_mode == _Mode.signUp && password != _confirmPasswordCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final controller = ref.read(authControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_mode == _Mode.signIn) {
        await controller.signIn(
          email: email,
          password: password,
        );
        _resetFailures();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Welcome back to More Properties.')),
        );
        if (widget.popOnSuccess) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        }
      } else {
        await controller.signUp(
          email: email,
          password: password,
          fullName: _nameCtrl.text.trim(),
        );

        final signedInImmediately = ref.read(isSignedInProvider);
        if (signedInImmediately) {
          await controller.signOut();
          if (!mounted) return;
          setState(() {
            _error =
                'Email verification code is not enabled yet. In Supabase Auth settings, turn on Confirm email.';
          });
          return;
        }

        if (!mounted) return;

        final verified = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _VerifySignUpCodeScreen(
              email: email,
              password: password,
            ),
          ),
        );

        if (!mounted) return;
        if (verified != true) {
          return;
        }

        _resetFailures();
        setState(() {
          _mode = _Mode.signIn;
          _passwordCtrl.clear();
          _confirmPasswordCtrl.clear();
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Profile confirmed. You are now signed in.'),
          ),
        );
        if (widget.popOnSuccess) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        }
      }
    } on AuthException catch (e) {
      if (_isRateLimited(e)) {
        _applyRateLimit(e);
      }
      _registerFailure();
      if (mounted) setState(() => _error = _friendlyAuthMessage(e));
    } catch (e) {
      _registerFailure();
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMagicLink() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider).sendMagicLink(email);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('If your email is registered, a magic link was sent.'),
        ),
      );
    } on AuthException catch (e) {
      if (_isRateLimited(e)) {
        _applyRateLimit(e);
      }
      if (mounted) setState(() => _error = _friendlyAuthMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email to receive a reset link.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider).resetPassword(email);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('If your email exists, a password reset link was sent.'),
        ),
      );
    } on AuthException catch (e) {
      if (_isRateLimited(e)) {
        _applyRateLimit(e);
      }
      if (mounted) setState(() => _error = _friendlyAuthMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _oauthSignIn(Future<void> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (_isRateLimited(e)) {
        _applyRateLimit(e);
      }
      if (mounted) setState(() => _error = _friendlyAuthMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'OAuth sign-in is not available right now.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isBlocked =>
      _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

  int get _remainingBlock {
    if (_blockedUntil == null) return 0;
    final seconds = _blockedUntil!.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  void _registerFailure() {
    _failedAttempts += 1;
    if (_failedAttempts >= 5) {
      _setBlockedUntil(DateTime.now().add(const Duration(seconds: 30)));
      _failedAttempts = 0;
    }
  }

  void _resetFailures() {
    _failedAttempts = 0;
    _blockedUntil = null;
    _stopCooldownTicker();
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(supabaseConfiguredProvider);
    final isSignUp = _mode == _Mode.signUp;
    final canUseApple =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isSignUp
                      ? 'Create your More Properties account'
                      : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Save favourites, set alerts and message verified SA agents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 26),
                if (!configured)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      'Supabase keys are not configured for this build. Run with --dart-define-from-file=supabase/dart_defines.json to enable sign-in.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (!configured) const SizedBox(height: 20),
                _ModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() {
                    _mode = m;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 18),
                if (isSignUp) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Email required';
                    if (!_emailPattern.hasMatch(s)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  textInputAction:
                      isSignUp ? TextInputAction.next : TextInputAction.done,
                  obscureText: !_showPassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) {
                    final p = v ?? '';
                    if (p.isEmpty) return 'Password required';
                    if (!isSignUp) return null;
                    if (p.length < 8) return 'At least 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(p)) {
                      return 'Include an uppercase letter';
                    }
                    if (!RegExp(r'[a-z]').hasMatch(p)) {
                      return 'Include a lowercase letter';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(p)) {
                      return 'Include a number';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (isSignUp) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    textInputAction: TextInputAction.done,
                    obscureText: !_showPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Confirm your password';
                      if (v != _passwordCtrl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isBlocked) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Requests are temporarily limited. Try again in ${_remainingBlock}s.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (_loading || !configured || _isBlocked)
                      ? null
                      : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.black,
                          ),
                        )
                      : Text(isSignUp ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 10),
                const Divider(color: AppColors.outline),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: (_loading || !configured)
                      ? null
                      : () => _oauthSignIn(
                            () => ref.read(authControllerProvider).signInWithGoogle(),
                          ),
                  icon: const Icon(Icons.g_mobiledata_rounded),
                  label: const Text('Continue with Google'),
                ),
                if (canUseApple) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: (_loading || !configured)
                        ? null
                        : () => _oauthSignIn(
                              () =>
                                  ref.read(authControllerProvider).signInWithApple(),
                            ),
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: (_loading || !configured) ? null : _sendMagicLink,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Email me a magic link'),
                ),
                const SizedBox(height: 4),
                if (!isSignUp)
                  TextButton(
                    onPressed: (_loading || !configured) ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                const SizedBox(height: 14),
                const Text(
                  'By continuing you accept our POPIA notice and consent to share these details with the agents you enquire with.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(_Mode.signIn, 'Sign in')),
          Expanded(child: _segment(_Mode.signUp, 'Sign up')),
        ],
      ),
    );
  }

  Widget _segment(_Mode m, String label) {
    final selected = m == mode;
    return GestureDetector(
      onTap: () => onChanged(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifySignUpCodeScreen extends ConsumerStatefulWidget {
  const _VerifySignUpCodeScreen({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  ConsumerState<_VerifySignUpCodeScreen> createState() =>
      _VerifySignUpCodeScreenState();
}

class _VerifySignUpCodeScreenState
    extends ConsumerState<_VerifySignUpCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  DateTime? _resendBlockedUntil;
  Timer? _resendTicker;

  void _startResendTicker() {
    if (_resendTicker?.isActive == true) return;
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopResendTicker();
        return;
      }
      if (!_resendBlocked) {
        _stopResendTicker();
      }
      setState(() {});
    });
  }

  void _stopResendTicker() {
    _resendTicker?.cancel();
    _resendTicker = null;
  }

  void _setResendBlockedUntil(DateTime until) {
    if (_resendBlockedUntil == null || until.isAfter(_resendBlockedUntil!)) {
      _resendBlockedUntil = until;
      _startResendTicker();
    }
  }

  bool get _resendBlocked =>
      _resendBlockedUntil != null && DateTime.now().isBefore(_resendBlockedUntil!);

  int get _resendRemaining {
    if (_resendBlockedUntil == null) return 0;
    final seconds = _resendBlockedUntil!.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  @override
  void dispose() {
    _stopResendTicker();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    final token = _codeCtrl.text.trim();
    if (token.length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final controller = ref.read(authControllerProvider);
    try {
      await controller.verifySignUpCode(
        email: widget.email,
        token: token,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to verify code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_loading) return;
    if (_resendBlocked) {
      _startResendTicker();
      setState(
        () => _error = 'Please wait $_resendRemaining seconds before resending.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).resendSignUpCode(widget.email);
      _setResendBlockedUntil(DateTime.now().add(const Duration(seconds: 60)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A new code has been sent to ${widget.email}.'),
        ),
      );
    } on AuthException catch (e) {
      if (e.statusCode == '429') {
        _setResendBlockedUntil(DateTime.now().add(const Duration(seconds: 90)));
      }
      if (mounted) setState(() => _error = _friendlyAuthMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not resend code right now.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Enter confirmation code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a code to ${widget.email}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Confirmation code',
                  hintText: '123456',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
                onSubmitted: (_) => _verify(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Verify code'),
              ),
              TextButton(
                onPressed: (_loading || _resendBlocked) ? null : _resendCode,
                child: Text(
                  _resendBlocked
                      ? 'Resend code (${_resendRemaining}s)'
                      : 'Resend code',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
