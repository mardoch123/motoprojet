import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// URL de base de l'API backend.
  /// Priorité : variable d'environnement API_BASE_URL > fallback production.
  /// En dev local, surcharger dans .env :
  ///   Android emulator : http://10.0.2.2:3000
  ///   iOS simulator    : http://localhost:3000
  ///   Production       : https://motoprojet.fly.dev
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://motoprojet.fly.dev';
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30000') ?? 30000;
  static String get appName => 'MotoProjet';
  static String get appVersion => '1.0.0';
}
