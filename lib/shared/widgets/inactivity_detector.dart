import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

/// Widget qui détecte l'inactivité de l'utilisateur et déconnecte automatiquement.
/// À placer en wrapper autour du contenu de l'AppShell.
///
/// Fonctionnement :
/// - Chaque interaction (tap, scroll, etc.) réinitialise le timer
/// - Si aucune interaction pendant [inactivityTimeoutMinutes], déconnexion
/// - Un heartbeat API est envoyé toutes les 5 minutes pour mettre à jour la dernière activité
class InactivityDetector extends ConsumerStatefulWidget {
  final Widget child;

  const InactivityDetector({super.key, required this.child});

  @override
  ConsumerState<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends ConsumerState<InactivityDetector> {
  Timer? _inactivityTimer;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    // Délayer après le build pour éviter "modify provider during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetInactivityTimer();
    });
    // Heartbeat toutes les 5 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.read(authProvider.notifier).recordActivity();
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      Duration(minutes: AppConstants.inactivityTimeoutMinutes),
      () {
        // Timeout atteint → déconnexion
        ref.read(authProvider.notifier).logout();
      },
    );
    // Enregistrer l'activité
    ref.read(authProvider.notifier).recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Capture tous les événements de pointeur (tap, drag, etc.)
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: widget.child,
    );
  }
}
