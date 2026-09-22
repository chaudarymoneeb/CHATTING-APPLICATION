// lib/main.dart

import 'package:chat_app/app_constant.dart';
import 'package:chat_app/firebase_options.dart';
import 'package:chat_app/screens/home_screen.dart';
import 'package:chat_app/screens/login_screen.dart';
import 'package:chat_app/screens/splash_screen.dart';
import 'package:chat_app/services/call_log_service.dart';
import 'package:chat_app/services/notification_service.dart'
    show NotificationService;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();

  await GoogleSignIn.instance.initialize();

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'We Chat',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF519306),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const ZegoServiceInitializer(child: SplashScreen()),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

class ZegoServiceInitializer extends StatefulWidget {
  final Widget child;
  const ZegoServiceInitializer({super.key, required this.child});

  @override
  State<ZegoServiceInitializer> createState() => _ZegoServiceInitializerState();
}

class _ZegoServiceInitializerState extends State<ZegoServiceInitializer> {
  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _initZego(user);
      } else {
        await _uninitZego();
      }
    });
  }

  Future<void> _initZego(User user) async {
    try {
      if (ZegoUIKitPrebuiltCallInvitationService().isInit) return;

      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: AppConstants.zegoAppId,
        appSign: AppConstants.zegoAppSign,
        userID: user.uid,
        userName: user.displayName ?? user.email ?? 'User',
        plugins: [ZegoUIKitSignalingPlugin()],
        invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
          onIncomingCallReceived: (_, caller, callType, _, _) {
            CallLogService.instance.onCallReceived(
              callerId: caller.id,
              callerName: caller.name,
              isVideo: callType == ZegoCallInvitationType.videoCall,
            );
          },
          onIncomingCallAcceptButtonPressed: () {
            CallLogService.instance.onCallAnswered();
          },
          onIncomingCallDeclineButtonPressed: () {
            CallLogService.instance.onCallEnded(endReason: 'decline');
          },
          onIncomingCallTimeout: (_, __) {
            CallLogService.instance.onCallEnded(endReason: 'timeout');
          },
          onIncomingCallCanceled: (_, __, ___) {
            CallLogService.instance.onCallEnded(endReason: 'cancel');
          },
          onOutgoingCallAccepted: (_, __) {
            CallLogService.instance.onCallAnswered();
          },
          onOutgoingCallDeclined: (_, __, ___) {
            CallLogService.instance.onCallEnded(endReason: 'decline');
          },
          onOutgoingCallRejectedCauseBusy: (_, __, ___) {
            CallLogService.instance.onCallEnded(endReason: 'decline');
          },
          onOutgoingCallCancelButtonPressed: () {
            CallLogService.instance.onCallEnded(endReason: 'cancel');
          },
          onOutgoingCallTimeout: (_, __, ___) {
            CallLogService.instance.onCallEnded(endReason: 'timeout');
          },
        ),
        events: ZegoUIKitPrebuiltCallEvents(
          onCallEnd: (_, defaultAction) {
            CallLogService.instance.onCallEnded();
            defaultAction();
          },
        ),
      );

      ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI([
        ZegoUIKitSignalingPlugin(),
      ]);

      debugPrint('✅ ZEGOCLOUD initialized for ${user.uid}');
    } catch (e, st) {
      debugPrint('❌ ZEGOCLOUD init error: $e\n$st');
    }
  }

  Future<void> _uninitZego() async {
    try {
      await ZegoUIKitPrebuiltCallInvitationService().uninit();
      debugPrint('✅ ZEGOCLOUD uninitialized');
    } catch (e) {
      debugPrint('❌ ZEGOCLOUD uninit error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
