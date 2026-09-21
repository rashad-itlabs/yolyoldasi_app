import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/features/app_update/data/models/app_update_model.dart';
import 'package:yolyoldasi/features/app_update/domain/entities/app_update.dart';
import 'package:yolyoldasi/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:yolyoldasi/features/app_update/presentation/bloc/app_update/app_update_bloc.dart';
import 'package:yolyoldasi/features/settings/domain/repositories/settings_repository.dart';

/// The update gate decides whether the app opens at all, so the tests that
/// matter here are the ones about *not* closing it: an unreachable server, an
/// unrecognised answer, a build that cannot name itself.
void main() {
  group('AppUpdateModel', () {
    test('reads a forced answer whole', () {
      final update = AppUpdateModel.fromJson(const {
        'status': 'required',
        'min_version': '1.1.0',
        'latest_version': '1.2.0',
        'store_url': 'https://play.google.com/store/apps/details?id=x',
        'message': 'Köhnə versiya artıq işləmir.',
      });

      expect(update.status, AppUpdateStatus.forced);
      expect(update.blocks, isTrue);
      expect(update.minVersion, '1.1.0');
      expect(update.latestVersion, '1.2.0');
      expect(update.message, 'Köhnə versiya artıq işləmir.');
    });

    test('an `ok` answer carries nothing and blocks nothing', () {
      final update = AppUpdateModel.fromJson(const {'status': 'ok'});

      expect(update.status, AppUpdateStatus.none);
      expect(update.blocks, isFalse);
      expect(update.isOptional, isFalse);
      expect(update.storeUrl, isNull);
    });

    test('optional is optional', () {
      final update = AppUpdateModel.fromJson(const {
        'status': 'optional',
        'latest_version': '1.2.0',
      });

      expect(update.isOptional, isTrue);
      expect(update.blocks, isFalse);
    });

    test('a status this build does not know lets the user through', () {
      // A future server growing a fourth status must not lock out every
      // build that shipped before it — which is every build that would ever
      // receive the new word.
      for (final status in ['', 'deprecated', 'REQUIRED', 'blocked']) {
        final update = AppUpdateModel.fromJson({'status': status});
        expect(
          update.blocks,
          isFalse,
          reason: 'unknown status "$status" must not block',
        );
      }
    });

    test('an empty body is not a verdict', () {
      expect(AppUpdateModel.fromJson(const {}).blocks, isFalse);
    });
  });

  group('AppUpdateBloc', () {
    test('a forced answer blocks', () async {
      final bloc = AppUpdateBloc(
        updates: _StubRepository(
          const Ok(AppUpdate(status: AppUpdateStatus.forced)),
        ),
        settings: _FakeSettings(),
      );
      addTearDown(bloc.close);

      bloc.add(const AppUpdateChecked());
      await bloc.stream.first;

      expect(bloc.state.blocks, isTrue);
    });

    test('a failed check changes nothing', () async {
      // The server being unreachable is not evidence that the app is out of
      // date. Treating it as such would take the app down for everyone every
      // time the API hiccups.
      final bloc = AppUpdateBloc(
        updates: _StubRepository(const Err(NetworkFailure())),
        settings: _FakeSettings(),
      );
      addTearDown(bloc.close);

      bloc.add(const AppUpdateChecked());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.blocks, isFalse);
      expect(bloc.state.showsOptional, isFalse);
      expect(bloc.state.update, AppUpdate.none);
    });

    test('an optional prompt is owed once, then remembered', () async {
      final settings = _FakeSettings();
      final bloc = AppUpdateBloc(
        updates: _StubRepository(
          const Ok(
            AppUpdate(status: AppUpdateStatus.optional, latestVersion: '1.2.0'),
          ),
        ),
        settings: settings,
      );
      addTearDown(bloc.close);

      bloc.add(const AppUpdateChecked());
      await bloc.stream.first;
      expect(bloc.state.showsOptional, isTrue);

      bloc.add(const AppUpdateDismissed());
      await bloc.stream.first;

      expect(bloc.state.showsOptional, isFalse);
      expect(
        settings.dismissedUpdateVersion,
        '1.2.0',
        reason: 'the answer has to survive the next launch',
      );
    });

    test('a release already dismissed does not ask again', () async {
      final bloc = AppUpdateBloc(
        updates: _StubRepository(
          const Ok(
            AppUpdate(status: AppUpdateStatus.optional, latestVersion: '1.2.0'),
          ),
        ),
        settings: _FakeSettings(dismissed: '1.2.0'),
      );
      addTearDown(bloc.close);

      bloc.add(const AppUpdateChecked());
      await bloc.stream.first;

      expect(bloc.state.showsOptional, isFalse);
    });

    test('a newer release asks again', () async {
      final bloc = AppUpdateBloc(
        updates: _StubRepository(
          const Ok(
            AppUpdate(status: AppUpdateStatus.optional, latestVersion: '1.3.0'),
          ),
        ),
        settings: _FakeSettings(dismissed: '1.2.0'),
      );
      addTearDown(bloc.close);

      bloc.add(const AppUpdateChecked());
      await bloc.stream.first;

      expect(bloc.state.showsOptional, isTrue);
    });

    test('"later" never applies to a forced update', () async {
      final bloc = AppUpdateBloc(
        updates: _StubRepository(
          const Ok(
            AppUpdate(status: AppUpdateStatus.forced, latestVersion: '1.2.0'),
          ),
        ),
        settings: _FakeSettings(dismissed: '1.2.0'),
      );
      addTearDown(bloc.close);

      bloc.add(const AppUpdateChecked());
      await bloc.stream.first;

      expect(bloc.state.blocks, isTrue);
      expect(bloc.state.showsOptional, isFalse);
    });
  });
}

class _StubRepository implements AppUpdateRepository {
  const _StubRepository(this._answer);

  final Result<AppUpdate> _answer;

  @override
  FutureResult<AppUpdate> check() async => _answer;
}

class _FakeSettings implements SettingsRepository {
  _FakeSettings({String? dismissed}) : _dismissed = dismissed;

  String? _dismissed;

  @override
  String? get dismissedUpdateVersion => _dismissed;

  @override
  Future<void> setDismissedUpdateVersion(String? version) async {
    _dismissed = version;
  }

  @override
  bool get onboardingSeen => true;

  @override
  ThemeMode get themeMode => ThemeMode.system;

  @override
  String? get languageCode => null;

  @override
  Future<void> load() async {}

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  Future<void> setLanguageCode(String? code) async {}

  @override
  Future<void> setOnboardingSeen(bool seen) async {}

  @override
  Future<void> clearForSignOut() async {}
}
