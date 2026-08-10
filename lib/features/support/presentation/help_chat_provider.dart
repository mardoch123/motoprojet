import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:motoprojet/features/auth/presentation/auth_provider.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class HelpMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String contenu;
  final DateTime date;
  final bool horsPerimetre;
  final List<String> suggestions;

  const HelpMessage({
    required this.id,
    required this.role,
    required this.contenu,
    required this.date,
    this.horsPerimetre = false,
    this.suggestions = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'role': role,
    'contenu': contenu,
    'date': date.toIso8601String(),
    'horsPerimetre': horsPerimetre,
    'suggestions': suggestions,
  };

  factory HelpMessage.fromMap(Map<String, dynamic> map) {
    return HelpMessage(
      id: map['id'] as String,
      role: map['role'] as String,
      contenu: map['contenu'] as String,
      date: DateTime.parse(map['date'] as String),
      horsPerimetre: map['horsPerimetre'] as bool? ?? false,
      suggestions: map['suggestions'] is List
          ? List<String>.from(map['suggestions'] as List)
          : [],
    );
  }
}

// ─── État ────────────────────────────────────────────────────────────────────

enum HelpChatStatus { idle, loading, error }

class HelpChatState {
  final List<HelpMessage> messages;
  final HelpChatStatus status;
  final String? errorMessage;

  const HelpChatState({
    this.messages = const [],
    this.status = HelpChatStatus.idle,
    this.errorMessage,
  });

  HelpChatState copyWith({
    List<HelpMessage>? messages,
    HelpChatStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HelpChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Service de stockage local ───────────────────────────────────────────────

class HelpChatStorage {
  static Box<Map>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(AppConstants.helpChatBox);
    AppLogger.i('HelpChatStorage initialisé — ${_box!.length} conversations');
  }

  static String _keyForUser(String userId) => 'chat_$userId';

  static List<HelpMessage> loadMessagesRaw(String userId) {
    if (_box == null) return [];
    final raw = _box!.get(_keyForUser(userId));
    if (raw == null) return [];
    try {
      final data = Map<String, dynamic>.from(raw);
      final list = data['messages'];
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((m) => HelpMessage.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      AppLogger.e('[HelpChat] Erreur lecture historique: $e');
      return [];
    }
  }

  static Future<void> saveMessages(String userId, List<HelpMessage> messages) async {
    if (_box == null) return;
    // Garder max 50 messages pour ne pas surcharger le stockage
    final toSave = messages.length > 50 ? messages.sublist(messages.length - 50) : messages;
    final data = {
      'messages': toSave.map((m) => m.toMap()).toList(),
      'lastUpdate': DateTime.now().toIso8601String(),
    };
    await _box!.put(_keyForUser(userId), data);
  }

  static Future<void> clearMessages(String userId) async {
    if (_box == null) return;
    await _box!.delete(_keyForUser(userId));
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class HelpChatNotifier extends StateNotifier<HelpChatState> {
  final Ref _ref;
  String? _currentUserId;

  HelpChatNotifier(this._ref) : super(const HelpChatState()) {
    _initUserId();
  }

  void _initUserId() {
    final authState = _ref.read(authProvider);
    _currentUserId = authState.userId;
    if (_currentUserId != null) {
      _loadLocalHistory();
    }
  }

  void _loadLocalHistory() {
    if (_currentUserId == null) return;
    final messages = HelpChatStorage.loadMessagesRaw(_currentUserId!);
    if (messages.isNotEmpty) {
      state = state.copyWith(messages: messages);
    }
  }

  Future<void> envoyerQuestion(String question) async {
    if (question.trim().isEmpty) return;

    // S'assurer qu'on a l'userId
    if (_currentUserId == null) {
      _initUserId();
      if (_currentUserId == null) return;
    }

    // Ajouter le message utilisateur
    final userMsg = HelpMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      contenu: question.trim(),
      date: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMsg];
    state = state.copyWith(messages: updatedMessages, status: HelpChatStatus.loading, clearError: true);

    // Construire l'historique pour l'API (max 10 derniers messages)
    final historique = updatedMessages
        .takeRight(10)
        .map((m) => {'role': m.role, 'contenu': m.contenu})
        .toList();

    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.post('/support/chat', data: {
        'question': question.trim(),
        'historique': historique,
      });

      final data = response.data as Map<String, dynamic>;
      final chatData = data['data'] as Map<String, dynamic>;

      final assistantMsg = HelpMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role: 'assistant',
        contenu: chatData['reponse'] as String? ?? 'Désolé, je ne peux pas répondre.',
        date: DateTime.now(),
        horsPerimetre: chatData['hors_perimetre'] as bool? ?? false,
        suggestions: chatData['suggestions'] is List
            ? List<String>.from(chatData['suggestions'] as List)
            : [],
      );

      final finalMessages = [...state.messages, assistantMsg];
      state = state.copyWith(messages: finalMessages, status: HelpChatStatus.idle);

      // Sauvegarder en local
      await HelpChatStorage.saveMessages(_currentUserId!, finalMessages);
    } catch (e) {
      AppLogger.e('[HelpChat] Erreur envoi: $e');
      state = state.copyWith(
        status: HelpChatStatus.error,
        errorMessage: 'Impossible de contacter le support pour le moment.',
      );
    }
  }

  void utiliserSuggestion(String suggestion) {
    envoyerQuestion(suggestion);
  }

  Future<void> effacerHistorique() async {
    state = state.copyWith(messages: []);
    if (_currentUserId != null) {
      await HelpChatStorage.clearMessages(_currentUserId!);
    }
  }

  List<HelpMessage> get suggestionsRapides => [
    HelpMessage(id: 's1', role: 'suggestion', contenu: 'Comment enregistrer un paiement ?', date: DateTime(2000)),
    HelpMessage(id: 's2', role: 'suggestion', contenu: 'Comment signaler une panne ?', date: DateTime(2000)),
    HelpMessage(id: 's3', role: 'suggestion', contenu: 'Comment fonctionne le hors-ligne ?', date: DateTime(2000)),
    HelpMessage(id: 's4', role: 'suggestion', contenu: 'Comment contacter l\'administrateur ?', date: DateTime(2000)),
  ];
}

// Extension utile
extension _ListExt<T> on List<T> {
  List<T> takeRight(int n) {
    if (n >= length) return this;
    return sublist(length - n);
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final helpChatProvider = StateNotifierProvider<HelpChatNotifier, HelpChatState>((ref) {
  return HelpChatNotifier(ref);
});

final helpChatNotifierProvider = Provider<HelpChatNotifier>((ref) {
  return ref.watch(helpChatProvider.notifier);
});
