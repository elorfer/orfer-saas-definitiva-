import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Wrapper ligero que normaliza el uso de `CachedNetworkImage` y calcula
/// `memCacheWidth`/`memCacheHeight` basados en el tamaño de render esperado
/// para reducir memoria y trabajo de decodificación en scroll.
class OptimizedCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedCachedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    int? memCacheWidth;
    int? memCacheHeight;

    if (width != null) memCacheWidth = (width! * devicePixelRatio).round();
    if (height != null) memCacheHeight = (height! * devicePixelRatio).round();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (ctx, url) => placeholder ?? const SizedBox.shrink(),
      errorWidget: (ctx, url, err) => errorWidget ?? const Icon(Icons.broken_image),
      useOldImageOnUrlChange: true,
    );
  }
}
