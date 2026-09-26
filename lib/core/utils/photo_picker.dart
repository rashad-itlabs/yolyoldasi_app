import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../extensions/context_extensions.dart';
import '../network/upload_file.dart';
import '../theme/app_dimens.dart';
import '../widgets/app_feedback.dart';

/// A picked image, already downscaled and ready to upload.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// Lower-case, no dot — `jpg`, `png`, …
  final String extension;
}

/// Camera / gallery picking, behind one call.
///
/// Images are capped at 1600px and re-encoded at 82% quality: plenty for an
/// avatar or a document scan, and small enough to upload on a mobile
/// connection.
abstract final class PhotoPicker {
  static final ImagePicker _picker = ImagePicker();

  /// Shows the source sheet, then picks. Returns `null` if cancelled.
  static Future<PickedPhoto?> pick(
    BuildContext context, {
    bool allowRemove = false,
    VoidCallback? onRemove,
  }) async {
    final l10n = context.l10n;

    final source = await AppFeedback.sheet<ImageSource?>(
      context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.pickFromGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            if (allowRemove)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: context.palette.danger,
                ),
                title: Text(
                  l10n.removePhoto,
                  style: TextStyle(color: context.palette.danger),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemove?.call();
                },
              ),
            VGap.md,
          ],
        ),
      ),
    );

    if (source == null) return null;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();

    // The content decides, the name is only a fallback — see
    // [UploadFile.sniffExtension].
    final name = file.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    final named = dot == -1 ? 'jpg' : name.substring(dot + 1);
    final extension = UploadFile.sniffExtension(bytes) ?? named;

    return PickedPhoto(
      bytes: bytes,
      extension: extension == 'jpeg' ? 'jpg' : extension,
    );
  }

  /// [photo] in one of the [accepted] formats, re-encoded as PNG when it is not
  /// already; null when the platform cannot decode it either.
  ///
  /// image_picker only re-encodes JPEG, PNG and WebP. A HEIC photo from an
  /// Android gallery comes back untouched and the server refuses it, so it is
  /// converted here rather than failing on the far side of the upload.
  static Future<PickedPhoto?> ensureFormat(
    PickedPhoto photo, {
    required Set<String> accepted,
  }) async {
    if (accepted.contains(photo.extension)) return photo;
    if (!accepted.contains('png')) return null;

    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(photo.bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = math.max(descriptor.width, descriptor.height);
      final scale = longest > _maxSide ? _maxSide / longest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();

      if (data == null) return null;
      return PickedPhoto(bytes: data.buffer.asUint8List(), extension: 'png');
    } catch (_) {
      return null;
    }
  }

  static const double _maxSide = 1600;
}
