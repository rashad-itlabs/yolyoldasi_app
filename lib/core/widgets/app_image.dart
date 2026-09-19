import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

/// Renders a remote image, or a placeholder while it loads or fails.
///
/// Every avatar and document thumbnail goes through here, so the caching and
/// fallback behaviour is decided once. The API returns absolute URLs
/// (`https://.../storage/avatars/x.jpg`), so there is nothing to resolve.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) return _fallback(context);

    return CachedNetworkImage(
      imageUrl: source,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, _) => _fallback(context),
      errorWidget: (context, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) =>
      placeholder ??
      Container(
        width: width,
        height: height,
        color: context.palette.shimmerBase,
      );
}
