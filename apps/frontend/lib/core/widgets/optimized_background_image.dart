import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_normalizer.dart';
import '../theme/neumorphism_theme.dart';
import '../services/http_cache_service.dart';

/// Widget optimizado para fondo de reproductor con precarga y transiciones suaves
/// Elimina parpadeos al cambiar de canción
class OptimizedBackgroundImage extends StatefulWidget {
  final String? imageUrl;
  final BoxFit fit;

  const OptimizedBackgroundImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<OptimizedBackgroundImage> createState() => _OptimizedBackgroundImageState();
}

class _OptimizedBackgroundImageState extends State<OptimizedBackgroundImage> {
  String? _currentImageUrl;
  String? _previousImageUrl;
  ImageProvider? _currentImageProvider;
  ImageProvider? _previousImageProvider;
  bool _isImageReady = false;

  @override
  void initState() {
    super.initState();
    _loadImage(widget.imageUrl);
  }

  @override
  void didUpdateWidget(OptimizedBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldNormalizedUrl = oldWidget.imageUrl != null 
        ? UrlNormalizer.normalizeImageUrl(oldWidget.imageUrl) 
        : null;
    final newNormalizedUrl = widget.imageUrl != null 
        ? UrlNormalizer.normalizeImageUrl(widget.imageUrl) 
        : null;
    
    if (oldNormalizedUrl != newNormalizedUrl) {
      _loadImage(widget.imageUrl);
    }
  }

  Future<void> _loadImage(String? imageUrl) async {
    final normalizedUrl = imageUrl != null 
        ? UrlNormalizer.normalizeImageUrl(imageUrl) 
        : null;

    if (normalizedUrl == _currentImageUrl) {
      return; // Ya está cargada
    }

    // Si hay una imagen actual, guardarla como anterior
    if (_currentImageUrl != null && _currentImageProvider != null) {
      setState(() {
        _previousImageUrl = _currentImageUrl;
        _previousImageProvider = _currentImageProvider;
        _isImageReady = false;
      });
    }

    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      setState(() {
        _currentImageUrl = null;
        _currentImageProvider = null;
        _isImageReady = true;
      });
      return;
    }

    // Precargar imagen antes de mostrarla
    try {
      final imageProvider = CachedNetworkImageProvider(
        normalizedUrl,
        cacheManager: AlbumArtCacheManager.instance, // ✅ Cache manager con persistencia de 90 días
      );
      
      // Precargar la imagen
      await precacheImage(imageProvider, context);
      
      if (mounted && normalizedUrl == UrlNormalizer.normalizeImageUrl(widget.imageUrl)) {
        setState(() {
          _currentImageUrl = normalizedUrl;
          _currentImageProvider = imageProvider;
          _isImageReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentImageUrl = null;
          _currentImageProvider = null;
          _isImageReady = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        child: _buildImageWidget(),
      ),
    );
  }

  Widget _buildImageWidget() {
    // Si hay imagen actual lista, mostrarla
    if (_isImageReady && _currentImageProvider != null) {
      return _buildImageContainer(_currentImageProvider!, _currentImageUrl!);
    }
    
    // Si hay imagen anterior, mantenerla mientras carga la nueva
    if (_previousImageProvider != null) {
      return _buildImageContainer(_previousImageProvider!, _previousImageUrl!);
    }
    
    // Fallback: gradiente suave
    return _buildGradientPlaceholder();
  }

  Widget _buildImageContainer(ImageProvider imageProvider, String imageUrl) {
    return RepaintBoundary(
      child: CachedNetworkImage(
        key: ValueKey(imageUrl),
        imageUrl: imageUrl,
        cacheManager: AlbumArtCacheManager.instance, // ✅ Cache manager con persistencia de 90 días
        fit: widget.fit,
        fadeInDuration: Duration.zero, // Ya precargada
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: true, // Mantener imagen anterior mientras carga
        filterQuality: FilterQuality.medium,
        errorWidget: (context, url, error) => _buildGradientPlaceholder(),
      ),
    );
  }

  Widget _buildGradientPlaceholder() {
    return Container(
      key: const ValueKey('gradient_placeholder'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
            NeumorphismTheme.coffeeDark.withValues(alpha: 0.4),
          ],
        ),
      ),
    );
  }
}

