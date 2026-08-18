import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late Size mq;

  bool _isLoading = false;

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();

    _initializeGoogleSignIn();
  }

  // Initialize Google Sign-In
  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
    } catch (e) {
      debugPrint('Google Sign-In initialization error: $e');
    }
  }

  // Google Sign-In button
  Future<void> _handleGoogleBtnClick() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential? userCredential = await _signInWithGoogle();

      // User cancelled login
      if (userCredential == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      if (!mounted) return;

      // Login successful
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Google Sign-In + Firebase Authentication
  Future<UserCredential?> _signInWithGoogle() async {
    try {
      // Make sure Google Sign-In is initialized
      await _googleSignIn.initialize();

      // Start authentication
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Get Google authentication information
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Get ID token
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In did not return an ID token.');
      }

      // Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      return userCredential;
    } on GoogleSignInException catch (e) {
      debugPrint('Google Sign-In Exception: ${e.code} - ${e.description}');

      // User cancelled Google Sign-In
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }

      rethrow;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to We Chat'),
        centerTitle: true,
      ),

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade100, Colors.white],
          ),
        ),

        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Chat Logo
                Image.asset(
                  'assets/images/chat.png',
                  height: mq.height * 0.20,

                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.chat,
                      size: mq.height * 0.20,
                      color: Colors.green,
                    );
                  },
                ),

                SizedBox(height: mq.height * 0.05),

                // Welcome Text
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: mq.width * 0.08,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),

                SizedBox(height: mq.height * 0.02),

                // Subtitle
                Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: mq.width * 0.04,
                    color: Colors.grey.shade600,
                  ),
                ),

                SizedBox(height: mq.height * 0.08),

                // Google Sign-In Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: mq.width * 0.05),

                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                      elevation: 3,

                      minimumSize: Size(mq.width * 0.9, mq.height * 0.07),

                      side: BorderSide(color: Colors.grey.shade300),
                    ),

                    onPressed: _isLoading ? null : _handleGoogleBtnClick,

                    // Button Icon
                    icon: _isLoading
                        ? SizedBox(
                            height: mq.height * 0.03,
                            width: mq.height * 0.03,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Image.asset(
                            'assets/images/google.png',
                            height: mq.height * 0.04,

                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.login,
                                size: mq.height * 0.04,
                                color: Colors.red,
                              );
                            },
                          ),

                    // Button Text
                    label: _isLoading
                        ? const Text(
                            'Signing in...',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          )
                        : RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: mq.width * 0.045,
                              ),

                              children: [
                                const TextSpan(
                                  text: 'Sign in with ',
                                  style: TextStyle(fontWeight: FontWeight.w300),
                                ),

                                TextSpan(
                                  text: 'Google',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                SizedBox(height: mq.height * 0.03),

                // Firebase Text
                Text(
                  'Your account is secured with Firebase',
                  style: TextStyle(
                    fontSize: mq.width * 0.03,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
