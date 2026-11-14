// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'Brade and Cake House';

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
  String get configurationRequired =>
      'መተግበሪያውን ከSupabase ለማገናኘት SUPABASE_URL እና SUPABASE_PUBLISHABLE_KEY (ወይም SUPABASE_ANON_KEY) ያዘጋጁ።';

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

  @override
  String get dashboard => 'ዳሽቦርድ';

  @override
  String get newSale => 'አዲስ ሽያጭ';

  @override
  String get alerts => 'ማንቂያዎች';

  @override
  String get productionModule => 'ምርት';

  @override
  String get salesModule => 'ሽያጭ እና ካሽ ሬጂስተር';

  @override
  String get inventoryModule => 'ክምችት';

  @override
  String get cashModule => 'ጥሬ ገንዘብ እና ወጪዎች';

  @override
  String get peopleModule => 'ሰዎች እና የሰው ሃብት';

  @override
  String get payrollModule => 'ደመወዝ';

  @override
  String get rentalsModule => 'ኪራይ';

  @override
  String get payablesModule => 'የሚከፈሉ ዕዳዎች';

  @override
  String get reportsModule => 'ሪፖርቶች';

  @override
  String get settingsModule => 'ቅንብሮች';

  @override
  String get notificationsModule => 'ማሳወቂያዎች';

  @override
  String get workspace => 'የስራ ቦታ';

  @override
  String get workspaceSubtitle => 'ለሚናዎ የሚገኙ ሁሉም የስራ ክፍሎች።';

  @override
  String get welcome => 'እንኳን ደህና መጡ';

  @override
  String get adminPortal => 'የአስተዳዳሪ ፖርታል';

  @override
  String get managerPortal => 'የስራ አስኪያጅ ፖርታል';

  @override
  String get teamPortal => 'የቡድን ፖርታል';

  @override
  String get roleNoReports =>
      'ሚናዎ የዳሽቦርድ ሪፖርት አያካትትም። ከታች ያሉትን የክፍል አቋራጮች ይጠቀሙ።';

  @override
  String get todaySales => 'የዛሬ ሽያጭ';

  @override
  String get thisMonth => 'በዚህ ወር';

  @override
  String get cashBalance => 'የጥሬ ገንዘብ ቀሪ';

  @override
  String get receivables => 'የሚቀበሉ ገንዘብ';

  @override
  String get payables => 'የሚከፈሉ ዕዳዎች';

  @override
  String get rentOutstanding => 'ያልተከፈለ ኪራይ';

  @override
  String get lowStock => 'ዝቅተኛ ክምችት';

  @override
  String get pendingExpenses => 'በመጠባበቅ ላይ ያሉ ወጪዎች';

  @override
  String get pendingLeave => 'በመጠባበቅ ላይ ያለ ፍቃድ';

  @override
  String get batchesToday => 'የዛሬ ምርት ቡድኖች';

  @override
  String get activeEmployees => 'ንቁ ሰራተኞች';

  @override
  String get revenueThisMonth => 'የዚህ ወር ገቢ';

  @override
  String get signInSubtitle => 'ሽያጭ፣ ክምችት፣ ጥሬ ገንዘብ፣ ሰዎች እና ንብረት ለማስተዳደር ይግቡ።';

  @override
  String get signingIn => 'በመግባት ላይ…';

  @override
  String get claimOwner => 'የባለቤት መለያ ይውሰዱ';

  @override
  String get claiming => 'በመውሰድ ላይ…';

  @override
  String get claimOwnerHelp =>
      'ይህ ለንግዱ የመጀመሪያ መለያ ከሆነ፣ ድርጅቱን እና የመጀመሪያውን ቅርንጫፍ ለመፍጠር ባለቤትነትን ይውሰዱ።';

  @override
  String get backToDashboard => 'ወደ ዳሽቦርድ ተመለስ';

  @override
  String get menu => 'ምናሌ';

  @override
  String get language => 'ቋንቋ';

  @override
  String get theme => 'ገጽታ';

  @override
  String get systemTheme => 'የስርዓት ገጽታ';

  @override
  String get lightTheme => 'ብርሃን ገጽታ';

  @override
  String get darkTheme => 'ጨለማ ገጽታ';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get close => 'ዝጋ';

  @override
  String get add => 'ጨምር';

  @override
  String get edit => 'አርትዕ';

  @override
  String get delete => 'አጥፋ';

  @override
  String get refresh => 'አድስ';

  @override
  String get search => 'ፈልግ';

  @override
  String get export => 'ላክ';

  @override
  String get myAccount => 'የእኔ መለያ';

  @override
  String get accountPreferences => 'መለያ እና ምርጫዎች';

  @override
  String get editDisplayName => 'የሚታይ ስም አርትዕ';

  @override
  String get displayName => 'የሚታይ ስም';

  @override
  String get fullName => 'ሙሉ ስም';

  @override
  String get english => 'English';

  @override
  String get noBranchSelected => 'ቅርንጫፍ አልተመረጠም';

  @override
  String get appNotConfigured => 'መተግበሪያው አልተዘጋጀም። እባክዎ ድጋፍን ያግኙ።';

  @override
  String get errorNoInternet =>
      'የኢንተርኔት ግንኙነት የለም። እባክዎ ኔትወርክዎን ያረጋግጡ እና እንደገና ይሞክሩ።';

  @override
  String get errorServiceUnavailable =>
      'አገልግሎቱ ለጊዜው አይገኝም። እባክዎ በአጭር ጊዜ ውስጥ እንደገና ይሞክሩ።';

  @override
  String get errorInvalidCredentials => 'ኢሜይል ወይም የይለፍ ቃል ትክክል አይደለም።';

  @override
  String get errorEmailAlreadyRegistered => 'ይህ ኢሜይል አስቀድሞ ተመዝግቧል። እባክዎ ይግቡ።';

  @override
  String get errorWeakPassword => 'የይለፍ ቃል ቢያንስ 8 ፊደሎች መሆን አለበት።';

  @override
  String get errorPermissionDenied => 'ይህንን ለማድረግ ፈቃድ የለዎትም።';

  @override
  String get errorSomethingWentWrong => 'የተሳሳተ ነገር ተከስቷል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get errorEmailNotConfirmed => 'ከመግባትዎ በፊት እባክዎ ኢሜይልዎን ያረጋግጡ።';

  @override
  String get errorDuplicateRecord => 'ይህ መዝገብ አስቀድሞ አለ።';

  @override
  String get errorRecordInUse => 'ይህ መዝገብ አሁንም ጥቅም ላይ ስለሆነ ሊሰረዝ አይችልም።';

  @override
  String get errorSessionExpired => 'ክፍለ ጊዜዎ አልቋል። እባክዎ እንደገና ይግቡ።';

  @override
  String get errorInvalidEmail => 'ትክክለኛ የኢሜይል አድራሻ ያስገቡ።';

  @override
  String get errorPasswordMin8 => 'የይለፍ ቃል ቢያንስ 8 ፊደሎች መሆን አለበት።';

  @override
  String get errorPasswordsDoNotMatch => 'የይለፍ ቃላቱ አይመሳሰሉም።';

  @override
  String get errorTooManyAttempts => 'ብዙ ሙከራዎች። እባክዎ ትንሽ ይጠብቁ እና እንደገና ይሞክሩ።';

  @override
  String get offlineBanner => 'ከመስመር ውጭ ነዎት';

  @override
  String get contactAdminToGetAccount => 'መለያ ለማግኘት አስተዳዳሪውን ያነጋግሩ።';

  @override
  String get createFirstAccount => 'የመጀመሪያውን መለያ ይፍጠሩ';

  @override
  String get createAccount => 'መለያ ይፍጠሩ';

  @override
  String get createCustomerAccount => 'የደንበኛ መለያ ይፍጠሩ';

  @override
  String get signUpFirstTitle => 'የመጀመሪያውን መለያ ይፍጠሩ';

  @override
  String get signUpCustomerTitle => 'መለያዎን ይፍጠሩ';

  @override
  String get signUpFirstHelp =>
      'በአዲስ ንግድ ውስጥ የመጀመሪያው መለያ አስተዳዳሪ ይሆናል። በኋላ የሚፈጠሩ መለያዎች በአስተዳዳሪ ሚና መመደብ ይፈልጋሉ።';

  @override
  String get signUpCustomerHelp => 'አስተዳዳሪው መለያዎን ገምግሞ የደንበኛ ፈቃድ ይመድባል።';

  @override
  String get confirmPassword => 'የይለፍ ቃል ያረጋግጡ';

  @override
  String get creatingAccount => 'መለያ በመፍጠር ላይ…';

  @override
  String get accountCreatedConfirmEmail =>
      'መለያ ተፈጥሯል። እባክዎ ኢሜይልዎን ያረጋግጡ፣ ከዚያ ይግቡ።';

  @override
  String get accountCreatedSignIn => 'መለያ ተፈጥሯል። አሁን መግባት ይችላሉ።';

  @override
  String get accountCreatedAwaitAdmin => 'መለያ ተፈጥሯል። አስተዳዳሪው የደንበኛ ፈቃድዎን ያነቃል።';

  @override
  String get checkingAccountOptions => 'የመለያ አማራጮችን በመፈተሽ ላይ…';

  @override
  String get couldNotCheckSignup => 'የምዝገባ አማራጮችን መጫን አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get customerSignupDisabled => 'የደንበኛ ምዝገባ በአሁኑ ጊዜ ተዘግቷል።';
}
