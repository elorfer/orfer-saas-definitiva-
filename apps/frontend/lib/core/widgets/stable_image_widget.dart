/// Widget de imagen estable que evita parpadeo durante cambios de canción
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/image_preloader_service.dart';
import '../utils/url_normalizer.dart';

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
  String? _currentImageUrl;
  Widget? _currentImageWidget;
  Widget? _previousImageWidget;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _updateImage();
  }

  @override
  void didUpdateWidget(StableImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldNormalizedUrl = oldWidget.imageUrl != null 
        ? UrlNormalizer.normalizeImageUrl(oldWidget.imageUrl) 
        : null;
    final newNormalizedUrl = widget.imageUrl != null 
        ? UrlNormalizer.normalizeImageUrl(widget.imageUrl) 
        : null;
    
    if (oldNormalizedUrl != newNormalizedUrl) {
      _updateImage();
    }
  }

  void _updateImage() {
    final normalizedUrl = widget.imageUrl != null 
        ? UrlNormalizer.normalizeImageUrl(widget.imageUrl) 
        : null;
    
    if (normalizedUrl != _currentImageUrl) {
      setState(() {
        _previousImageWidget = _currentImageWidget;
        _currentImageUrl = normalizedUrl;
        _isTransitioning = true;
        
        if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
          _currentImageWidget = _buildCachedImage(normalizedUrl);
        } else {
          _currentImageWidget = _buildDefaultWidget();
        }
      });
      
      // Después de un breve delay, quitar la imagen anterior
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _isTransitioning = false;
            _previousImageWidget = null;
          });
        }
      });
    }
  }

  Widget _buildCachedImage(String imageUrl) {
    // 🚀 Verificar si la imagen ya está precargada para evitar animaciones
    final isPreloaded = ImagePreloaderService().isImagePreloaded(imageUrl);
    
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
        
        // Si es una imagen grande (portada), usar límites más altos pero razonables
        if (widget.isLargeCover) {
          final screenWidth = MediaQuery.of(context).size.width;
          final maxSize = (screenWidth * devicePixelRatio * 1.5).round(); // 1.5x para pantallas grandes
          memCacheWidth ??= maxSize;
          memCacheHeight ??= maxSize;
        }
        
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          // Optimización: límite de memoria para evitar alto uso de RAM
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          maxWidthDiskCache: memCacheWidth,
          maxHeightDiskCache: memCacheHeight,
          // 🎯 Sin animación si ya está precargada, transición rápida si no
          fadeInDuration: isPreloaded ? Duration.zero : const Duration(milliseconds: 100),
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          // Cache optimizado
          cacheKey: imageUrl,
          httpHeaders: const {
            'Accept': 'image/webp,image/jpeg,image/png;q=0.9,*/*;q=0.8',
            'Cache-Control': 'max-age=3600',
          },
          // Mantener imagen anterior durante cambio
          useOldImageOnUrlChange: true,
          filterQuality: FilterQuality.medium,
          placeholder: (context, url) => widget.placeholder ?? _buildPlaceholder(),
          errorWidget: (context, url, error) => widget.errorWidget ?? _buildErrorWidget(),
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

  Widget _buildDefaultWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.image, color: Colors.white70, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagen anterior (si está en transición)
        if (_isTransitioning && _previousImageWidget != null)
          _previousImageWidget!,
        
        // Imagen actual
        if (_currentImageWidget != null)
          AnimatedOpacity(
            opacity: _isTransitioning ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 100), // Más rápido para Hero
            child: _currentImageWidget!,
          ),
      ],
    );
  }
}
