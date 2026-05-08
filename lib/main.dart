import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/android_background_impact_service.dart';
import 'services/notification_service.dart';
import 'services/web_monitoring_service.dart';
import 'screens/dashboard_router.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    await WebMonitoringService.load();
  }

  runApp(const EVSmartPlus());
}

class EVSmartPlus extends StatefulWidget {
  const EVSmartPlus({super.key});

  @override
  State<EVSmartPlus> createState() => _EVSmartPlusState();
}

class _EVSmartPlusState extends State<EVSmartPlus> with WidgetsBindingObserver {
  bool _backgroundServiceActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_initializeNotificationServices());
    });
  }

  Future<void> _initializeNotificationServices() async {
    try {
      await NotificationService.initialize().timeout(
        const Duration(seconds: 10),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'EVSmart startup',
          context: ErrorDescription('while initializing notification services'),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AndroidBackgroundImpactService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (kIsWeb) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        if (_backgroundServiceActive) {
          _backgroundServiceActive = false;
          AndroidBackgroundImpactService.stop();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!_backgroundServiceActive) {
          _backgroundServiceActive = true;
          AndroidBackgroundImpactService.start();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EVSmart+',
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
      ),
      routes: {'/dashboard': (_) => const DashboardRouter()},
      home: const SplashScreen(),
    );
  }
}
