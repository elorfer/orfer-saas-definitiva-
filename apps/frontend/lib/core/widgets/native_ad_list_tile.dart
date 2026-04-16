import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/ads/services/admob_service.dart';
import '../../core/utils/logger.dart';
import '../../core/providers/auth_provider.dart';
import 'package:vintage_music_app/core/providers/theme_provider.dart';
import 'package:vintage_music_app/core/theme/neumorphism_theme.dart';

enum NativeAdType {
  large, // Default (square-ish with media)
  small, // List tile size (no media)
}

/// 🎨 NATIVE AD LIST TILE - Anuncio que parece parte de la app
/// 
/// Utiliza la NativeAdFactory registrada en el lado nativo ("listTile").
class NativeAdListTile extends ConsumerStatefulWidget {
  final NativeAdType adType;
  final String placement;

  const NativeAdListTile({
    super.key,
    this.adType = NativeAdType.large, // Por defecto es grande (con imagen)
    this.placement = 'home', // 'home' o 'search'
  });

  @override
  ConsumerState<NativeAdListTile> createState() => _NativeAdListTileState();
}

class _NativeAdListTileState extends ConsumerState<NativeAdListTile> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool? _lastIsDark;

  @override
  void initState() {
    super.initState();
    _lastIsDark = NeumorphismTheme.isDark;
    // 🚀 ANR FIX: Defer ad loading to avoid blocking main thread during startup
    // google_mobile_ads uses WebView internally which can block the UI thread
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          // 🚀 ANR FIX (ESTABILIDAD ELITE): Solo cargar si la app sigue en primer plano
          final lifecycle = WidgetsBinding.instance.lifecycleState;
          if (mounted && lifecycle == AppLifecycleState.resumed) {
            _loadAd();
          }
        });
      }
    });
  }

  void _loadAd() {
    // 🛡️ SEGURIDAD PREMIUM
    final user = ref.read(authStateProvider).user;
    if (user != null && user.isPremium) return;

    final adUnitId = AdMobService.nativeAdUnitId(placement: widget.placement);
    if (adUnitId == null) return;

    // 🎨 DYNAMIC THEME COLORS
    final isDark = NeumorphismTheme.isDark;
    final backgroundColor = NeumorphismTheme.background;
    final surfaceColor = NeumorphismTheme.surface;
    final accentColor = NeumorphismTheme.accent;
    final textPrimaryColor = NeumorphismTheme.textPrimary;
    final textSecondaryColor = NeumorphismTheme.textSecondary;

    String colorToHex(Color color) {
      return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    }

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(
          startMuted: true,
          customControlsRequested: true,
          clickToExpandRequested: true,
        ),
      ),
      customOptions: {
        'isDark': isDark,
        'adType': widget.adType.name, // 'large' o 'small'
        'backgroundColor': colorToHex(backgroundColor),
        'surfaceColor': colorToHex(surfaceColor),
        'accentColor': colorToHex(accentColor),
        'textPrimaryColor': colorToHex(textPrimaryColor),
        'textSecondaryColor': colorToHex(textSecondaryColor),
      },
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          AppLogger.info('[NativeAd] ✅ Anuncio nativo cargado');
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.warning('[NativeAd] ❌ Error: ${error.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌚 FIXED DARK MODE: No longer watching theme changes. The ad loads once in Dark Mode and stays there.
    if (!_isLoaded && _nativeAd == null) {
       // Si el ad es null y no est cargado, podra ser por una rotacin o reconstruccin,
       // el initState se encargar de disparar el _loadAd inicial.
    }
    
    final currentIsDark = true; // Forzado
    _lastIsDark = true;

    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final surfaceColor = NeumorphismTheme.surface;
    
    // 📏 Altura dinámica según el tipo de anuncio (Margen extra para evitar errores de recorte "clipping" del validador de AdMob)
    final double adHeight = widget.adType == NativeAdType.small ? 200 : 380;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: adHeight,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: NeumorphismTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
