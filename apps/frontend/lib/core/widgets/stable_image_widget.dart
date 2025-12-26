/// Widget de imagen estable que evita parpadeo durante cambios de canción
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_normalizer.dart';
import '../services/http_cache_service.dart';

class StableImageWidget extends StatefulWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isLargeCover;

  const StableImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.isLargeCover = false,
  });

  @override
  State<StableImageWidget> createState() => _StableImageWidgetState();
}

class _StableImageWidgetState extends State<StableImageWidget> {
  @override
  Widget build(BuildContext context) {
    // Si no hay URL, mostrar placeholder
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return widget.placeholder ?? _buildPlaceholder();
    }

    final normalizedUrl = UrlNormalizer.normalizeImageUrl(widget.imageUrl!);
    
    // Si la normalización falla (aunque sea improbable aquí), mostrar placeholder
    if (normalizedUrl == null) {
      return widget.placeholder ?? _buildPlaceholder();
    }

    return Builder(
      builder: (context) {
        // Calcular memCache basado en tamaño del widget y devicePixelRatio
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        int? memCacheWidth;
        int? memCacheHeight;
        
        if (widget.width != null && widget.width!.isFinite) {
          memCacheWidth = (widget.width! * devicePixelRatio).round();
        }
        if (widget.height != null && widget.height!.isFinite) {
          memCacheHeight = (widget.height! * devicePixelRatio).round();
        }
        
        // Si es una imagen grande (portada), usar límites más altos
        if (widget.isLargeCover) {
          final screenWidth = MediaQuery.of(context).size.width;
          final maxSize = (screenWidth * devicePixelRatio * 1.5).round(); 
          memCacheWidth ??= maxSize;
          memCacheHeight ??= maxSize;
        }

        return CachedNetworkImage(
          imageUrl: normalizedUrl,
          cacheManager: AlbumArtCacheManager.instance,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          // ✅ TRANSICIÓN SIMPLE: Fade rápido (200ms) sin "capa sobre capa"
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: null,
          placeholderFadeInDuration: Duration.zero,
          
          // ✅ EVITAR TARJETA NEGRA: Mantener imagen vieja visible hasta que cargue la nueva
          useOldImageOnUrlChange: true,
          
          // ✅ MEMORIA: Integración de ResizeImage
          imageBuilder: (context, imageProvider) {
            // Aplicar resize en memoria aquí
            final effectiveImageProvider = ResizeImage(
              imageProvider,
              width: memCacheWidth,
              height: memCacheHeight,
              policy: ResizeImagePolicy.fit,
            );
            
            return Image(
              image: effectiveImageProvider,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              filterQuality: FilterQuality.low,
            );
          },
          
          cacheKey: normalizedUrl,
          httpHeaders: const {
            'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
            'Cache-Control': 'max-age=7776000',
          },
          filterQuality: FilterQuality.low,
          placeholder: (context, url) => widget.placeholder ?? _buildPlaceholder(),
          errorWidget: (context, url, error) {
             debugPrint('[StableImageWidget] ❌ Error loading image $url: $error');
             // Si falla, intentamos mostrar placeholder en vez de nada
             return widget.errorWidget ?? _buildErrorWidget();
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white30, size: 48),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white, size: 48),
      ),
    );
  }
}
