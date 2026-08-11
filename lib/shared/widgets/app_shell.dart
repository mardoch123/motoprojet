import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motoprojet/core/auth/permissions.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/core/theme/app_theme.dart';
import 'package:motoprojet/features/support/presentation/screens/help_chat_screen.dart';

/// ─── Définition de navigation par rôle ──────────────────────────────────────
/// Chaque entrée de navigation est associée à une capacité requise.
/// Si l'utilisateur n'a pas la capacité, l'onglet est masqué.
class _NavEntry {
  final IconData icon;
  final String label;
  final String route;
  final Capability requiredCapability;

  const _NavEntry({
    required this.icon,
    required this.label,
    required this.route,
    required this.requiredCapability,
  });
}

/// ─── Shell de navigation avec barre inférieure adaptée au rôle ──────────────
class AppShell extends ConsumerWidget {
  final String role;
  final Widget child;

  const AppShell({super.key, required this.role, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final items = _getNavItems().where((e) => perms.can(e.requiredCapability)).toList();

    return Scaffold(
      body: Stack(
        children: [
          child,
          // Bulle flottante d'aide (en bas à droite, au-dessus de la nav bar)
          Positioned(
            right: 16,
            bottom: items.length < 2 ? 24 : 72, // Au-dessus de la BottomNavigationBar
            child: _HelpFloatingBubble(),
          ),
        ],
      ),
      bottomNavigationBar: items.length < 2
          ? null
          : BottomNavigationBar(
              currentIndex: _getCurrentIndex(context, items),
              onTap: (index) => context.go(items[index].route),
              type: items.length > 4 ? BottomNavigationBarType.fixed : BottomNavigationBarType.fixed,
              items: items
                  .map((item) => BottomNavigationBarItem(
                        icon: Icon(item.icon),
                        label: item.label,
                      ))
                  .toList(),
            ),
    );
  }

  int _getCurrentIndex(BuildContext context, List<_NavEntry> items) {
    final location = GoRouterState.of(context).matchedLocation;
    
    // Chercher d'abord une correspondance exacte
    for (int i = 0; i < items.length; i++) {
      if (location == items[i].route) return i;
    }
    
    // Sinon chercher une correspondance par préfixe (du plus long au plus court)
    // pour éviter que /chauffeur matche avant /chauffeur/paiements
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route) && items[i].route != '/') {
        return i;
      }
    }
    
    return 0;
  }

  /// ─── Déclaration centralisée de la navigation ───────────────────────────
  /// Chaque onglet est associé à une Capability. Le filtrage se fait
  /// automatiquement : pas de if/else par rôle dans le code UI.
  List<_NavEntry> _getNavItems() {
    switch (role) {
      case AppConstants.roleSuperAdmin:
        return const [
          _NavEntry(icon: Icons.dashboard, label: 'Dashboard', route: '/admin', requiredCapability: Capability.viewDashboardAdmin),
          _NavEntry(icon: Icons.people, label: 'Chauffeurs', route: '/admin/chauffeurs', requiredCapability: Capability.viewChauffeurs),
          _NavEntry(icon: Icons.directions_car, label: 'Véhicules', route: '/admin/vehicules', requiredCapability: Capability.viewVehicles),
          _NavEntry(icon: Icons.payments, label: 'Paiements', route: '/admin/paiements', requiredCapability: Capability.viewPayments),
          _NavEntry(icon: Icons.lock_reset, label: 'Reset PIN', route: '/admin/reset-pin', requiredCapability: Capability.managePinReset),
          _NavEntry(icon: Icons.auto_awesome, label: 'IA', route: '/admin/ia', requiredCapability: Capability.viewIA),
        ];
      case AppConstants.roleGestionnaire:
        return const [
          _NavEntry(icon: Icons.dashboard, label: 'Opérations', route: '/gestionnaire', requiredCapability: Capability.viewDashboardOperations),
          _NavEntry(icon: Icons.people, label: 'Chauffeurs', route: '/gestionnaire/chauffeurs', requiredCapability: Capability.viewChauffeurs),
          _NavEntry(icon: Icons.directions_car, label: 'Véhicules', route: '/gestionnaire/vehicules', requiredCapability: Capability.viewVehicles),
          _NavEntry(icon: Icons.payments, label: 'Paiements', route: '/gestionnaire/paiements', requiredCapability: Capability.viewPayments),
          _NavEntry(icon: Icons.report_problem, label: 'Incidents', route: '/gestionnaire/incidents', requiredCapability: Capability.createIncidents),
        ];
      case AppConstants.roleChauffeur:
        return const [
          _NavEntry(icon: Icons.home, label: 'Accueil', route: '/chauffeur', requiredCapability: Capability.viewPayments),
          _NavEntry(icon: Icons.payments, label: 'Paiements', route: '/chauffeur/paiements', requiredCapability: Capability.viewPayments),
          _NavEntry(icon: Icons.report_problem, label: 'Incidents', route: '/chauffeur/incidents', requiredCapability: Capability.viewIncidents),
        ];
      default:
        return [];
    }
  }
}

/// ─── Bulle flottante d'aide ─────────────────────────────────────────────────
/// Visible sur tous les écrans, ouvre le chatbot d'aide.
class _HelpFloatingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const HelpChatScreen(),
          ),
        );
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.help_outline,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
