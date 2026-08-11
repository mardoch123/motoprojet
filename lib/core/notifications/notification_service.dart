import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:motoprojet/core/notifications/firebase_messaging_handler.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Service de gestion des notifications push Firebase
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _messageSubscription;
  String? _fcmToken;

  /// Initialise les notifications push Firebase
  /// Firebase doit déjà être initialisé dans main() via Firebase.initializeApp()
  Future<void> init() async {
    try {
      // Configurer les notifications locales
      await _initLocalNotifications();

      // Demander la permission (iOS)
      if (Platform.isIOS) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }

      // Configurer le handler pour les messages en foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Configurer le handler pour les messages en arrière-plan (app fermée)
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Récupérer le token FCM
      await _getFCMToken();

      // Écouter les changements de token
      _messaging.onTokenRefresh.listen((token) {
        AppLogger.i('[NotificationService] Token FCM rafraîchi: $token');
        _fcmToken = token;
        // TODO: Envoyer le nouveau token au backend
      });

      AppLogger.i('[NotificationService] Initialisé avec succès');
    } catch (e) {
      AppLogger.e('[NotificationService] Erreur initialisation: $e');
    }
  }

  /// Initialise les notifications locales Android
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Récupère le token FCM
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      AppLogger.i('[NotificationService] Token FCM: $_fcmToken');
      
      // TODO: Envoyer ce token au backend pour l'associer à l'utilisateur
      // await backendService.updateFCMToken(_fcmToken);
    } catch (e) {
      AppLogger.e('[NotificationService] Erreur récupération token: $e');
    }
  }

  /// Gère les messages reçus en foreground (app ouverte)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.i('[NotificationService] Message foreground: ${message.notification?.title}');

    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'motoprojet_channel',
      'Notifications MotoProjet',
      channelDescription: 'Notifications pour les rappels de paiement et alertes',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Callback quand l'utilisateur tape sur une notification
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.i('[NotificationService] Notification tapée: ${response.payload}');
    // TODO: Naviguer vers l'écran correspondant selon le payload
  }

  /// Getter pour le token FCM
  String? get fcmToken => _fcmToken;

  /// S'abonner à un topic (pour les notifications groupées)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    AppLogger.i('[NotificationService] Abonné au topic: $topic');
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    AppLogger.i('[NotificationService] Désabonné du topic: $topic');
  }

  /// Nettoyer les ressources
  void dispose() {
    _messageSubscription?.cancel();
  }
}
