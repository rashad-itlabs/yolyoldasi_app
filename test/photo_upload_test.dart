import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/bloc/data_status.dart';
import 'package:yolyoldasi/core/config/app_config.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/network/upload_file.dart';
import 'package:yolyoldasi/core/services/image_cache_seeder.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/profile/data/repositories/user_repository_impl.dart';
import 'package:yolyoldasi/features/profile/data/services/device_token_api_service.dart';
import 'package:yolyoldasi/features/profile/data/services/user_api_service.dart';
import 'package:yolyoldasi/features/profile/presentation/bloc/profile_form/profile_form_bloc.dart';

/// Reported: a new profile photo uploaded fine but took 10–15 seconds to
/// appear. The server gave it a new URL, and every avatar downloaded back the
/// two-megabyte PNG the phone had just sent.
void main() {
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
  final photo = UploadFile.fromExtension(
    bytes: bytes,
    extension: 'png',
    baseName: 'avatar',
  );
  final host = Uri.parse(AppConfig.apiBaseUrl).origin;

  group('uploading a photo', () {
    test(
      'puts the bytes in the image cache under the URL served back',
      () async {
        final cache = _RecordingSeeder();
        final users = _repository(
          _Server.ok('/storage/avatars/new.png'),
          cache,
        );

        final result = await users.uploadPhoto(photo);

        expect(result.valueOrNull?.photoUrl, '/storage/avatars/new.png');
        expect(cache.seeded, hasLength(1));
        expect(cache.seeded.single.url, '$host/storage/avatars/new.png');
        expect(cache.seeded.single.bytes, bytes);
        expect(cache.seeded.single.extension, 'png');
      },
    );

    test('a cache that cannot be written does not fail the upload', () async {
      final users = _repository(
        _Server.ok('$host/storage/avatars/new.png'),
        _ThrowingSeeder(),
      );

      final result = await users.uploadPhoto(photo);

      expect(result.valueOrNull?.photoUrl, '$host/storage/avatars/new.png');
    });

    test('nothing is cached when the upload itself fails', () async {
      final cache = _RecordingSeeder();
      final users = _repository(_Server.failing(), cache);

      final result = await users.uploadPhoto(photo);

      expect(result.valueOrNull, isNull);
      expect(cache.seeded, isEmpty);
    });
  });

  group('the profile form', () {
    blocTest<ProfileFormBloc, ProfileFormState>(
      'shows the picked photo while it uploads, then the stored one',
      build: () => ProfileFormBloc(
        users: _repository(
          _Server.ok('$host/storage/avatars/new.png'),
          _RecordingSeeder(),
        ),
      ),
      act: (bloc) => bloc.add(ProfilePhotoPicked(photo)),
      // The upload goes through a real Dio stack; let it answer.
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<ProfileFormState>()
            .having((s) => s.photoStatus, 'status', ActionStatus.inProgress)
            .having((s) => s.pendingPhoto, 'preview', bytes),
        isA<ProfileFormState>()
            .having((s) => s.photoStatus, 'status', ActionStatus.success)
            .having((s) => s.pendingPhoto, 'preview', isNull)
            .having(
              (s) => s.photoUrl,
              'photo',
              '$host/storage/avatars/new.png',
            ),
      ],
    );

    blocTest<ProfileFormBloc, ProfileFormState>(
      'drops the preview again when the upload fails',
      build: () => ProfileFormBloc(
        users: _repository(_Server.failing(), _RecordingSeeder()),
      ),
      act: (bloc) => bloc.add(ProfilePhotoPicked(photo)),
      // The upload goes through a real Dio stack; let it answer.
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<ProfileFormState>().having((s) => s.pendingPhoto, 'preview', bytes),
        isA<ProfileFormState>()
            .having((s) => s.photoStatus, 'status', ActionStatus.failure)
            .having((s) => s.pendingPhoto, 'preview', isNull),
      ],
    );
  });
}

UserRepositoryImpl _repository(_Server server, ImageCacheSeeder cache) {
  final client = ApiClient(
    tokens: InMemoryTokenStorage(),
    dio: Dio()..httpClientAdapter = server,
    baseUrl: 'https://example.test/api/v1',
  );
  return UserRepositoryImpl(
    users: UserApiService(client),
    deviceTokens: DeviceTokenApiService(client),
    imageCache: cache,
  );
}

class _RecordingSeeder implements ImageCacheSeeder {
  final List<({String url, Uint8List bytes, String extension})> seeded = [];

  @override
  Future<void> seed(
    String url,
    Uint8List bytes, {
    required String fileExtension,
  }) async => seeded.add((url: url, bytes: bytes, extension: fileExtension));
}

class _ThrowingSeeder implements ImageCacheSeeder {
  @override
  Future<void> seed(
    String url,
    Uint8List bytes, {
    required String fileExtension,
  }) => Future.error(StateError('disk full'));
}

/// Answers `POST /me/photo`, either with a profile carrying [photoUrl] or
/// with a server error.
class _Server implements HttpClientAdapter {
  _Server.ok(String this.photoUrl);
  _Server.failing() : photoUrl = null;

  final String? photoUrl;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = photoUrl;
    final (status, body) = url == null
        ? (500, <String, Object>{'message': 'Server Error'})
        : (
            200,
            <String, Object>{
              'data': {
                'id': 8,
                'phone': '+994501234567',
                'full_name': 'Rəşad Məmmədov',
                'photo_url': url,
              },
            },
          );
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
