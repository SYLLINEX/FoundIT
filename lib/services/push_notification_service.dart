import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'found_it_alerts',
    'FoundIT Alerts',
    description: 'Important alerts and report updates',
    importance: Importance.max,
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _previousUserId;

  Future<void> init() async {
    if (_initialized) return;

    await _requestPermission();
    await _setupLocalNotifications();
    await _setupForegroundPresentation();
    await _syncTokenForCurrentUser();
    _listenTokenRefresh();
    _listenAuthChanges();
    _listenForegroundMessages();

    _initialized = true;
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background push message: ${message.messageId}');
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Request iOS permission through flutter_local_notifications as well.
    // This is separate from firebase_messaging's requestPermission and is needed
    // so that local notifications (shown in the foreground handler) are allowed.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Explicitly request iOS local notification permission via the plugin.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> _setupForegroundPresentation() {
    return _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _syncTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _saveToken(user.uid, token);
    _previousUserId = user.uid;
  }

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _saveToken(user.uid, token);
    });
  }

  void _listenAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      final currentToken = await _messaging.getToken();

      // We no longer attempt to _removeToken here when `user` becomes null
      // because Firestore will reject unauthenticated writes.
      // Instead, we handle token removal directly in `AuthService.signOut()`.

      if (user != null && currentToken != null) {
        await _saveToken(user.uid, currentToken);
      }

      _previousUserId = user?.uid;
    });
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;

      await _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'FoundIT',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcm_tokens': FieldValue.arrayUnion([token]),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  Future<void> _removeToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcm_tokens': FieldValue.arrayRemove([token]),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error removing token: $e');
    }
  }
}
