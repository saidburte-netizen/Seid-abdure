import 'package:flutter/widgets.dart';

const localeRecoveryPreferenceKey = 'reset_locale_on_next_launch';

Locale? localeFromLanguageCode(String? languageCode) =>
    switch (languageCode?.trim().toLowerCase()) {
      'en' => const Locale('en'),
      'am' => const Locale('am'),
      'om' => const Locale('om'),
      _ => null,
    };
