import 'package:package_info_plus/package_info_plus.dart';

/// What version this build actually is, read from the binary at launch.
///
/// Read rather than declared. The force-update gate decides whether the app
/// opens at all by comparing [build] against what the server demands, and a
/// hand-maintained constant drifts the moment someone bumps `pubspec.yaml`
/// without touching it — which is exactly what had happened to the old
/// `AppConfig.appVersion`/`buildNumber` pair this replaces. The number that
/// locks users out has to come from the thing being versioned.
class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.build});

  /// `1.0.0` — the marketing version. Shown to the user; never compared.
  final String version;

  /// `versionCode` on Android, `CFBundleVersion` on iOS. Monotonic, which is
  /// why the gate compares this and not [version]: `1.0.10` sorts before
  /// `1.0.9` as a string, and no amount of care at the call site fixes that.
  final int build;

  /// Used when the platform channel is unavailable — a plain widget test, or
  /// a host with no plugin registered. A zero build reads as "unknown", and
  /// the gate lets an unknown build through rather than locking it out.
  static const AppVersionInfo unknown = AppVersionInfo(version: '', build: 0);

  bool get isKnown => build > 0;

  /// `1.0.0 (4)` — what the settings and profile screens show. The build is
  /// what a support conversation actually needs, so it is not hidden.
  String get display => isKnown ? '$version ($build)' : version;

  /// Never throws: a missing plugin must not take the launch down, so a
  /// failure degrades to [unknown] and the app opens.
  static Future<AppVersionInfo> read() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersionInfo(
        version: info.version,
        build: int.tryParse(info.buildNumber) ?? 0,
      );
    } catch (_) {
      return unknown;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppVersionInfo &&
          other.version == version &&
          other.build == build);

  @override
  int get hashCode => Object.hash(version, build);

  @override
  String toString() => 'AppVersionInfo($version+$build)';
}
