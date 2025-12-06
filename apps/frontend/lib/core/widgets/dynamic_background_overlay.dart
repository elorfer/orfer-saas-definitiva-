import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../utils/url_normalizer.dart';
import '../theme/neumorphism_theme.dart';

/// Widget que extrae colores dominantes de la portada y crea un overlay dinámico
class DynamicBackgroundOverlay extends StatefulWidget {
  final String? coverArtUrl;
  final Widget child;

  const DynamicBackgroundOverlay({
    super.key,
    required this.coverArtUrl,
    required this.child,
  });

  @override
  State<DynamicBackgroundOverlay> createState() => _DynamicBackgroundOverlayState();
}

class _DynamicBackgroundOverlayState extends State<DynamicBackgroundOverlay> {
  Color? _dominantColor;
  Color? _vibrantColor;
  Color? _mutedColor;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(DynamicBackgroundOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverArtUrl != widget.coverArtUrl) {
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    if (widget.coverArtUrl == null || widget.coverArtUrl!.isEmpty) {
      setState(() {
        _dominantColor = null;
        _vibrantColor = null;
        _mutedColor = null;
      });
      return;
    }

    try {
      final normalizedUrl = UrlNormalizer.normalizeImageUrl(widget.coverArtUrl);
      if (normalizedUrl == null || normalizedUrl.isEmpty) {
        setState(() {
          _dominantColor = null;
          _vibrantColor = null;
          _mutedColor = null;
        });
        return;
      }

      // Extraer paleta de colores directamente del ImageProvider
      final imageProvider = CachedNetworkImageProvider(normalizedUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 5,
      );

      if (mounted) {
        setState(() {
          _dominantColor = paletteGenerator.dominantColor?.color;
          _vibrantColor = paletteGenerator.vibrantColor?.color;
          _mutedColor = paletteGenerator.mutedColor?.color;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dominantColor = null;
          _vibrantColor = null;
          _mutedColor = null;
        });
      }
    }
  }

  List<Color> _getGradientColors() {
    // Si tenemos colores extraídos, usarlos
    if (_vibrantColor != null && _mutedColor != null) {
      return [
        _vibrantColor!.withValues(alpha: 0.4),
        _mutedColor!.withValues(alpha: 0.6),
      ];
    }
    
    if (_dominantColor != null) {
      // Crear variaciones del color dominante
      final hsl = HSLColor.fromColor(_dominantColor!);
      final lighter = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
      final darker = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
      
      return [
        lighter.withValues(alpha: 0.3),
        darker.withValues(alpha: 0.5),
      ];
    }

    // Fallback: usar colores del tema
    return [
      NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
      NeumorphismTheme.coffeeDark.withValues(alpha: 0.5),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _getGradientColors(),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

