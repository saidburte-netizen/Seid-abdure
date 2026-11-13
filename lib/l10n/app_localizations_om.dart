// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Oromo (`om`).
class AppLocalizationsOm extends AppLocalizations {
  AppLocalizationsOm([String locale = 'om']) : super(locale);

  @override
  String get appTitle => 'Bulchiinsa Buddeenaa fi Keekii';

  @override
  String get production => 'Oomisha';

  @override
  String get sales => 'Gurgurtaa fi POS';

  @override
  String get inventory => 'Kuusaa';

  @override
  String get cashManagement => 'Maallaqa';

  @override
  String get people => 'Hojjettoota';

  @override
  String get rentals => 'Kiraa';

  @override
  String get reports => 'Gabaasa';

  @override
  String get settings => 'Qindaa\'ina';

  @override
  String get moduleSetupMessage =>
      'Moojuuliin kun karoora hojii keessa jira; ammaaf hin argamu.';

  @override
  String get configurationRequired =>
      'Appii kana Supabase waliin wal qunnamsiisuuf SUPABASE_URL fi SUPABASE_ANON_KEY qindeessaa.';

  @override
  String get signIn => 'Seeni';

  @override
  String get signOut => 'Ba\'i';

  @override
  String get email => 'Imeelii';

  @override
  String get password => 'Jecha darbii';

  @override
  String get requiredField => 'Dirreen kun barbaachisaadha.';

  @override
  String get membershipRequired =>
      'Herregni keessan qophaa\'eera, garuu miseensummaan damee hojii irra jiru hin kennamne. Bulchaa keessan qunnamaa.';

  @override
  String get accessDenied =>
      'Gaheen keessan moojuulii kana seenuuf hayyama hin kennu.';

  @override
  String get accessLoadFailed =>
      'Hayyama herrega keessanii fe\'uun hin danda\'amne.';

  @override
  String get retry => 'Irra deebi\'ii yaali';
}
