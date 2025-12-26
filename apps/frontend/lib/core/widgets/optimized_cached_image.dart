import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_normalizer.dart';

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
    // 🛡️ SECURITY: Normalizar URL para asegurar que localhost se convierta a IP real
    // Esto repara las imágenes rotas en dispositivos físicos
    final normalizedUrl = UrlNormalizer.normalizeImageUrl(imageUrl);
    // Si la URL es inválida después de normalizar, retornar error widget o vacío
    if (normalizedUrl == null) {
        return SizedBox(
            width: width, 
            height: height, 
            child: errorWidget ?? const Icon(Icons.broken_image)
        );
    }

    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    int? memCacheWidth;
    int? memCacheHeight;

    if (width != null) memCacheWidth = (width! * devicePixelRatio).round();
    if (height != null) memCacheHeight = (height! * devicePixelRatio).round();

    return CachedNetworkImage(
      imageUrl: normalizedUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      // ⚡ FIX: Placeholder explícitamente transparente para evitar fondos negros por defecto
      placeholder: (ctx, url) => placeholder ?? const SizedBox.expand(child: ColoredBox(color: Colors.transparent)),
      errorWidget: (ctx, url, err) => errorWidget ?? const Icon(Icons.broken_image),
      useOldImageOnUrlChange: true, // Esto es clave para transiciones suaves
    );
  }
}
