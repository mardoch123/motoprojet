import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Handler pour les messages Firebase reçus en arrière-plan (app fermée).
/// DOIT être une fonction top-level (pas une méthode de classe).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.i('[Firebase BG] Message reçu: ${message.messageId}');
}
