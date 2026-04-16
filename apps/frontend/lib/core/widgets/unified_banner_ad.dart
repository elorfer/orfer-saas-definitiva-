import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart'; // 🚀 ADDED: Para efecto profesional
import '../theme/neumorphism_theme.dart';
import '../../features/ads/services/admob_service.dart';
import '../../core/providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/logger.dart';

/// 🎨 UNIFIED BANNER AD - Widget premium para anuncios
/// 
/// Características PRO (v2.0):
/// - Carga Proactiva: Inicia la carga en initState (sin esperar a visibilidad).
/// - Shimmer Premium: Efecto de esqueleto animado mientras carga.
/// - Estabilidad de Layout: Reserva espacio exacto para evitar saltos.
class UnifiedBannerAd extends ConsumerStatefulWidget {
  final AdSize adSize;
  final bool useAdaptive;
  
  const UnifiedBannerAd({
    super.key, 
    this.adSize = AdSize.banner,
    this.useAdaptive = false,
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
    // 🚀 PROFESIONAL: Iniciar carga inmediatamente
    // 🚀 ANR FIX: Defer ad loading to avoid main thread contention
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        // 🚀 ANR FIX (ESTABILIDAD ELITE): Solo cargar si la app sigue en primer plano
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (mounted && lifecycle == AppLifecycleState.resumed) {
          _loadAd();
        }
      });
    });
  }

  Future<void> _loadAd() async {
    if (!mounted || _isRequesting || _isLoaded) return;

    // 🛡️ SEGURIDAD PREMIUM: No cargar para usuarios premium
    final user = ref.read(authStateProvider).user;
    if (user != null && user.isPremium) return;

    setState(() {
      _currentAdSize = widget.adSize;
    });

    // 🚀 NIVEL PRO: Intentar obtener anuncio del Pool (Instantáneo)
    // Solo si el tamaño solicitado es el estándar (que es el que precargamos)
    if (widget.adSize == AdSize.banner && !widget.useAdaptive) {
      final pooledAd = AdMobService.takePreloadedBanner();
      if (pooledAd != null) {
        AppLogger.info('[UnifiedBannerAd] ⚡ Usando anuncio instantáneo del Pool');
        setState(() {
          _bannerAd = pooledAd;
          _isLoaded = true;
          _isRequesting = false;
        });
        return;
      }
    }

    setState(() => _isRequesting = true);

    final adUnitId = AdMobService.bannerAdUnitId;
    if (adUnitId == null) {
      setState(() => _isRequesting = false);
      return;
    }

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
          AppLogger.info('[UnifiedBannerAd] ✅ Anuncio cargado correctamente');
          setState(() {
            _isLoaded = true;
            _isError = false;
            _isRequesting = false;
            _retryCount = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.warning('[UnifiedBannerAd] ❌ Falló la carga: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isError = true;
              _isLoaded = false;
              _isRequesting = false;
            });
            // Reintento exponencial
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

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          minHeight: _currentAdSize?.height.toDouble() ?? widget.adSize.height.toDouble() + 40,
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
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_outline_rounded, 
                    size: 12, 
                    color: NeumorphismTheme.textLight.withValues(alpha: 0.4)
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CONTENIDO SUGERIDO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: NeumorphismTheme.textLight.withValues(alpha: 0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.star_outline_rounded, 
                    size: 12, 
                    color: NeumorphismTheme.textLight.withValues(alpha: 0.4)
                  ),
                ],
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
              _buildErrorState()
            else
              _buildShimmerPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    final double width = _currentAdSize?.width.toDouble() ?? widget.adSize.width.toDouble();
    final double height = _currentAdSize?.height.toDouble() ?? widget.adSize.height.toDouble();
    
    return Shimmer.fromColors(
      baseColor: NeumorphismTheme.isDark 
          ? Colors.white.withValues(alpha: 0.05) 
          : Colors.grey[300]!,
      highlightColor: NeumorphismTheme.isDark 
          ? Colors.white.withValues(alpha: 0.1) 
          : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: NeumorphismTheme.textLight.withValues(alpha: 0.3)),
          const SizedBox(width: 8),
          Text(
            'No se pudo cargar la sugerencia',
            style: TextStyle(fontSize: 10, color: NeumorphismTheme.textLight.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  String get adUnitId => AdMobService.bannerAdUnitId ?? 'default';
}
