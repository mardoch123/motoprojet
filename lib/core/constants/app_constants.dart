class AppConstants {
  // Rôles utilisateur
  static const String roleSuperAdmin = 'super_admin';
  static const String roleGestionnaire = 'gestionnaire';
  static const String roleChauffeur = 'chauffeur';

  // Types de véhicule
  static const String typeMoto = 'moto';
  static const String typeVoiture = 'voiture';

  // Statuts de paiement
  static const String paymentPending = 'pending';
  static const String paymentCompleted = 'completed';
  static const String paymentFailed = 'failed';
  static const String paymentSynced = 'synced';

  // Statuts de financement
  static const String financingActive = 'active';
  static const String financingCompleted = 'completed';
  static const String financingDefaulted = 'defaulted';

  // Hive box names
  static const String offlinePaymentsBox = 'offline_payments';
  static const String syncQueueBox = 'sync_queue';
  static const String userCacheBox = 'user_cache';
  static const String helpChatBox = 'help_chat';

  // Secure storage keys
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String mustChangePinKey = 'must_change_pin';
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String lastActivityKey = 'last_activity';

  // Inactivité (déconnexion automatique)
  static const int inactivityTimeoutMinutes = 30;
}
