// ignore_for_file: unused_import, use_build_context_synchronously, deprecated_member_use

import 'package:chat_app/app_constant.dart';
import 'package:chat_app/screens/home_screen.dart';
import 'package:chat_app/widgets/gradient_button.dart';
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
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e.code, e.message);
    } catch (e) {
      _handleAuthError('unknown', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<UserCredential> _signInWithGoogle() async {
    try {
      if (!_googleSignInInitialized) await _initGoogleSignIn();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Failed to get authentication token');
      }
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.softGradient),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.25),
                      blurRadius: 60,
                    ),
                  ],
                ),
                child: Container(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lightGreen.withValues(alpha: 0.2),
                      blurRadius: 60,
                    ),
                  ],
                ),
                child: Container(color: Colors.white.withValues(alpha: 0.88)),
              ),
            ),
            SingleChildScrollView(
              child: SizedBox(
                height: _screenSize.height,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              size: 72,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.primaryGradient.createShader(bounds),
                            child: Text(
                              'Connect & Chat',
                              style: AppTextStyles.heading1.copyWith(
                                color: Colors.white,
                                fontSize: 32,
                              ),
                            ),
                          ),
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
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: _screenSize.height * 0.08,
                        left: AppDimensions.paddingLarge,
                        right: AppDimensions.paddingLarge,
                      ),
                      child: Column(
                        children: [
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.errorColor.withValues(
                                    alpha: 0.3,
                                  ),
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
                          GradientButton(
                            label: _isLoading
                                ? 'Signing in...'
                                : 'Sign in with Google',
                            icon: Icons.g_mobiledata_rounded,
                            isLoading: _isLoading,
                            height: _screenSize.height * 0.065,
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                          ),
                          const SizedBox(height: 20),
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
      ),
    );
  }
}
