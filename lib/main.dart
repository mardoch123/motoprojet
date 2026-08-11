import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/l10n/generated/app_localizations.dart';
import 'package:motoprojet/core/monitoring/sync_monitoring_service.dart';
import 'package:motoprojet/core/monitoring/usage_tracking_service.dart';
import 'package:motoprojet/core/network/offline_storage_service.dart';
import 'package:motoprojet/core/network/providers.dart' show OfflineStorageHolder;
import 'package:motoprojet/core/notifications/notification_service.dart';
import 'package:motoprojet/core/preferences/preferences_provider.dart';
import 'package:motoprojet/core/router/app_router.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:motoprojet/features/support/presentation/help_chat_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase (google-services.json est dans android/app/)
  try {
    await Firebase.initializeApp();
    AppLogger.i('[Firebase] Initialisé avec succès');
  } catch (e) {
    AppLogger.w('[Firebase] Non configuré: $e');
  }

  // Charger les variables d'environnement
  await dotenv.load(fileName: '.env');

  // Sentry : initialisation avant tout le reste
  final sentryEnabled = dotenv.env['SENTRY_ENABLED'] == 'true';
  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';

  if (sentryEnabled && sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = dotenv.env['API_BASE_URL']?.contains('dev') == true
            ? 'development'
            : 'production';
        options.tracesSampleRate = 0.2;
        options.release = 'motoprojet@1.0.0+1';

        // Filtrage et sanitisation avant envoi
        options.beforeSend = (event, hint) {
          // Supprimer les données utilisateur identifiables
          event.user?.data?.remove('telephone');

          // Ignorer les erreurs réseau bénignes
          final exc = event.exceptions?.isNotEmpty == true
              ? event.exceptions!.first
              : null;
          if (exc != null) {
            final msg = (exc.type ?? '') + (exc.value ?? '');
            if (msg.contains('ECONNRESET') ||
                msg.contains('NetworkError') ||
                msg.contains('EPIPE')) {
              return null;
            }
          }
          return event;
        };
      },
      appRunner: () => _startApp(),
    );
  } else {
    AppLogger.i('[Sentry] Désactivé (SENTRY_ENABLED=false ou DSN manquant)');
    _startApp();
  }
}

void _startApp() {
  runApp(
    const ProviderScope(
      child: MotoProjetApp(),
    ),
  );
}

class MotoProjetApp extends ConsumerStatefulWidget {
  const MotoProjetApp({super.key});

  @override
  ConsumerState<MotoProjetApp> createState() => _MotoProjetAppState();
}

class _MotoProjetAppState extends ConsumerState<MotoProjetApp> {
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _initMonitoringServices();
  }

  Future<void> _initMonitoringServices() async {
    try {
      // Initialiser le stockage hors-ligne (Hive)
      final offlineStorage = OfflineStorageService();
      await offlineStorage.init();

      // Stocker l'instance pour les providers
      OfflineStorageHolder.instance = offlineStorage;

      // Initialiser le stockage du chat d'aide
      await HelpChatStorage.init();

      // Initialiser les services de monitoring
      await UsageTrackingService.instance.init();
      await SyncMonitoringService.instance.init();

      // Initialiser les notifications push Firebase
      await NotificationService().init();

      // Nettoyer les anciennes entrées de sync
      await SyncMonitoringService.instance.cleanup();

      if (mounted) {
        setState(() => _servicesInitialized = true);
      }
    } catch (e) {
      AppLogger.e('Erreur init services: $e');
      if (mounted) {
        setState(() => _servicesInitialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final prefs = ref.watch(preferencesProvider);

    // Attendre que les préférences et services soient chargés
    if (prefs.isLoading || !_servicesInitialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Thème avec support contraste renforcé et font scale
    final lightTheme = prefs.highContrast
        ? AppTheme.highContrastLightTheme
        : AppTheme.lightTheme;
    final darkTheme = prefs.highContrast
        ? AppTheme.highContrastDarkTheme
        : AppTheme.darkTheme;

    return MaterialApp.router(
      title: 'MotoProjet',
      debugShowCheckedModeBanner: false,

      // ─── Internationalisation ────────────────────────────────────────────
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'), // Français — langue par défaut (Bénin)
        Locale('en'), // English
        Locale('fon'), // Fon — langue locale du Bénin
      ],
      locale: prefs.locale,

      // ─── Thème ─────────────────────────────────────────────────────────
      theme: lightTheme.copyWith(
        textTheme: lightTheme.textTheme.apply(
          fontSizeFactor: prefs.fontScale,
        ),
      ),
      darkTheme: darkTheme.copyWith(
        textTheme: darkTheme.textTheme.apply(
          fontSizeFactor: prefs.fontScale,
        ),
      ),
      themeMode: ThemeMode.light,

      // ─── Navigation ────────────────────────────────────────────────────
      routerConfig: router,

      // ─── Observateurs (tracking usage) ─────────────────────────────────
      // Le tracking des écrans est géré via le callback redirect du GoRouter
      // et manuellement dans les écrans clés (MaterialApp.router ne supporte
      // pas navigatorObservers car le Navigator est interne au RouterDelegate).

      // ─── Accessibilité ─────────────────────────────────────────────────
      // Le MediaQuery textScaleFactor est appliqué via le thème.
      // Les widgets Semantics sont ajoutés dans les écrans critiques.
    );
  }
}
