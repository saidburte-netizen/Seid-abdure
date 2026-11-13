// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'የዳቦና ኬክ አስተዳደር';

  @override
  String get production => 'ምርት';

  @override
  String get sales => 'ሽያጭና POS';

  @override
  String get inventory => 'ክምችት';

  @override
  String get cashManagement => 'ገንዘብ';

  @override
  String get people => 'ሰው ኃይል';

  @override
  String get rentals => 'ኪራይ';

  @override
  String get reports => 'ሪፖርቶች';

  @override
  String get settings => 'ቅንብሮች';

  @override
  String get moduleSetupMessage => 'ይህ ሞጁል በእቅድ ላይ ነው፤ ገና አይገኝም።';

  @override
  String get configurationRequired =>
      'ይህን መተግበሪያ ከSupabase ጋር ለማገናኘት SUPABASE_URL እና SUPABASE_ANON_KEY ያዘጋጁ።';

  @override
  String get signIn => 'ግባ';

  @override
  String get signOut => 'ውጣ';

  @override
  String get email => 'ኢሜይል';

  @override
  String get password => 'የይለፍ ቃል';

  @override
  String get requiredField => 'ይህ መስክ ያስፈልጋል።';

  @override
  String get membershipRequired =>
      'መለያዎ ዝግጁ ነው፣ ግን ንቁ የቅርንጫፍ አባልነት አልተመደበም። አስተዳዳሪዎን ያነጋግሩ።';

  @override
  String get accessDenied => 'የእርስዎ ሚና ወደዚህ ሞጁል መግባት አይፈቅድም።';

  @override
  String get accessLoadFailed => 'የመለያዎን ፈቃዶች መጫን አልተቻለም።';

  @override
  String get retry => 'እንደገና ሞክር';
}
