// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MotoProjet';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonFinish => 'Finish';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonOK => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonSort => 'Sort';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonHelp => 'Help';

  @override
  String get commonAbout => 'About';

  @override
  String get commonLogout => 'Log out';

  @override
  String get commonFCFA => 'CFA';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get paymentNew => 'New payment';

  @override
  String get paymentAmount => 'Amount (CFA)';

  @override
  String get paymentAmountLabel => 'Amount';

  @override
  String get paymentMode => 'Payment method';

  @override
  String get paymentModeCash => 'Cash';

  @override
  String get paymentModeMobileMoney => 'Mobile Money';

  @override
  String get paymentModeKKiaPay => 'KKiaPay';

  @override
  String get paymentDate => 'Date';

  @override
  String get paymentDriver => 'Driver';

  @override
  String get paymentDriverSelect => 'Select a driver';

  @override
  String get paymentVehicle => 'Vehicle';

  @override
  String get paymentVehicleSelect => 'Select a vehicle';

  @override
  String get paymentRegisterCash => 'RECORD CASH';

  @override
  String get paymentValidate => 'SUBMIT';

  @override
  String get paymentSuccess => 'Payment recorded!';

  @override
  String get paymentOffline => 'Offline';

  @override
  String get paymentOfflineMessage =>
      'Offline — only cash payment is available';

  @override
  String get paymentSyncPending => 'Auto-sync when network returns';

  @override
  String get paymentRemainingBalance => 'Remaining balance';

  @override
  String paymentReimbursedPercent(String percent) {
    return '$percent% reimbursed';
  }

  @override
  String get paymentNewPayment => 'NEW PAYMENT';

  @override
  String paymentQuickAmount(String amount) {
    return '$amount F';
  }

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardBalance => 'Balance';

  @override
  String get dashboardEndDate => 'End date';

  @override
  String get dashboardObjective => 'Goal';

  @override
  String get dashboardDailyObjective => 'Daily goal';

  @override
  String dashboardDaysRemaining(int days) {
    return '$days days left';
  }

  @override
  String get dashboardPaid => 'Up to date';

  @override
  String get dashboardLate => 'Late';

  @override
  String dashboardDaysLate(int days) {
    return '$days days late';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsFontSizeSmall => 'Small';

  @override
  String get settingsFontSizeNormal => 'Normal';

  @override
  String get settingsFontSizeLarge => 'Large';

  @override
  String get settingsFontSizeExtraLarge => 'Extra large';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsHighContrastDescription =>
      'Improves readability in bright sunlight';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFon => 'Fon';

  @override
  String get settingsAccessibility => 'Accessibility';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsChangePin => 'Change PIN';

  @override
  String get settingsAbout => 'About MotoProjet';

  @override
  String get accessibilityPaymentButton => 'Record a payment';

  @override
  String get accessibilityPaymentButtonHint => 'Enter amount and submit';

  @override
  String get accessibilityLateButton => 'Late';

  @override
  String get accessibilityLateButtonHint => 'View current delays';

  @override
  String get accessibilityObjectiveButton => 'Goal';

  @override
  String get accessibilityObjectiveButtonHint => 'View your daily goal';

  @override
  String get accessibilityAmountField => 'Amount in CFA francs';

  @override
  String get accessibilityDatePicker => 'Select payment date';

  @override
  String get accessibilityDriverDropdown => 'Choose a driver';

  @override
  String get accessibilityVehicleDropdown => 'Choose a vehicle';

  @override
  String get accessibilityPaymentMode => 'Choose payment method';

  @override
  String get accessibilitySubmitPayment => 'Submit payment';

  @override
  String accessibilitySyncIndicator(int count) {
    return '$count payments pending sync';
  }

  @override
  String get onboardingWelcome => 'Welcome';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingFinish => 'Get started';

  @override
  String get errorNetwork => 'Connection error. Check your network.';

  @override
  String get errorGeneric => 'An error occurred. Please try again.';

  @override
  String get errorRequired => 'This field is required';

  @override
  String get errorInvalidAmount => 'Invalid amount';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authLoginSubtitle => 'Taxi financing in Benin';

  @override
  String get authPhone => 'Phone';

  @override
  String get authPhoneHint => '+229 XX XX XX XX';

  @override
  String get authPin => 'PIN code';

  @override
  String get authLogin => 'Sign in';

  @override
  String get authForgotPin => 'Forgot PIN?';

  @override
  String get authErrorInvalidCredentials => 'Invalid phone or PIN.';

  @override
  String get authErrorPhoneRequired => 'Please enter your phone number';

  @override
  String get authErrorPinRequired => 'Please enter your PIN';

  @override
  String get authErrorPinTooShort => 'PIN must be at least 4 digits';

  @override
  String get authPaymentFavorites => 'Favorites';

  @override
  String get authPaymentLastUsed => 'Last used';

  @override
  String get authPaymentQuickPay => 'QUICK PAY';

  @override
  String get authPaymentFavoriteSaved => 'Favorite saved';
}
