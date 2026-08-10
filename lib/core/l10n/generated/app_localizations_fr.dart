// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'MotoProjet';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonSkip => 'Passer';

  @override
  String get commonFinish => 'Terminer';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonSuccess => 'Succès';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonOK => 'OK';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonFilter => 'Filtrer';

  @override
  String get commonSort => 'Trier';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonSettings => 'Paramètres';

  @override
  String get commonHelp => 'Aide';

  @override
  String get commonAbout => 'À propos';

  @override
  String get commonLogout => 'Déconnexion';

  @override
  String get commonFCFA => 'FCFA';

  @override
  String get commonToday => 'Aujourd\'hui';

  @override
  String get commonYesterday => 'Hier';

  @override
  String get commonTomorrow => 'Demain';

  @override
  String get paymentNew => 'Nouveau paiement';

  @override
  String get paymentAmount => 'Montant (FCFA)';

  @override
  String get paymentAmountLabel => 'Montant';

  @override
  String get paymentMode => 'Mode de paiement';

  @override
  String get paymentModeCash => 'Espèces';

  @override
  String get paymentModeMobileMoney => 'Mobile Money';

  @override
  String get paymentModeKKiaPay => 'KKiaPay';

  @override
  String get paymentDate => 'Date';

  @override
  String get paymentDriver => 'Chauffeur';

  @override
  String get paymentDriverSelect => 'Sélectionner un chauffeur';

  @override
  String get paymentVehicle => 'Véhicule';

  @override
  String get paymentVehicleSelect => 'Sélectionner un véhicule';

  @override
  String get paymentRegisterCash => 'ENREGISTRER ESPÈCES';

  @override
  String get paymentValidate => 'VALIDER';

  @override
  String get paymentSuccess => 'Paiement enregistré !';

  @override
  String get paymentOffline => 'Hors-ligne';

  @override
  String get paymentOfflineMessage =>
      'Hors-ligne — seul le paiement en espèces est disponible';

  @override
  String get paymentSyncPending =>
      'Synchronisation automatique dès retour réseau';

  @override
  String get paymentRemainingBalance => 'Solde restant';

  @override
  String paymentReimbursedPercent(String percent) {
    return '$percent% remboursé';
  }

  @override
  String get paymentNewPayment => 'NOUVEAU PAIEMENT';

  @override
  String paymentQuickAmount(String amount) {
    return '$amount F';
  }

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String get dashboardBalance => 'Solde';

  @override
  String get dashboardEndDate => 'Date de fin';

  @override
  String get dashboardObjective => 'Objectif';

  @override
  String get dashboardDailyObjective => 'Objectif journalier';

  @override
  String dashboardDaysRemaining(int days) {
    return '$days jours restants';
  }

  @override
  String get dashboardPaid => 'À jour';

  @override
  String get dashboardLate => 'En retard';

  @override
  String dashboardDaysLate(int days) {
    return '$days jours de retard';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsFontSize => 'Taille de police';

  @override
  String get settingsFontSizeSmall => 'Petit';

  @override
  String get settingsFontSizeNormal => 'Normal';

  @override
  String get settingsFontSizeLarge => 'Grand';

  @override
  String get settingsFontSizeExtraLarge => 'Très grand';

  @override
  String get settingsHighContrast => 'Contraste renforcé';

  @override
  String get settingsHighContrastDescription =>
      'Améliore la lisibilité en plein soleil';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFon => 'Fon';

  @override
  String get settingsAccessibility => 'Accessibilité';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsSecurity => 'Sécurité';

  @override
  String get settingsChangePin => 'Changer le code PIN';

  @override
  String get settingsAbout => 'À propos de MotoProjet';

  @override
  String get accessibilityPaymentButton => 'Enregistrer un paiement';

  @override
  String get accessibilityPaymentButtonHint => 'Saisir le montant et valider';

  @override
  String get accessibilityLateButton => 'Retard';

  @override
  String get accessibilityLateButtonHint => 'Voir les retards en cours';

  @override
  String get accessibilityObjectiveButton => 'Objectif';

  @override
  String get accessibilityObjectiveButtonHint =>
      'Voir votre objectif journalier';

  @override
  String get accessibilityAmountField => 'Montant en francs CFA';

  @override
  String get accessibilityDatePicker => 'Sélectionner la date du paiement';

  @override
  String get accessibilityDriverDropdown => 'Choisir un chauffeur';

  @override
  String get accessibilityVehicleDropdown => 'Choisir un véhicule';

  @override
  String get accessibilityPaymentMode => 'Choisir le mode de paiement';

  @override
  String get accessibilitySubmitPayment => 'Valider le paiement';

  @override
  String accessibilitySyncIndicator(int count) {
    return '$count paiements en attente de synchronisation';
  }

  @override
  String get onboardingWelcome => 'Bienvenue';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingFinish => 'Commencer';

  @override
  String get errorNetwork => 'Erreur de connexion. Vérifiez votre réseau.';

  @override
  String get errorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get errorRequired => 'Ce champ est requis';

  @override
  String get errorInvalidAmount => 'Montant invalide';
}
