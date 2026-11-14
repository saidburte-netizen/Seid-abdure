// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Brade and Cake House';

  @override
  String get production => 'Production';

  @override
  String get sales => 'Sales & POS';

  @override
  String get inventory => 'Inventory';

  @override
  String get cashManagement => 'Cash';

  @override
  String get people => 'People & HR';

  @override
  String get rentals => 'Rentals';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get configurationRequired =>
      'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY) to connect this app to Supabase.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get membershipRequired =>
      'Your account is ready, but no active branch membership is assigned. Contact your administrator.';

  @override
  String get accessDenied => 'Your role does not grant access to this module.';

  @override
  String get accessLoadFailed => 'Could not load your account access.';

  @override
  String get retry => 'Retry';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get newSale => 'New sale';

  @override
  String get alerts => 'Alerts';

  @override
  String get productionModule => 'Production';

  @override
  String get salesModule => 'Sales & POS';

  @override
  String get inventoryModule => 'Inventory';

  @override
  String get cashModule => 'Cash & expenses';

  @override
  String get peopleModule => 'People & HR';

  @override
  String get payrollModule => 'Payroll';

  @override
  String get rentalsModule => 'Rentals';

  @override
  String get payablesModule => 'Payables';

  @override
  String get reportsModule => 'Reports';

  @override
  String get settingsModule => 'Settings';

  @override
  String get notificationsModule => 'Notifications';

  @override
  String get workspace => 'Workspace';

  @override
  String get workspaceSubtitle =>
      'All operational areas available to your role.';

  @override
  String get welcome => 'Welcome';

  @override
  String get adminPortal => 'Admin portal';

  @override
  String get managerPortal => 'Manager portal';

  @override
  String get teamPortal => 'Team portal';

  @override
  String get roleNoReports =>
      'Your role does not include dashboard reporting. Use the module shortcuts below.';

  @override
  String get todaySales => 'Today\'s sales';

  @override
  String get thisMonth => 'This month';

  @override
  String get cashBalance => 'Cash balance';

  @override
  String get receivables => 'Receivables';

  @override
  String get payables => 'Payables';

  @override
  String get rentOutstanding => 'Rent outstanding';

  @override
  String get lowStock => 'Low stock';

  @override
  String get pendingExpenses => 'Pending expenses';

  @override
  String get pendingLeave => 'Pending leave';

  @override
  String get batchesToday => 'Today\'s batches';

  @override
  String get activeEmployees => 'Active employees';

  @override
  String get revenueThisMonth => 'Revenue this month';

  @override
  String get signInSubtitle =>
      'Sign in to manage sales, stock, cash, people and property.';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get claimOwner => 'Claim owner account';

  @override
  String get claiming => 'Claiming…';

  @override
  String get claimOwnerHelp =>
      'If this is the first account for the business, claim ownership to create the organization and its first branch.';

  @override
  String get backToDashboard => 'Back to dashboard';

  @override
  String get menu => 'Menu';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System theme';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get refresh => 'Refresh';

  @override
  String get search => 'Search';

  @override
  String get export => 'Export';

  @override
  String get myAccount => 'My account';

  @override
  String get accountPreferences => 'Account and preferences';

  @override
  String get editDisplayName => 'Edit display name';

  @override
  String get displayName => 'Display name';

  @override
  String get fullName => 'Full name';

  @override
  String get english => 'English';

  @override
  String get noBranchSelected => 'No branch selected';

  @override
  String get appNotConfigured =>
      'App is not configured, please contact support.';

  @override
  String get errorNoInternet =>
      'No internet connection. Please check your network and try again.';

  @override
  String get errorServiceUnavailable =>
      'Service is temporarily unavailable. Please try again in a moment.';

  @override
  String get errorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get errorEmailAlreadyRegistered =>
      'This email is already registered. Try signing in.';

  @override
  String get errorWeakPassword => 'Password must be at least 8 characters.';

  @override
  String get errorPermissionDenied => 'You do not have permission to do this.';

  @override
  String get errorSomethingWentWrong =>
      'Something went wrong. Please try again.';

  @override
  String get errorEmailNotConfirmed =>
      'Please confirm your email before signing in.';

  @override
  String get errorDuplicateRecord => 'This record already exists.';

  @override
  String get errorRecordInUse =>
      'This record is still in use and cannot be deleted.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorInvalidEmail => 'Enter a valid email address.';

  @override
  String get errorPasswordMin8 => 'Password must be at least 8 characters.';

  @override
  String get errorPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get errorTooManyAttempts =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get offlineBanner => 'You are offline';

  @override
  String get contactAdminToGetAccount =>
      'Contact the administrator to get an account.';

  @override
  String get createFirstAccount => 'Create the first account';

  @override
  String get createAccount => 'Create account';

  @override
  String get createCustomerAccount => 'Create customer account';

  @override
  String get signUpFirstTitle => 'Create the first account';

  @override
  String get signUpCustomerTitle => 'Create your account';

  @override
  String get signUpFirstHelp =>
      'The first account created in a new business becomes the administrator. Later accounts need a role assigned by an administrator.';

  @override
  String get signUpCustomerHelp =>
      'An administrator will review your account and assign customer access.';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get creatingAccount => 'Creating account…';

  @override
  String get accountCreatedConfirmEmail =>
      'Account created. Check your email to confirm it, then sign in.';

  @override
  String get accountCreatedSignIn => 'Account created. You can sign in now.';

  @override
  String get accountCreatedAwaitAdmin =>
      'Account created. An administrator will activate your customer access.';

  @override
  String get checkingAccountOptions => 'Checking account options…';

  @override
  String get couldNotCheckSignup =>
      'Could not load sign-up options. Please try again.';

  @override
  String get customerSignupDisabled => 'Customer sign-up is currently closed.';
}
