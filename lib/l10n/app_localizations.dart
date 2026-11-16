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

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @branchSetup.
  ///
  /// In en, this message translates to:
  /// **'Branch setup'**
  String get branchSetup;

  /// No description provided for @noActiveBranch.
  ///
  /// In en, this message translates to:
  /// **'No active branch exists. Create the first branch to start using Brade and Cake House.'**
  String get noActiveBranch;

  /// No description provided for @createMainBranch.
  ///
  /// In en, this message translates to:
  /// **'Create main branch'**
  String get createMainBranch;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get creating;

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

  /// No description provided for @languageResetNotice.
  ///
  /// In en, this message translates to:
  /// **'We switched back to English.'**
  String get languageResetNotice;

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

  /// No description provided for @appNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'App is not configured, please contact support.'**
  String get appNotConfigured;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get errorNoInternet;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service is temporarily unavailable. Please try again in a moment.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try signing in.'**
  String get errorEmailAlreadyRegistered;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get errorWeakPassword;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do this.'**
  String get errorPermissionDenied;

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorSomethingWentWrong;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Some of the details are not valid. Please check and try again.'**
  String get errorInvalidInput;

  /// No description provided for @errorOperationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This action is not allowed right now.'**
  String get errorOperationNotAllowed;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large. Please choose a smaller file.'**
  String get errorFileTooLarge;

  /// No description provided for @errorUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported.'**
  String get errorUnsupportedFile;

  /// No description provided for @errorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be uploaded. Please try again.'**
  String get errorUploadFailed;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before signing in.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorDuplicateRecord.
  ///
  /// In en, this message translates to:
  /// **'This record already exists.'**
  String get errorDuplicateRecord;

  /// No description provided for @errorRecordInUse.
  ///
  /// In en, this message translates to:
  /// **'This record is still in use and cannot be deleted.'**
  String get errorRecordInUse;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get errorInvalidEmail;

  /// No description provided for @errorPasswordMin8.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get errorPasswordMin8;

  /// No description provided for @errorPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get errorPasswordsDoNotMatch;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get errorTooManyAttempts;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get offlineBanner;

  /// No description provided for @contactAdminToGetAccount.
  ///
  /// In en, this message translates to:
  /// **'Contact the administrator to get an account.'**
  String get contactAdminToGetAccount;

  /// No description provided for @createFirstAccount.
  ///
  /// In en, this message translates to:
  /// **'Create the first account'**
  String get createFirstAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @createCustomerAccount.
  ///
  /// In en, this message translates to:
  /// **'Create customer account'**
  String get createCustomerAccount;

  /// No description provided for @signUpFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'Create the first account'**
  String get signUpFirstTitle;

  /// No description provided for @signUpCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpCustomerTitle;

  /// No description provided for @signUpFirstHelp.
  ///
  /// In en, this message translates to:
  /// **'The first account created in a new business becomes the administrator. Later accounts need a role assigned by an administrator.'**
  String get signUpFirstHelp;

  /// No description provided for @signUpCustomerHelp.
  ///
  /// In en, this message translates to:
  /// **'An administrator will review your account and assign customer access.'**
  String get signUpCustomerHelp;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get creatingAccount;

  /// No description provided for @accountCreatedConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to confirm it, then sign in.'**
  String get accountCreatedConfirmEmail;

  /// No description provided for @accountCreatedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Account created. You can sign in now.'**
  String get accountCreatedSignIn;

  /// No description provided for @accountCreatedAwaitAdmin.
  ///
  /// In en, this message translates to:
  /// **'Account created. An administrator will activate your customer access.'**
  String get accountCreatedAwaitAdmin;

  /// No description provided for @checkingAccountOptions.
  ///
  /// In en, this message translates to:
  /// **'Checking account options…'**
  String get checkingAccountOptions;

  /// No description provided for @couldNotCheckSignup.
  ///
  /// In en, this message translates to:
  /// **'Could not load sign-up options. Please try again.'**
  String get couldNotCheckSignup;

  /// No description provided for @customerSignupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Customer sign-up is currently closed.'**
  String get customerSignupDisabled;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackAgainToExit;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Leave this form?'**
  String get discardChangesMessage;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get passwordUpdated;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @avatar.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get avatar;

  /// No description provided for @uploadAvatar.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get uploadAvatar;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @helpContact.
  ///
  /// In en, this message translates to:
  /// **'Help & contact'**
  String get helpContact;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationPreferences;

  /// No description provided for @notificationCenter.
  ///
  /// In en, this message translates to:
  /// **'Notification center'**
  String get notificationCenter;

  /// No description provided for @businessSettings.
  ///
  /// In en, this message translates to:
  /// **'Business settings'**
  String get businessSettings;

  /// No description provided for @masterData.
  ///
  /// In en, this message translates to:
  /// **'Master data'**
  String get masterData;

  /// No description provided for @rolePermissions.
  ///
  /// In en, this message translates to:
  /// **'Roles & permissions'**
  String get rolePermissions;

  /// No description provided for @auditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get auditLog;

  /// No description provided for @dataExport.
  ///
  /// In en, this message translates to:
  /// **'Data export'**
  String get dataExport;

  /// No description provided for @generateInvoices.
  ///
  /// In en, this message translates to:
  /// **'Generate invoices'**
  String get generateInvoices;

  /// No description provided for @runAlerts.
  ///
  /// In en, this message translates to:
  /// **'Run alerts now'**
  String get runAlerts;

  /// No description provided for @languageAppearance.
  ///
  /// In en, this message translates to:
  /// **'Language & appearance'**
  String get languageAppearance;

  /// No description provided for @supportContact.
  ///
  /// In en, this message translates to:
  /// **'Support contact'**
  String get supportContact;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionLabel;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// No description provided for @slogan.
  ///
  /// In en, this message translates to:
  /// **'Slogan'**
  String get slogan;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @vatRate.
  ///
  /// In en, this message translates to:
  /// **'VAT rate (%)'**
  String get vatRate;

  /// No description provided for @totRate.
  ///
  /// In en, this message translates to:
  /// **'TOT rate (%)'**
  String get totRate;

  /// No description provided for @defaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default language'**
  String get defaultLanguage;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get saved;

  /// No description provided for @noPermissionForArea.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this area.'**
  String get noPermissionForArea;

  /// No description provided for @notificationsSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences saved.'**
  String get notificationsSaved;

  /// No description provided for @alertsGenerated.
  ///
  /// In en, this message translates to:
  /// **'Alerts generated.'**
  String get alertsGenerated;

  /// No description provided for @avatarUploaded.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated.'**
  String get avatarUploaded;

  /// No description provided for @emailReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Email cannot be changed here.'**
  String get emailReadOnly;

  /// No description provided for @selectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Select photo'**
  String get selectPhoto;

  /// No description provided for @csvExport.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get csvExport;

  /// No description provided for @pdfExport.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdfExport;

  /// No description provided for @excelExport.
  ///
  /// In en, this message translates to:
  /// **'Excel'**
  String get excelExport;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Export saved.'**
  String get exportSaved;

  /// No description provided for @pressBackToReturn.
  ///
  /// In en, this message translates to:
  /// **'Press back to return.'**
  String get pressBackToReturn;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @signOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this account?'**
  String get signOutConfirmation;

  /// No description provided for @approvals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvals;

  /// No description provided for @voidSaleAlreadyVoided.
  ///
  /// In en, this message translates to:
  /// **'This sale has already been voided.'**
  String get voidSaleAlreadyVoided;

  /// No description provided for @voidSaleFailed.
  ///
  /// In en, this message translates to:
  /// **'The sale could not be voided. Please check the sale and try again.'**
  String get voidSaleFailed;

  /// No description provided for @voidSaleNotFound.
  ///
  /// In en, this message translates to:
  /// **'This sale could not be found. Refresh the list and try again.'**
  String get voidSaleNotFound;

  /// No description provided for @voidSaleOnlyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Only completed sales can be voided.'**
  String get voidSaleOnlyCompleted;

  /// No description provided for @voidSaleHasReturns.
  ///
  /// In en, this message translates to:
  /// **'This sale already has returns, so it cannot be voided. Use the return flow instead.'**
  String get voidSaleHasReturns;

  /// No description provided for @voidSaleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sale voided and stock restored.'**
  String get voidSaleSuccess;
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
