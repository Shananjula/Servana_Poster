// lib/screens/login_screen.dart
//
// Phone-only Login (Sri Lanka default)
// • Step 1: enter phone → Send code (Firebase verifyPhoneNumber)
// • Step 2: enter 6-digit code → Verify & sign in
// • Resend timer + error messages
// • Auto handle instant verification / auto-retrieval when the device supports it
//
// Flows after success:
// • We do NOT manually navigate here; AuthWrapper (in main.dart) listens to auth changes
//   and routes appropriately. That keeps navigation centralized and reliable.
//
// Safe fallbacks:
// • If auto-verification triggers (Android), we immediately sign in.
// • If SMS arrives and Google Play Services auto-retrieves the code, we autofill.
// • If verification fails, a friendly message appears.
// • Country code defaults to +94 (changeable by the user).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- Step state ---
  final _phoneCtrl = TextEditingController(text: '+94');
  final _codeCtrl = TextEditingController();
  final _formPhone = GlobalKey<FormState>();
  final _formCode = GlobalKey<FormState>();

  String? _verificationId;
  int? _resendToken;

  bool _sending = false;
  bool _verifying = false;

  int _resendSeconds = 0;
  Timer? _resendTimer;

  String? _error; // surface friendly errors

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // --- UI helpers ---

  bool get _hasVerification => _verificationId != null && _verificationId!.isNotEmpty;

  void _startResendCountdown([int seconds = 30]) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _setError(Object e) {
    final msg = e.toString();
    String friendly = 'Something went wrong. Please try again.';
    if (msg.contains('invalid-phone-number')) {
      friendly = 'That phone number looks invalid.';
    } else if (msg.contains('too-many-requests')) {
      friendly = 'Too many attempts. Please try again later.';
    } else if (msg.contains('session-expired')) {
      friendly = 'Code expired. Please resend a new code.';
    } else if (msg.contains('invalid-verification-code')) {
      friendly = 'That code is not correct.';
    }
    setState(() => _error = friendly);
  }

  // --- Actions ---

  Future<void> _sendCode({bool resend = false}) async {
    if (!(_formPhone.currentState?.validate() ?? false)) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    final phone = _phoneCtrl.text.trim();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android: instant verification or auto-retrieval
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Signed in automatically.')),
            );
          } catch (e) {
            _setError(e);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _setError(e);
        },
        codeSent: (String verificationId, int? forceResendingToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = forceResendingToken;
            _error = null;
          });
          _startResendCountdown(30);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code sent. Check your SMS.')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Still can use this verificationId with the code
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      _setError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!(_formCode.currentState?.validate() ?? false)) return;
    if (_verificationId == null || _verificationId!.isEmpty) {
      setState(() => _error = 'Please request a code first.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeCtrl.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      // AuthWrapper (main.dart) will pick this up and route. We just show a toast.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in. Welcome!')),
      );
    } on FirebaseAuthException catch (e) {
      _setError(e);
    } catch (e) {
      _setError(e);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // --- Validators ---

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your phone number';
    // Very loose check: starts with + and > 8 digits total
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (!s.startsWith('+') || digits.length < 9) {
      return 'Enter a valid phone number with country code';
    }
    return null;
  }

  String? _validateCode(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 6) return 'Enter the 6-digit code';
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Digits only';
    return null;
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          // Header
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primary.withOpacity(0.12),
                foregroundColor: cs.primary,
                child: const Icon(Icons.phone_iphone),
              ),
              title: const Text('Sign in with your phone'),
              subtitle: const Text('We’ll send a verification code via SMS.'),
            ),
          ),
          const SizedBox(height: 16),

          // Step 1: Phone
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Form(
                key: _formPhone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone number', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                      decoration: const InputDecoration(
                        hintText: '+94 7X XXX XXXX',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _sending ? null : () => _sendCode(resend: false),
                            icon: _sending
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.sms_outlined),
                            label: const Text('Send code'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: (_resendSeconds == 0 && !_sending && _hasVerification)
                              ? () => _sendCode(resend: true)
                              : null,
                          child: Text(_resendSeconds == 0 ? 'Resend' : 'Resend (${_resendSeconds}s)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Step 2: Code
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Form(
                key: _formCode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verification code', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      validator: _validateCode,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        hintText: '6-digit code',
                        counterText: '',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _verifying ? null : _verifyCode,
                      icon: _verifying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.verified_user_outlined),
                      label: const Text('Verify & sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Card(
              color: cs.errorContainer,
              child: ListTile(
                leading: Icon(Icons.error_outline, color: cs.onErrorContainer),
                title: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Footer
          Center(
            child: Text(
              'By continuing you agree to our Terms & Privacy.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
