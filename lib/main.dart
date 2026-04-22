import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'services/push_notification_service.dart';

// Global theme notifier — light mode by default; user can enable dark mode in Profile > Settings
final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(ThemeMode.light);

void _applyEdgeToEdgeSystemUi() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env variables
  await dotenv.load(fileName: ".env");

  // Load saved theme
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  appThemeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Fire and forget to prevent hanging on iOS without APNs entitlements during sideloading.
  PushNotificationService.instance.init();

  _applyEdgeToEdgeSystemUi();
  
  runApp(const FoundItApp());
}

class FoundItApp extends StatefulWidget {
  const FoundItApp({super.key});

  @override
  State<FoundItApp> createState() => _FoundItAppState();
}

class _FoundItAppState extends State<FoundItApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen for theme changes and save to shared preferences
    appThemeNotifier.addListener(_saveTheme);
  }

  void _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', appThemeNotifier.value == ThemeMode.dark);
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_saveTheme);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyEdgeToEdgeSystemUi();
    }
  }

  @override
  void didChangeMetrics() {
    _applyEdgeToEdgeSystemUi();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'FoundIT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            
            // Find the current system scale factor and reduce it by 15% globally
            final systemScale = mediaQueryData.textScaler.scale(1.0);
            final reducedScale = systemScale * 0.85;

            // Clamp the final scaled result to prevent extreme layout breakage
            final finalScaler = TextScaler.linear(reducedScale).clamp(
              minScaleFactor: 0.7,
              maxScaleFactor: 1.1,
            );

            return MediaQuery(
              data: mediaQueryData.copyWith(textScaler: finalScaler),
              child: ColoredBox(
                color: themeMode == ThemeMode.dark ? AppColors.darkBg : AppColors.mist,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const SplashScreen(),
        );
      }
    );
  }
}
