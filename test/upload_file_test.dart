import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/network/upload_file.dart';

/// The document endpoint checks what a file *is*, not what it is called
/// (API.md §7), so the client has to read the same thing before sending.
void main() {
  Uint8List bytes(List<int> head) =>
      Uint8List.fromList([...head, ...List.filled(16, 0)]);

  test('recognises the formats by their first bytes', () {
    expect(UploadFile.sniffExtension(bytes([0xFF, 0xD8, 0xFF, 0xE0])), 'jpg');
    expect(
      UploadFile.sniffExtension(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])),
      'png',
    );
    expect(UploadFile.sniffExtension(bytes('%PDF-1.7'.codeUnits)), 'pdf');
    expect(
      UploadFile.sniffExtension(
        bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
      ),
      'webp',
    );
  });

  test('sees a HEIC photo whatever it is named', () {
    // Box size, then `ftyp`, then the brand — how an Android gallery HEIC
    // starts even when its name ends in .jpg.
    expect(
      UploadFile.sniffExtension(
        bytes([0, 0, 0, 0x18, ...'ftyp'.codeUnits, ...'heic'.codeUnits]),
      ),
      'heic',
    );
  });

  test('says nothing about bytes it does not know', () {
    expect(UploadFile.sniffExtension(bytes([1, 2, 3, 4])), isNull);
    expect(UploadFile.sniffExtension(Uint8List(0)), isNull);
  });
}
