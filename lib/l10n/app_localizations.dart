import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('am'),
    Locale('en'),
    Locale('om'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Brade and Cake House'**
  String get appTitle;

  /// No description provided for @production.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get production;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales & POS'**
  String get sales;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @cashManagement.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cashManagement;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People & HR'**
  String get people;

  /// No description provided for @rentals.
  ///
  /// In en, this message translates to:
  /// **'Rentals'**
  String get rentals;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @configurationRequired.
  ///
  /// In en, this message translates to:
  /// **'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY) to connect this app to Supabase.'**
  String get configurationRequired;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @membershipRequired.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready, but no active branch membership is assigned. Contact your administrator.'**
  String get membershipRequired;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Your role does not grant access to this module.'**
  String get accessDenied;

  /// No description provided for @accessLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account access.'**
  String get accessLoadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get newSale;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @productionModule.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get productionModule;

  /// No description provided for @salesModule.
  ///
  /// In en, this message translates to:
  /// **'Sales & POS'**
  String get salesModule;

  /// No description provided for @inventoryModule.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryModule;

  /// No description provided for @cashModule.
  ///
  /// In en, this message translates to:
  /// **'Cash & expenses'**
  String get cashModule;

  /// No description provided for @peopleModule.
  ///
  /// In en, this message translates to:
  /// **'People & HR'**
  String get peopleModule;

  /// No description provided for @payrollModule.
  ///
  /// In en, this message translates to:
  /// **'Payroll'**
  String get payrollModule;

  /// No description provided for @rentalsModule.
  ///
  /// In en, this message translates to:
  /// **'Rentals'**
  String get rentalsModule;

  /// No description provided for @payablesModule.
  ///
  /// In en, this message translates to:
  /// **'Payables'**
  String get payablesModule;

  /// No description provided for @reportsModule.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsModule;

  /// No description provided for @settingsModule.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsModule;

  /// No description provided for @notificationsModule.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsModule;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @workspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All operational areas available to your role.'**
  String get workspaceSubtitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @adminPortal.
  ///
  /// In en, this message translates to:
  /// **'Admin portal'**
  String get adminPortal;

  /// No description provided for @managerPortal.
  ///
  /// In en, this message translates to:
  /// **'Manager portal'**
  String get managerPortal;

  /// No description provided for @teamPortal.
  ///
  /// In en, this message translates to:
  /// **'Team portal'**
  String get teamPortal;

  /// No description provided for @roleNoReports.
  ///
  /// In en, this message translates to:
  /// **'Your role does not include dashboard reporting. Use the module shortcuts below.'**
  String get roleNoReports;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales'**
  String get todaySales;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @cashBalance.
  ///
  /// In en, this message translates to:
  /// **'Cash balance'**
  String get cashBalance;

  /// No description provided for @receivables.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get receivables;

  /// No description provided for @payables.
  ///
  /// In en, this message translates to:
  /// **'Payables'**
  String get payables;

  /// No description provided for @rentOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Rent outstanding'**
  String get rentOutstanding;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStock;

  /// No description provided for @pendingExpenses.
  ///
  /// In en, this message translates to:
  /// **'Pending expenses'**
  String get pendingExpenses;

  /// No description provided for @pendingLeave.
  ///
  /// In en, this message translates to:
  /// **'Pending leave'**
  String get pendingLeave;

  /// No description provided for @batchesToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s batches'**
  String get batchesToday;

  /// No description provided for @activeEmployees.
  ///
  /// In en, this message translates to:
  /// **'Active employees'**
  String get activeEmployees;

  /// No description provided for @revenueThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Revenue this month'**
  String get revenueThisMonth;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage sales, stock, cash, people and property.'**
  String get signInSubtitle;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @claimOwner.
  ///
  /// In en, this message translates to:
  /// **'Claim owner account'**
  String get claimOwner;

  /// No description provided for @claiming.
  ///
  /// In en, this message translates to:
  /// **'Claiming…'**
  String get claiming;

  /// No description provided for @claimOwnerHelp.
  ///
  /// In en, this message translates to:
  /// **'If this is the first account for the business, claim ownership to create the organization and its first branch.'**
  String get claimOwnerHelp;

  /// No description provided for @backToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get backToDashboard;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System theme'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get darkTheme;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get myAccount;

  /// No description provided for @accountPreferences.
  ///
  /// In en, this message translates to:
  /// **'Account and preferences'**
  String get accountPreferences;

  /// No description provided for @editDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Edit display name'**
  String get editDisplayName;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @noBranchSelected.
  ///
  /// In en, this message translates to:
  /// **'No branch selected'**
  String get noBranchSelected;
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
      <String>['am', 'en', 'om'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
    case 'om':
      return AppLocalizationsOm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
