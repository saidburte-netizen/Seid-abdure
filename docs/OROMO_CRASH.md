# Oromo locale crash

## Reproduction

Before the fix, `flutter test test/oromo_localizations_test.dart` failed when
the app opened a Material date picker with `Locale('om')`. Flutter logged:

```text
Warning: This application's locale, om, is not supported by all of its localization delegates.
A MaterialLocalizations delegate that supports the om locale was not found.
A CupertinoLocalizations delegate that supports the om locale was not found.
```

The widget failure was:

```text
No MaterialLocalizations found.
AppBar widgets require MaterialLocalizations to be provided by a Localizations widget ancestor.
```

The application declared Oromo in `supportedLocales` and supplied its Oromo
ARB messages, but Flutter's built-in Material and Cupertino delegates do not
support `om`. Consequently, common Material widgets could not resolve their
required localization objects.

## Fix

Provide Oromo-specific Material, Cupertino and Widgets delegates that load
Flutter's English localization data. Keep the Oromo app-message delegate and
ARB catalog active, so only framework-provided labels fall back to English.
Date, number and ETB formatting must use a supported formatting locale (`en`
for Oromo), and locale restoration must validate the stored code and recover
to English rather than leaving the app in a broken state.
