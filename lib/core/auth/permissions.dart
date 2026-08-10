import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

/// ─── Capabilities déclaratives ─────────────────────────────────────────────
/// Chaque capacité représente une action ou un accès autorisé.
/// Les rôles disposent d'un ensemble de capacités — pas de if/else dispersé.
enum Capability {
  // Dashboard
  viewDashboardAdmin,        // Dashboard complet (cash, prix, exports)
  viewDashboardOperations,   // Dashboard opérationnel (retards, recouvrement)

  // Paiements
  viewPayments,
  createPayments,
  viewPaymentAmounts,        // Voir les montants détaillés

  // Chauffeurs
  viewChauffeurs,
  createChauffeurs,
  editChauffeurs,
  viewChauffeurFinancials,   // Salaires, pourcentages, versements

  // Véhicules
  viewVehicles,
  createVehicles,
  editVehicles,
  viewVehiclePrices,         // Prix d'achat, paramètres financiers

  // Incidents
  viewIncidents,
  createIncidents,

  // Administration
  viewExports,               // Exports comptables globaux
  viewAuditLog,              // Journal d'audit
  manageUsers,               // Gestion des droits utilisateurs
  managePinReset,            // Reset PIN
  viewIA,                    // Recommandations IA
  viewNextPurchase,          // Compteurs prochain achat
  viewSalaries,              // Salaires et versements
}

/// ─── Matrice des permissions par rôle ───────────────────────────────────────
class RolePermissions {
  static const Map<String, Set<Capability>> _roleCapabilities = {
    AppConstants.roleSuperAdmin: {
      // Tout accès
      Capability.viewDashboardAdmin,
      Capability.viewPayments,
      Capability.createPayments,
      Capability.viewPaymentAmounts,
      Capability.viewChauffeurs,
      Capability.createChauffeurs,
      Capability.editChauffeurs,
      Capability.viewChauffeurFinancials,
      Capability.viewVehicles,
      Capability.createVehicles,
      Capability.editVehicles,
      Capability.viewVehiclePrices,
      Capability.viewIncidents,
      Capability.createIncidents,
      Capability.viewExports,
      Capability.viewAuditLog,
      Capability.manageUsers,
      Capability.managePinReset,
      Capability.viewIA,
      Capability.viewNextPurchase,
      Capability.viewSalaries,
      Capability.viewDashboardOperations,
    },
    AppConstants.roleGestionnaire: {
      // Accès opérationnel uniquement
      Capability.viewDashboardOperations,
      Capability.viewPayments,
      Capability.createPayments,
      Capability.viewPaymentAmounts,
      Capability.viewChauffeurs,
      Capability.viewVehicles,
      Capability.viewIncidents,
      Capability.createIncidents,
    },
    AppConstants.roleChauffeur: {
      // Accès minimal
      Capability.viewPayments,
      Capability.viewIncidents,
    },
  };

  /// Vérifie si un rôle possède une capacité donnée
  static bool hasCapability(String role, Capability cap) {
    final caps = _roleCapabilities[role] ?? {};
    return caps.contains(cap);
  }

  /// Retourne l'ensemble des capacités d'un rôle
  static Set<Capability> capabilitiesFor(String role) {
    return _roleCapabilities[role] ?? {};
  }
}

/// ─── Widget conditionnel basé sur les permissions ───────────────────────────
/// Affiche son enfant uniquement si l'utilisateur a la capacité requise.
class PermissionGate extends ConsumerWidget {
  final Capability capability;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.capability,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final hasAccess = authState.role != null &&
        RolePermissions.hasCapability(authState.role!, capability);
    return hasAccess ? child : (fallback ?? const SizedBox.shrink());
  }
}

/// ─── Provider de permissions ────────────────────────────────────────────────
final permissionsProvider = Provider<PermissionsService>((ref) {
  final authState = ref.watch(authProvider);
  return PermissionsService(authState.role);
});

class PermissionsService {
  final String? role;

  PermissionsService(this.role);

  bool can(Capability cap) {
    if (role == null) return false;
    return RolePermissions.hasCapability(role!, cap);
  }

  bool get isAdmin => role == AppConstants.roleSuperAdmin;
  bool get isGestionnaire => role == AppConstants.roleGestionnaire;
  bool get isChauffeur => role == AppConstants.roleChauffeur;
}
