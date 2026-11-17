/// Build metadata injected by the Android release workflow with `--dart-define`.
///
/// The same values are written to the generated release notes and the workflow
/// summary, so Settings > About can be compared against the build log.
class BuildInfo {
  const BuildInfo._();

  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '',
  );
  static const String buildNumber = String.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: '',
  );
  static const String sha = String.fromEnvironment(
    'BUILD_SHA',
    defaultValue: 'unknown',
  );
  static const String branch = String.fromEnvironment(
    'BUILD_BRANCH',
    defaultValue: 'unknown',
  );

  static String get shortSha => sha.length <= 7 ? sha : sha.substring(0, 7);

  static String get display => '$version+$buildNumber ($branch@$shortSha)';
}
