import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// It's good practice to import your theme if you need to access specific colors directly,
// though most styling will come from Theme.of(context).
// import '../theme/theme.dart'; // Assuming your theme file is in lib/theme/theme.dart

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  String? _verificationId;
  bool _isLoading = false;
  bool _isOtpSent = false;

  @override
  void initState() {
    super.initState();
    // Request focus on the phone field initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isOtpSent && mounted) {
        FocusScope.of(context).requestFocus(_phoneFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating, // More modern look
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary, // Or your success color
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter your phone number.");
      return;
    }
    // Basic validation for SL phone number length (without +94)
    if (_phoneController.text.trim().length < 9 || _phoneController.text.trim().length > 10) {
      _showErrorSnackBar("Please enter a valid 9 or 10 digit phone number.");
      return;
    }

    String phoneNumber = "+94${_phoneController.text.trim()}";

    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // This callback will be triggered if auto-retrieval is successful
        await _auth.signInWithCredential(credential);
        if (mounted) {
          _showSuccessSnackBar("Signed in automatically!");
          setState(() => _isLoading = false);
        }
        // Navigation will be handled by the StreamBuilder in main.dart
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          _showErrorSnackBar("Verification Failed: ${e.code}"); // Using e.code is often cleaner
          setState(() => _isLoading = false);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          _showSuccessSnackBar("OTP sent to $phoneNumber!");
          setState(() {
            _verificationId = verificationId;
            _isOtpSent = true;
            _isLoading = false;
            // Request focus on the OTP field after OTP is sent
            FocusScope.of(context).requestFocus(_otpFocusNode);
          });
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // You might want to update _verificationId here as well
        // if (_verificationId == null && mounted) { // Or if it matches the current one
        //   setState(() {
        //     _verificationId = verificationId;
        //   });
        // }
        print("codeAutoRetrievalTimeout: $verificationId");
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length != 6 || _verificationId == null) {
      _showErrorSnackBar("Please enter the 6-digit code.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      if(mounted) _showSuccessSnackBar("Successfully signed in!");
      // Navigation handled by StreamBuilder in main.dart
    } on FirebaseAuthException catch (e) {
      if (mounted) _showErrorSnackBar("Invalid OTP or error: ${e.code}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access theme data
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final primaryAction = _isOtpSent ? _verifyOtp : _sendOtp;
    final buttonText = _isOtpSent ? 'Verify & Sign In' : 'Send OTP';

    return Scaffold(
      // backgroundColor will be picked from AppTheme.lightTheme.scaffoldBackgroundColor
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0), // Adjusted padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Image.asset(
                  'assets/logo.png', // Ensure this asset exists
                  height: 80,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.task_alt_rounded, // Using a rounded version
                    size: 80,
                    color: colorScheme.primary, // Use themed color
                  ),
                ),
                const SizedBox(height: 24), // Increased spacing

                // Title Text
                Text(
                  _isOtpSent ? 'Enter Verification Code' : 'Welcome to Helpify!', // Slightly friendlier title
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary, // Using primary color for title
                  ),
                ),
                const SizedBox(height: 12), // Increased spacing

                // Subtitle Text
                Text(
                  _isOtpSent
                      ? 'A 6-digit code was sent to your phone.'
                      : 'Sign in or create an account with your phone number.', // Clearer subtitle
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: textTheme.bodySmall?.color, // Use themed secondary text color
                  ),
                ),
                const SizedBox(height: 48), // Increased spacing before inputs

                // AnimatedSwitcher for Phone/OTP inputs
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition( // Added slide transition for better effect
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _isOtpSent
                      ? _buildOtpInputUI(theme, textTheme)
                      : _buildPhoneInputUI(theme, textTheme),
                ),
                const SizedBox(height: 24), // Increased spacing

                // Action Button or Loading Indicator
                _isLoading
                    ? Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                )
                    : ElevatedButton(
                  // The style will be picked from AppTheme.elevatedButtonTheme
                  onPressed: primaryAction,
                  child: Text(buttonText),
                ),
                const SizedBox(height: 16),

                // "Different Number" TextButton
                if (_isOtpSent && !_isLoading)
                  TextButton(
                    // Style will be picked from AppTheme.textButtonTheme
                    onPressed: () {
                      setState(() {
                        _isOtpSent = false;
                        _otpController.clear();
                        _phoneController.clear(); // Optionally clear phone too
                        // Request focus on the phone field when going back
                        FocusScope.of(context).requestFocus(_phoneFocusNode);
                      });
                    },
                    child: const Text('Use a different number?'),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Phone Input UI ---
  Widget _buildPhoneInputUI(ThemeData theme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('phone-input'), // Key for AnimatedSwitcher
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField( // Using TextFormField for potential future validation
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          keyboardType: TextInputType.phone,
          // The decoration will largely be picked from AppTheme.inputDecorationTheme
          decoration: const InputDecoration(
            hintText: '77 123 4567',
            labelText: 'Phone Number', // Added label for better UX
            prefixIcon: Icon(Icons.phone_android_rounded), // Slightly different icon
            prefixText: '+94 ',
            // border property is handled by inputDecorationTheme in AppTheme
          ),
          style: textTheme.bodyLarge,
          validator: (value) { // Example validator (can be expanded)
            if (value == null || value.trim().isEmpty) {
              return 'Phone number cannot be empty.';
            }
            if (value.trim().length < 9 || value.trim().length > 10) {
              return 'Enter a valid 9 or 10 digit number.';
            }
            return null;
          },
          autovalidateMode: AutovalidateMode.onUserInteraction, // Validate as user types
        ),
      ],
    );
  }

  // --- OTP Input UI ---
  Widget _buildOtpInputUI(ThemeData theme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('otp-input'), // Key for AnimatedSwitcher
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          // Style for OTP input - large and spaced out
          style: textTheme.headlineMedium?.copyWith(letterSpacing: 10, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: '● ● ● ● ● ●', // Using dots for hint
            hintStyle: TextStyle(letterSpacing: 10, fontWeight: FontWeight.bold), // Match hint style
            counterText: "", // Hides the maxLength counter
            labelText: 'OTP Code', // Added label
            // border property is handled by inputDecorationTheme in AppTheme
          ),
          validator: (value) {
            if (value == null || value.trim().length != 6) {
              return 'Enter the 6-digit code.';
            }
            return null;
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ],
    );
  }
}