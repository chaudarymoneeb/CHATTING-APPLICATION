// ignore_for_file: unused_import, use_build_context_synchronously, deprecated_member_use

import 'package:chat_app/app_constant.dart';
import 'package:chat_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late Size _screenSize;
  bool _isLoading = false;
  String? _errorMessage;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
    _checkIfAlreadyLoggedIn();
  }

  Future<void> _initGoogleSignIn() async {
    if (_googleSignInInitialized) return;
    try {
      await _googleSignIn.initialize(
        // Required so Firebase can validate the returned ID token.
        // This is your Firebase project's WEB client ID, found in:
        // Firebase Console -> Project Settings -> General -> your app,
        // or Google Cloud Console -> APIs & Services -> Credentials.
        serverClientId:
            '613314793444-4qsful3qa1cni0rb61ir1hl39if0lahs.apps.googleusercontent.com',
      );
      _googleSignInInitialized = true;
    } catch (e) {
      debugPrint('GoogleSignIn initialize error: $e');
    }
  }

  Future<void> _checkIfAlreadyLoggedIn() async {
    if (_firebaseAuth.currentUser != null) {
      if (mounted) {
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed('/home');
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userCredential = await _signInWithGoogle();

      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e.code, e.message);
    } catch (e) {
      _handleAuthError('unknown', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleAuthError(String code, String? message) {
    String displayMessage = 'Sign in failed. Please try again.';

    switch (code) {
      case 'sign_in_aborted':
        displayMessage = 'Sign in was cancelled.';
        break;
      case 'network_error':
        displayMessage = 'Network error. Please check your connection.';
        break;
      case 'sign_in_failed':
        displayMessage = 'Google sign in failed. Please try again.';
        break;
      default:
        displayMessage = message ?? 'An error occurred during sign in.';
    }

    if (mounted) {
      setState(() => _errorMessage = displayMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Future<UserCredential> _signInWithGoogle() async {
    try {
      if (!_googleSignInInitialized) {
        await _initGoogleSignIn();
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // `authentication` is now a synchronous getter, not a Future.
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get authentication token');
      }

      // `accessToken` no longer lives on GoogleSignInAuthentication.
      // Firebase sign-in only needs the idToken.
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('sign_in_aborted');
      }
      throw Exception('Google Sign-in failed: ${e.description}');
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Google Sign-in failed: $e');
    }
  }

  Future<void> _createOrUpdateUser(User firebaseUser) async {
    try {
      final userDoc = _firestore.collection('users').doc(firebaseUser.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'id': firebaseUser.uid,
          'name': firebaseUser.displayName ?? 'User',
          'email': firebaseUser.email ?? '',
          'image': firebaseUser.photoURL ?? '',
          'about': 'Hey! I\'m using We Chat',
          'created_at': FieldValue.serverTimestamp(),
          'is_online': true,
          'push_token': '',
          'last_active': FieldValue.serverTimestamp(),
        });
      } else {
        await userDoc.update({
          'is_online': true,
          'last_active': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error creating/updating user: $e');
      throw Exception('Failed to save user data');
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Welcome to We Chat', style: AppTextStyles.heading2),
      ),
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.lightGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main content
          SingleChildScrollView(
            child: SizedBox(
              height: _screenSize.height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo and description
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Connect & Chat', style: AppTextStyles.heading1),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Fast, secure, and simple messaging. Start connecting with friends now!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sign-in section
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: _screenSize.height * 0.08,
                      left: AppDimensions.paddingLarge,
                      right: AppDimensions.paddingLarge,
                    ),
                    child: Column(
                      children: [
                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadius,
                              ),
                              border: Border.all(
                                color: AppColors.errorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.errorColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.errorColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Google Sign-in button
                        Material(
                          child: InkWell(
                            onTap: _isLoading ? null : _handleGoogleSignIn,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadius,
                            ),
                            child: Container(
                              height: _screenSize.height * 0.065,
                              decoration: BoxDecoration(
                                color: _isLoading
                                    ? AppColors.primaryGreen.withOpacity(0.6)
                                    : AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.borderRadius,
                                ),
                                boxShadow: [
                                  if (!_isLoading)
                                    BoxShadow(
                                      color: AppColors.primaryGreen.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoading)
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  else
                                    Image.asset(
                                      'assets/images/google.png',
                                      height: _screenSize.height * 0.04,
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isLoading
                                        ? 'Signing in...'
                                        : 'Sign in with Google',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Terms and conditions
                        Text(
                          'By signing in, you agree to our Terms & Conditions',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
