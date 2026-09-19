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
