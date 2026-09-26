import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// A file on its way to a `multipart/form-data` endpoint.
///
/// Sits between the picker and the API services so nothing in the feature
/// layer has to import Dio to attach an avatar or a document scan.
class UploadFile extends Equatable {
  const UploadFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;

  /// `image/jpeg`, `application/pdf`, …
  final String contentType;

  /// Builds one from raw bytes and a bare extension (`jpg`, `png`, `pdf`).
  factory UploadFile.fromExtension({
    required Uint8List bytes,
    required String extension,
    required String baseName,
  }) {
    final normalized = extension.toLowerCase().replaceFirst('.', '');
    return UploadFile(
      bytes: bytes,
      fileName: '$baseName.$normalized',
      contentType: mimeFor(normalized),
    );
  }

  int get sizeBytes => bytes.length;

  bool fitsWithin(int maxBytes) => sizeBytes <= maxBytes;

  MultipartFile toMultipart() => MultipartFile.fromBytes(
    bytes,
    filename: fileName,
    contentType: DioMediaType.parse(contentType),
  );

  /// The format [bytes] actually are, read from their first bytes — `jpg`,
  /// `png`, `webp`, `heic` or `pdf` — or null when unrecognised.
  ///
  /// The file name is not evidence: Android's gallery can hand back a HEIC
  /// photo under a name that ends in anything, and Laravel's `mimes` rule
  /// checks the content, not the name.
  static String? sniffExtension(Uint8List bytes) {
    bool at(int offset, List<int> signature) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (at(0, const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (at(0, const [0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (at(0, const [0x25, 0x50, 0x44, 0x46])) return 'pdf'; // %PDF
    if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'webp';
    if (at(4, 'ftyp'.codeUnits)) {
      for (final brand in const ['heic', 'heix', 'hevc', 'heif', 'mif1']) {
        if (at(8, brand.codeUnits)) return 'heic';
      }
    }
    return null;
  }

  /// The types the API accepts: jpg/jpeg/png/webp for avatars, plus pdf for
  /// documents (API.md §4 and §7).
  static String mimeFor(String extension) => switch (extension.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };

  @override
  List<Object?> get props => [fileName, contentType, bytes.length];
}
