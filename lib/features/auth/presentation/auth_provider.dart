import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:motoprojet/core/constants/app_constants.dart';

/// État de l'authentification
enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? role;
  final String? token;
  final String? statut;
  final bool mustChangePin;
  final bool onboardingCompleted;
  final DateTime? lastActivity;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.role,
    this.token,
    this.statut,
    this.mustChangePin = false,
    this.onboardingCompleted = false,
    this.lastActivity,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? role,
    String? token,
    String? statut,
    bool? mustChangePin,
    bool? onboardingCompleted,
    DateTime? lastActivity,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      token: token ?? this.token,
      statut: statut ?? this.statut,
      mustChangePin: mustChangePin ?? this.mustChangePin,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isSuperAdmin => role == AppConstants.roleSuperAdmin;
  bool get isGestionnaire => role == AppConstants.roleGestionnaire;
  bool get isChauffeur => role == AppConstants.roleChauffeur;

  /// Vérifie si la session a expiré par inactivité
  bool get isInactive {
    if (lastActivity == null) return false;
    final diff = DateTime.now().difference(lastActivity!);
    return diff.inMinutes >= AppConstants.inactivityTimeoutMinutes;
  }
}

/// Notifier pour l'état d'authentification Riverpod
class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _secureStorage;

  AuthNotifier(this._secureStorage) : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    final role = await _secureStorage.read(key: AppConstants.userRoleKey);
    final userId = await _secureStorage.read(key: AppConstants.userIdKey);
    final mustChangePin = await _secureStorage.read(key: AppConstants.mustChangePinKey);
    final onboardingCompleted = await _secureStorage.read(key: AppConstants.onboardingCompletedKey);

    if (token != null && role != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: userId,
        role: role,
        token: token,
        mustChangePin: mustChangePin == 'true',
        onboardingCompleted: onboardingCompleted == 'true',
        lastActivity: DateTime.now(),
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String token,
    required String userId,
    required String role,
    String? statut,
    bool mustChangePin = false,
    bool onboardingCompleted = false,
  }) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    await _secureStorage.write(key: AppConstants.userIdKey, value: userId);
    await _secureStorage.write(key: AppConstants.userRoleKey, value: role);
    await _secureStorage.write(
      key: AppConstants.mustChangePinKey,
      value: mustChangePin.toString(),
    );
    await _secureStorage.write(
      key: AppConstants.onboardingCompletedKey,
      value: onboardingCompleted.toString(),
    );

    state = AuthState(
      status: AuthStatus.authenticated,
      userId: userId,
      role: role,
      token: token,
      statut: statut,
      mustChangePin: mustChangePin,
      onboardingCompleted: onboardingCompleted,
      lastActivity: DateTime.now(),
    );
  }

  /// Appelé après un changement de PIN réussi
  Future<void> pinChanged() async {
    await _secureStorage.write(key: AppConstants.mustChangePinKey, value: 'false');
    state = state.copyWith(mustChangePin: false);
  }

  /// Stocke le refresh token séparément (utilisé par l'AuthInterceptor pour le auto-refresh)
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  /// Récupère le refresh token stocké
  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  /// Marque l'onboarding comme terminé
  Future<void> completeOnboarding() async {
    await _secureStorage.write(key: AppConstants.onboardingCompletedKey, value: 'true');
    state = state.copyWith(onboardingCompleted: true);
  }

  /// Met à jour le timestamp d'activité (heartbeat)
  void recordActivity() {
    state = state.copyWith(lastActivity: DateTime.now());
  }

  /// Déconnexion automatique par inactivité
  Future<void> logoutIfInactive() async {
    if (state.isInactive) {
      await logout();
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.userIdKey);
    await _secureStorage.delete(key: AppConstants.userRoleKey);
    await _secureStorage.delete(key: AppConstants.mustChangePinKey);
    await _secureStorage.delete(key: AppConstants.onboardingCompletedKey);

    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Provider global de l'état d'authentification
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(const FlutterSecureStorage());
});
