import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';

/// Puts image bytes the app already holds into the network-image cache, under
/// the URL the server will serve them from.
///
/// After a photo upload the server answers with the photo's new URL — a URL
/// the cache has never seen, so every avatar on screen would download back the
/// very bytes the phone just sent. On a slow network, and with an unshrunk PNG
/// of a couple of megabytes, that left the new photo missing for ten seconds
/// or more.
abstract interface class ImageCacheSeeder {
  Future<void> seed(
    String url,
    Uint8List bytes, {
    required String fileExtension,
  });
}

/// The cache [CachedNetworkImage] itself reads from, so a seeded URL renders
/// from disk on the first frame.
class CachedImageSeeder implements ImageCacheSeeder {
  const CachedImageSeeder();

  @override
  Future<void> seed(
    String url,
    Uint8List bytes, {
    required String fileExtension,
  }) => CachedNetworkImageProvider.defaultCacheManager.putFile(
    url,
    bytes,
    fileExtension: fileExtension,
  );
}
