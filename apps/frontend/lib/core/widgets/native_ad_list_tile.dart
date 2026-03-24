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

  const NativeAdListTile({
    super.key,
    this.adType = NativeAdType.large, // Por defecto es grande (con imagen)
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
    _loadAd();
  }

  void _loadAd() {
    // 🛡️ SEGURIDAD PREMIUM
    final user = ref.read(authStateProvider).user;
    if (user != null && user.isPremium) return;

    final adUnitId = AdMobService.nativeAdUnitId;
    if (adUnitId == null) return;

    // 🎨 DYNAMIC THEME COLORS
    final isDark = NeumorphismTheme.isDark;
    final backgroundColor = NeumorphismTheme.background;
    final surfaceColor = NeumorphismTheme.surface;
    final accentColor = NeumorphismTheme.accent;
    final textPrimaryColor = NeumorphismTheme.textPrimary;
    final textSecondaryColor = NeumorphismTheme.textSecondary;

    String colorToHex(Color color) {
      return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
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
    // 🚀 Escuchar cambios de tema para recargar el anuncio
    ref.watch(themeProvider);
    final currentIsDark = NeumorphismTheme.isDark;
    
    if (_lastIsDark != null && _lastIsDark != currentIsDark) {
      _lastIsDark = currentIsDark;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nativeAd?.dispose();
          setState(() {
            _isLoaded = false;
            _nativeAd = null;
          });
          _loadAd();
        }
      });
    }
    _lastIsDark ??= currentIsDark;

    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final surfaceColor = NeumorphismTheme.surface;
    
    // 📏 Altura dinámica según el tipo de anuncio
    final double adHeight = widget.adType == NativeAdType.small ? 220 : 480;

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
