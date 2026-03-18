import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart'; // 🚀 OPTIMIZATION: Carga por visibilidad
import '../theme/neumorphism_theme.dart';
import '../../features/ads/services/admob_service.dart';
import '../../core/providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/logger.dart';

/// 🎨 UNIFIED BANNER AD - Widget premium para anuncios
/// 
/// Características PRO:
/// - Banners Adaptativos: Se ajustan al ancho de pantalla.
/// - Carga por Visibilidad: Solo carga cuando el usuario lo ve.
/// - Reintentos Automáticos: Con backoff exponencial.
/// - Estabilidad de Layout: Reserva espacio para evitar saltos visuales.
class UnifiedBannerAd extends ConsumerStatefulWidget {
  final AdSize adSize;
  final bool useAdaptive;
  
  const UnifiedBannerAd({
    super.key, 
    this.adSize = AdSize.banner,
    this.useAdaptive = false, // Deshabilitado por petición del usuario
  });

  @override
  ConsumerState<UnifiedBannerAd> createState() => _UnifiedBannerAdState();
}

class _UnifiedBannerAdState extends ConsumerState<UnifiedBannerAd> 
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  AdSize? _currentAdSize;
  bool _isLoaded = false;
  bool _isError = false;
  bool _isRequesting = false;
  int _retryCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadAd() async {
    if (!mounted || _isRequesting || _isLoaded) return;

    // 🛡️ SEGURIDAD PREMIUM
    final user = ref.read(authStateProvider).user;
    if (user != null && user.isPremium) return;

    setState(() {
      _isRequesting = true;
      _currentAdSize = widget.adSize;
    });

    final adUnitId = AdMobService.bannerAdUnitId;
    if (adUnitId == null) return;

    // 🚀 OPTIMIZATION: Solo usar adaptativo si se solicita explícitamente
    if (widget.useAdaptive) {
      final width = MediaQuery.of(context).size.width - 64;
      final orientation = MediaQuery.of(context).orientation;
      final adaptiveSize = await AdMobService.getAdaptiveSize(width, orientation);
      if (adaptiveSize != null) {
        _currentAdSize = adaptiveSize;
      }
    }

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: _currentAdSize!,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
            _isError = false;
            _isRequesting = false;
            _retryCount = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isError = true;
              _isLoaded = false;
              _isRequesting = false;
            });
            if (_retryCount < 3) {
              _retryCount++;
              Future.delayed(Duration(seconds: _retryCount * 5), () => _loadAd());
            }
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(themeProvider);

    final user = ref.watch(authStateProvider).user;
    if (user != null && user.isPremium) return const SizedBox.shrink();

    return VisibilityDetector(
      key: Key('ad_visibility_${widget.key ?? adUnitId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1 && !_isLoaded && !_isRequesting) {
          _loadAd();
        }
      },
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            minHeight: _currentAdSize?.height.toDouble() ?? widget.adSize.height.toDouble(),
          ),
          decoration: BoxDecoration(
            color: NeumorphismTheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            boxShadow: NeumorphismTheme.softShadow,
            border: Border.all(
              color: NeumorphismTheme.isDark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.black.withValues(alpha: 0.03),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Publicidad Sugerida',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: NeumorphismTheme.textLight.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              if (_isLoaded && _bannerAd != null)
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: SizedBox(
                    width: _currentAdSize!.width.toDouble(),
                    height: _currentAdSize!.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                )
              else if (_isError)
                const SizedBox(
                  height: 50,
                  child: Center(child: Icon(Icons.info_outline, size: 20, color: Colors.grey)),
                )
              else
                SizedBox(
                  height: _currentAdSize?.height.toDouble() ?? widget.adSize.height.toDouble(),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get adUnitId => AdMobService.bannerAdUnitId ?? 'default';
}
