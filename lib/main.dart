import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 1. Enable Edge-to-Edge mode first
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 2. Set the style, explicitly disabling contrast enforcement
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      // This is the key line to remove the translucent bar/scrim
      systemNavigationBarContrastEnforced: false, 
    ),
  );

  runApp(const FoundItApp());
}

class FoundItApp extends StatelessWidget {
  const FoundItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoundIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
