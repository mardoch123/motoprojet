import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fon.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fon'),
    Locale('fr'),
  ];

  /// Nom de l'application
  ///
  /// In fr, this message translates to:
  /// **'MotoProjet'**
  String get appTitle;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get commonSkip;

  /// No description provided for @commonFinish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get commonFinish;

  /// No description provided for @commonLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Succès'**
  String get commonSuccess;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @commonYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get commonNo;

  /// No description provided for @commonOK.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get commonOK;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @commonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get commonSearch;

  /// No description provided for @commonFilter.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer'**
  String get commonFilter;

  /// No description provided for @commonSort.
  ///
  /// In fr, this message translates to:
  /// **'Trier'**
  String get commonSort;

  /// No description provided for @commonRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get commonRefresh;

  /// No description provided for @commonSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get commonSettings;

  /// No description provided for @commonHelp.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get commonHelp;

  /// No description provided for @commonAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get commonAbout;

  /// No description provided for @commonLogout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get commonLogout;

  /// No description provided for @commonFCFA.
  ///
  /// In fr, this message translates to:
  /// **'FCFA'**
  String get commonFCFA;

  /// No description provided for @commonToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get commonYesterday;

  /// No description provided for @commonTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get commonTomorrow;

  /// Titre de l'écran de saisie de paiement
  ///
  /// In fr, this message translates to:
  /// **'Nouveau paiement'**
  String get paymentNew;

  /// No description provided for @paymentAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant (FCFA)'**
  String get paymentAmount;

  /// No description provided for @paymentAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get paymentAmountLabel;

  /// No description provided for @paymentMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get paymentMode;

  /// No description provided for @paymentModeCash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get paymentModeCash;

  /// No description provided for @paymentModeMobileMoney.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money'**
  String get paymentModeMobileMoney;

  /// No description provided for @paymentModeKKiaPay.
  ///
  /// In fr, this message translates to:
  /// **'KKiaPay'**
  String get paymentModeKKiaPay;

  /// No description provided for @paymentDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get paymentDate;

  /// No description provided for @paymentDriver.
  ///
  /// In fr, this message translates to:
  /// **'Chauffeur'**
  String get paymentDriver;

  /// No description provided for @paymentDriverSelect.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un chauffeur'**
  String get paymentDriverSelect;

  /// No description provided for @paymentVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule'**
  String get paymentVehicle;

  /// No description provided for @paymentVehicleSelect.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un véhicule'**
  String get paymentVehicleSelect;

  /// No description provided for @paymentRegisterCash.
  ///
  /// In fr, this message translates to:
  /// **'ENREGISTRER ESPÈCES'**
  String get paymentRegisterCash;

  /// No description provided for @paymentValidate.
  ///
  /// In fr, this message translates to:
  /// **'VALIDER'**
  String get paymentValidate;

  /// No description provided for @paymentSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Paiement enregistré !'**
  String get paymentSuccess;

  /// No description provided for @paymentOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne'**
  String get paymentOffline;

  /// No description provided for @paymentOfflineMessage.
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne — seul le paiement en espèces est disponible'**
  String get paymentOfflineMessage;

  /// No description provided for @paymentSyncPending.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation automatique dès retour réseau'**
  String get paymentSyncPending;

  /// No description provided for @paymentRemainingBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde restant'**
  String get paymentRemainingBalance;

  /// No description provided for @paymentReimbursedPercent.
  ///
  /// In fr, this message translates to:
  /// **'{percent}% remboursé'**
  String paymentReimbursedPercent(String percent);

  /// No description provided for @paymentNewPayment.
  ///
  /// In fr, this message translates to:
  /// **'NOUVEAU PAIEMENT'**
  String get paymentNewPayment;

  /// No description provided for @paymentQuickAmount.
  ///
  /// In fr, this message translates to:
  /// **'{amount} F'**
  String paymentQuickAmount(String amount);

  /// No description provided for @dashboardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboardTitle;

  /// No description provided for @dashboardBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get dashboardBalance;

  /// No description provided for @dashboardEndDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de fin'**
  String get dashboardEndDate;

  /// No description provided for @dashboardObjective.
  ///
  /// In fr, this message translates to:
  /// **'Objectif'**
  String get dashboardObjective;

  /// No description provided for @dashboardDailyObjective.
  ///
  /// In fr, this message translates to:
  /// **'Objectif journalier'**
  String get dashboardDailyObjective;

  /// No description provided for @dashboardDaysRemaining.
  ///
  /// In fr, this message translates to:
  /// **'{days} jours restants'**
  String dashboardDaysRemaining(int days);

  /// No description provided for @dashboardPaid.
  ///
  /// In fr, this message translates to:
  /// **'À jour'**
  String get dashboardPaid;

  /// No description provided for @dashboardLate.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get dashboardLate;

  /// No description provided for @dashboardDaysLate.
  ///
  /// In fr, this message translates to:
  /// **'{days} jours de retard'**
  String dashboardDaysLate(int days);

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settingsAppearance;

  /// No description provided for @settingsFontSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille de police'**
  String get settingsFontSize;

  /// No description provided for @settingsFontSizeSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petit'**
  String get settingsFontSizeSmall;

  /// No description provided for @settingsFontSizeNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get settingsFontSizeNormal;

  /// No description provided for @settingsFontSizeLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grand'**
  String get settingsFontSizeLarge;

  /// No description provided for @settingsFontSizeExtraLarge.
  ///
  /// In fr, this message translates to:
  /// **'Très grand'**
  String get settingsFontSizeExtraLarge;

  /// No description provided for @settingsHighContrast.
  ///
  /// In fr, this message translates to:
  /// **'Contraste renforcé'**
  String get settingsHighContrast;

  /// No description provided for @settingsHighContrastDescription.
  ///
  /// In fr, this message translates to:
  /// **'Améliore la lisibilité en plein soleil'**
  String get settingsHighContrastDescription;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get settingsLanguageFrench;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageFon.
  ///
  /// In fr, this message translates to:
  /// **'Fon'**
  String get settingsLanguageFon;

  /// No description provided for @settingsAccessibility.
  ///
  /// In fr, this message translates to:
  /// **'Accessibilité'**
  String get settingsAccessibility;

  /// No description provided for @settingsNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get settingsSecurity;

  /// No description provided for @settingsChangePin.
  ///
  /// In fr, this message translates to:
  /// **'Changer le code PIN'**
  String get settingsChangePin;

  /// No description provided for @settingsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos de MotoProjet'**
  String get settingsAbout;

  /// No description provided for @accessibilityPaymentButton.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un paiement'**
  String get accessibilityPaymentButton;

  /// No description provided for @accessibilityPaymentButtonHint.
  ///
  /// In fr, this message translates to:
  /// **'Saisir le montant et valider'**
  String get accessibilityPaymentButtonHint;

  /// No description provided for @accessibilityLateButton.
  ///
  /// In fr, this message translates to:
  /// **'Retard'**
  String get accessibilityLateButton;

  /// No description provided for @accessibilityLateButtonHint.
  ///
  /// In fr, this message translates to:
  /// **'Voir les retards en cours'**
  String get accessibilityLateButtonHint;

  /// No description provided for @accessibilityObjectiveButton.
  ///
  /// In fr, this message translates to:
  /// **'Objectif'**
  String get accessibilityObjectiveButton;

  /// No description provided for @accessibilityObjectiveButtonHint.
  ///
  /// In fr, this message translates to:
  /// **'Voir votre objectif journalier'**
  String get accessibilityObjectiveButtonHint;

  /// No description provided for @accessibilityAmountField.
  ///
  /// In fr, this message translates to:
  /// **'Montant en francs CFA'**
  String get accessibilityAmountField;

  /// No description provided for @accessibilityDatePicker.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner la date du paiement'**
  String get accessibilityDatePicker;

  /// No description provided for @accessibilityDriverDropdown.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un chauffeur'**
  String get accessibilityDriverDropdown;

  /// No description provided for @accessibilityVehicleDropdown.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un véhicule'**
  String get accessibilityVehicleDropdown;

  /// No description provided for @accessibilityPaymentMode.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le mode de paiement'**
  String get accessibilityPaymentMode;

  /// No description provided for @accessibilitySubmitPayment.
  ///
  /// In fr, this message translates to:
  /// **'Valider le paiement'**
  String get accessibilitySubmitPayment;

  /// No description provided for @accessibilitySyncIndicator.
  ///
  /// In fr, this message translates to:
  /// **'{count} paiements en attente de synchronisation'**
  String accessibilitySyncIndicator(int count);

  /// No description provided for @onboardingWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get onboardingWelcome;

  /// No description provided for @onboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get onboardingNext;

  /// No description provided for @onboardingFinish.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingFinish;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion. Vérifiez votre réseau.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get errorGeneric;

  /// No description provided for @errorRequired.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est requis'**
  String get errorRequired;

  /// No description provided for @errorInvalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide'**
  String get errorInvalidAmount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fon', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fon':
      return AppLocalizationsFon();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
