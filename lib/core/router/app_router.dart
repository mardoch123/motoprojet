import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';
import 'package:motoprojet/features/auth/presentation/screens/login_screen.dart';
import 'package:motoprojet/features/auth/presentation/screens/splash_screen.dart';
import 'package:motoprojet/features/auth/presentation/screens/change_pin_screen.dart';
import 'package:motoprojet/features/auth/presentation/screens/forgot_pin_screen.dart';
import 'package:motoprojet/features/auth/presentation/screens/reset_pin_screen.dart';
import 'package:motoprojet/features/onboarding/presentation/screens/onboarding_super_admin_screen.dart';
import 'package:motoprojet/features/onboarding/presentation/screens/onboarding_gestionnaire_screen.dart';
import 'package:motoprojet/features/onboarding/presentation/screens/onboarding_chauffeur_screen.dart';
import 'package:motoprojet/features/chauffeurs/presentation/screens/chauffeurs_screen.dart';
import 'package:motoprojet/features/chauffeurs/presentation/screens/chauffeur_detail_screen.dart';
import 'package:motoprojet/features/chauffeurs/presentation/screens/chauffeur_form_screen.dart';
import 'package:motoprojet/features/vehicules/presentation/screens/vehicules_screen.dart';
import 'package:motoprojet/features/paiements/presentation/screens/paiements_screen.dart';
import 'package:motoprojet/features/paiements/presentation/screens/saisie_rapide_screen.dart';
import 'package:motoprojet/features/paiements/presentation/screens/historique_paiements_screen.dart';
import 'package:motoprojet/features/paiements/presentation/screens/pending_sync_screen.dart';
import 'package:motoprojet/features/dashboard/presentation/screens/super_admin_dashboard.dart';
import 'package:motoprojet/features/dashboard/presentation/screens/gestionnaire_dashboard.dart';
import 'package:motoprojet/features/incidents/presentation/screens/incident_form_screen.dart';
import 'package:motoprojet/features/incidents/presentation/screens/incident_history_screen.dart';
import 'package:motoprojet/features/vehicules/presentation/screens/vehicule_detail_screen.dart';
import 'package:motoprojet/features/rappels/presentation/screens/rappels_screen.dart';
import 'package:motoprojet/features/ia/presentation/screens/ia_screen.dart';
import 'package:motoprojet/features/simulation/presentation/screens/simulation_screen.dart';
import 'package:motoprojet/features/salaires/presentation/screens/salaires_screen.dart';
import 'package:motoprojet/features/finances/presentation/screens/export_comptable_screen.dart';
import 'package:motoprojet/features/finances/presentation/screens/apports_config_screen.dart';
import 'package:motoprojet/features/penalites/presentation/screens/penalites_config_screen.dart';
import 'package:motoprojet/features/fleet/presentation/screens/fleet_tracking_screen.dart';
import 'package:motoprojet/features/contrats/presentation/screens/contrats_screen.dart';
import 'package:motoprojet/features/settings/presentation/screens/settings_screen.dart';
import 'package:motoprojet/features/monitoring/presentation/screens/monitoring_dashboard_screen.dart';
import 'package:motoprojet/shared/widgets/app_shell.dart';
import 'package:motoprojet/core/monitoring/usage_tracking_service.dart';
import 'package:motoprojet/shared/widgets/inactivity_detector.dart';

/// Configuration du routeur avec redirection selon le rôle
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isSplash = state.matchedLocation == '/';
      final currentPath = state.matchedLocation;

      // Routes publiques (toujours accessibles)
      const publicRoutes = ['/login', '/forgot-pin'];
      if (publicRoutes.contains(currentPath)) return null;

      // Routes onboarding (accessibles si connecté mais onboarding non fait)
      const onboardingRoutes = ['/onboarding/super-admin', '/onboarding/gestionnaire', '/onboarding/chauffeur'];
      if (onboardingRoutes.contains(currentPath)) {
        if (!isLoggedIn) return '/login';
        // Si l'onboarding est déjà fait, rediriger vers le dashboard
        if (authState.onboardingCompleted) return _dashboardRoute(authState.role);
        return null;
      }

      // Route change-pin : accessible seulement si connecté ET mustChangePin
      if (currentPath == '/change-pin') {
        if (!isLoggedIn) return '/login';
        if (!authState.mustChangePin) {
          // PIN déjà changé → rediriger vers le dashboard
          return _dashboardRoute(authState.role);
        }
        return null;
      }

      // Sur la page splash → vérifier l'auth
      if (isSplash) {
        if (!isLoggedIn) return '/login';
        // Si doit changer son PIN → forcer le changement
        if (authState.mustChangePin) return '/change-pin';
        // Si onboarding non fait → rediriger vers l'onboarding du rôle
        if (!authState.onboardingCompleted) return _onboardingRoute(authState.role);
        return _dashboardRoute(authState.role);
      }

      // Si pas connecté → rediriger vers login
      if (!isLoggedIn) return '/login';

      // Si doit changer son PIN → bloquer l'accès au reste
      if (authState.mustChangePin) return '/change-pin';

      // Si onboarding non fait → rediriger vers l'onboarding
      if (!authState.onboardingCompleted) return _onboardingRoute(authState.role);

      // Si connecté et route finale → tracker la navigation
      if (isLoggedIn) {
        UsageTrackingService.instance.trackScreen(currentPath);
      }

      return null;
    },
    routes: [
      // ─── Splash ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // ─── Login ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ─── PIN oublié ─────────────────────────────────────────────────────
      GoRoute(
        path: '/forgot-pin',
        builder: (context, state) => const ForgotPinScreen(),
      ),

      // ─── Changement PIN obligatoire ─────────────────────────────────────
      GoRoute(
        path: '/change-pin',
        builder: (context, state) => const ChangePinScreen(),
      ),

      // ─── Onboarding (hors ShellRoute — pas d'AppShell) ────────────────────
      GoRoute(
        path: '/onboarding/super-admin',
        builder: (context, state) => const OnboardingSuperAdminScreen(),
      ),
      GoRoute(
        path: '/onboarding/gestionnaire',
        builder: (context, state) => const OnboardingGestionnaireScreen(),
      ),
      GoRoute(
        path: '/onboarding/chauffeur',
        builder: (context, state) => const OnboardingChauffeurScreen(),
      ),

      // ─── Super Admin ────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => InactivityDetector(
          child: AppShell(
            role: AppConstants.roleSuperAdmin,
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const SuperAdminDashboard(),
          ),
          GoRoute(
            path: '/admin/chauffeurs',
            builder: (context, state) => const ChauffeursScreen(),
          ),
          GoRoute(
            path: '/admin/vehicules',
            builder: (context, state) => const VehiculesScreen(),
          ),
          GoRoute(
            path: '/admin/paiements',
            builder: (context, state) => const PaiementsScreen(),
          ),
          GoRoute(
            path: '/paiements/saisie',
            builder: (context, state) => const SaisieRapideScreen(),
          ),
          GoRoute(
            path: '/paiements/historique',
            builder: (context, state) => const HistoriquePaiementsScreen(),
          ),
          GoRoute(
            path: '/paiements/sync',
            builder: (context, state) => const PendingSyncScreen(),
          ),
          GoRoute(
            path: '/admin/rappels',
            builder: (context, state) => const RappelsScreen(),
          ),
          GoRoute(
            path: '/admin/ia',
            builder: (context, state) => const IaScreen(),
          ),
          GoRoute(
            path: '/admin/simulation',
            builder: (context, state) => const SimulationScreen(),
          ),
          GoRoute(
            path: '/admin/salaires',
            builder: (context, state) => const SalairesScreen(),
          ),
          GoRoute(
            path: '/admin/finances',
            builder: (context, state) => const ExportComptableScreen(),
          ),
          GoRoute(
            path: '/admin/apports',
            builder: (context, state) => const ApportsConfigScreen(),
          ),
          GoRoute(
            path: '/admin/penalites',
            builder: (context, state) => const PenalitesConfigScreen(),
          ),
          GoRoute(
            path: '/admin/fleet',
            builder: (context, state) => const FleetTrackingScreen(),
          ),
          GoRoute(
            path: '/admin/contrats',
            builder: (context, state) => const ContratsScreen(),
          ),
          GoRoute(
            path: '/admin/reset-pin',
            builder: (context, state) => const ResetPinScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/admin/monitoring',
            builder: (context, state) => const MonitoringDashboardScreen(),
          ),
          GoRoute(
            path: '/chauffeurs/create',
            builder: (context, state) => const ChauffeurFormScreen(),
          ),
          GoRoute(
            path: '/chauffeurs/:id',
            builder: (context, state) => ChauffeurDetailScreen(
              chauffeurId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/chauffeurs/:id/edit',
            builder: (context, state) => ChauffeurFormScreen(
              chauffeurId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/vehicules/:id',
            builder: (context, state) => VehiculeDetailScreen(
              vehiculeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/vehicules/:id/incidents',
            builder: (context, state) => IncidentHistoryScreen(
              vehiculeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/incidents/new',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return IncidentFormScreen(
                preselectedVehiculeId: extra?['vehiculeId'] as String?,
              );
            },
          ),
        ],
      ),

      // ─── Gestionnaire ───────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => InactivityDetector(
          child: AppShell(
            role: AppConstants.roleGestionnaire,
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/gestionnaire',
            builder: (context, state) => const GestionnaireDashboard(),
          ),
          GoRoute(
            path: '/gestionnaire/chauffeurs',
            builder: (context, state) => const ChauffeursScreen(),
          ),
          GoRoute(
            path: '/gestionnaire/vehicules',
            builder: (context, state) => const VehiculesScreen(),
          ),
          GoRoute(
            path: '/gestionnaire/paiements',
            builder: (context, state) => const PaiementsScreen(),
          ),
          GoRoute(
            path: '/gestionnaire/rappels',
            builder: (context, state) => const RappelsScreen(),
          ),
          GoRoute(
            path: '/gestionnaire/incidents',
            builder: (context, state) => const IncidentFormScreen(),
          ),
          GoRoute(
            path: '/chauffeurs/create',
            builder: (context, state) => const ChauffeurFormScreen(),
          ),
          GoRoute(
            path: '/chauffeurs/:id',
            builder: (context, state) => ChauffeurDetailScreen(
              chauffeurId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/chauffeurs/:id/edit',
            builder: (context, state) => ChauffeurFormScreen(
              chauffeurId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/vehicules/:id',
            builder: (context, state) => VehiculeDetailScreen(
              vehiculeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/vehicules/:id/incidents',
            builder: (context, state) => IncidentHistoryScreen(
              vehiculeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/incidents/new',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return IncidentFormScreen(
                preselectedVehiculeId: extra?['vehiculeId'] as String?,
              );
            },
          ),
        ],
      ),

      // ─── Chauffeur ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => InactivityDetector(
          child: AppShell(
            role: AppConstants.roleChauffeur,
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/chauffeur',
            builder: (context, state) => const ChauffeurDashboard(),
          ),
          GoRoute(
            path: '/chauffeur/paiements',
            builder: (context, state) => const PaiementsScreen(),
          ),
          GoRoute(
            path: '/chauffeur/rappels',
            builder: (context, state) => const RappelsScreen(),
          ),
          GoRoute(
            path: '/chauffeur/incidents',
            builder: (context, state) => const IncidentFormScreen(),
          ),
          GoRoute(
            path: '/chauffeur/contrats',
            builder: (context, state) => const ContratsScreen(),
          ),
          GoRoute(
            path: '/vehicules/:id',
            builder: (context, state) => VehiculeDetailScreen(
              vehiculeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/vehicules/:id/incidents',
            builder: (context, state) => IncidentHistoryScreen(
              vehiculeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/incidents/new',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return IncidentFormScreen(
                preselectedVehiculeId: extra?['vehiculeId'] as String?,
              );
            },
          ),
        ],
      ),
    ],
  );
});

/// Retourne la route du dashboard selon le rôle
String _dashboardRoute(String? role) {
  switch (role) {
    case AppConstants.roleSuperAdmin:
      return '/admin';
    case AppConstants.roleGestionnaire:
      return '/gestionnaire';
    case AppConstants.roleChauffeur:
      return '/chauffeur';
    default:
      return '/login';
  }
}

/// Retourne la route d'onboarding selon le rôle
String _onboardingRoute(String? role) {
  switch (role) {
    case AppConstants.roleSuperAdmin:
      return '/onboarding/super-admin';
    case AppConstants.roleGestionnaire:
      return '/onboarding/gestionnaire';
    case AppConstants.roleChauffeur:
      return '/onboarding/chauffeur';
    default:
      return '/login';
  }
}

/// Dashboard simplifié pour le chauffeur
class ChauffeurDashboard extends StatelessWidget {
  const ChauffeurDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon espace')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text('Bienvenue chauffeur', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Consultez vos paiements et rappels'),
          ],
        ),
      ),
    );
  }
}
