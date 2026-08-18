import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Size mq;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to We Chat'),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade100, Colors.green.shade50, Colors.white],
          ),
        ),

        child: Stack(
          children: [
            // App Logo
            Positioned(
              top: mq.height * 0.15,
              left: mq.width * 0.25,
              width: mq.width * 0.5,

              child: Column(
                children: [
                  Image.asset('images/chat.png', height: mq.height * 0.25),

                  SizedBox(height: mq.height * 0.02),

                  Text(
                    'We Chat',
                    style: TextStyle(
                      fontSize: mq.width * 0.08,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),

                  Text(
                    'Connect with friends',
                    style: TextStyle(
                      fontSize: mq.width * 0.04,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Loading Indicator
            Positioned(
              bottom: mq.height * 0.35,
              left: mq.width * 0.35,
              width: mq.width * 0.3,

              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.green,
                  strokeWidth: 2,
                ),
              ),
            ),

            // Bottom Text
            Positioned(
              bottom: mq.height * 0.03,
              left: 0,
              right: 0,

              child: Center(
                child: Text(
                  'Make your life better',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
