// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bread & Cake Management';

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
  String get moduleSetupMessage =>
      'This module is part of the implementation roadmap and is not available yet.';

  @override
  String get configurationRequired =>
      'Set SUPABASE_URL and SUPABASE_ANON_KEY to connect this app to Supabase.';

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
}
