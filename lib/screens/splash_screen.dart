import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/impact_detection_service.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSplashFlow();
    });
  }

  Future<void> _startSplashFlow() async {
    if (_started || !mounted) {
      return;
    }
    _started = true;

    if (!kIsWeb) {
      await ImpactDetectionService.maybeRequestBackgroundPermission(context);
    }
    await Future<void>.delayed(Duration(seconds: kIsWeb ? 1 : 2));

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          "assets/images/one.png",
          width: screenWidth * 0.8, // responsive scaling
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
