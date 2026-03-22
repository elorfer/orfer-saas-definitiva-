import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';
import '../../../core/utils/logger.dart';

/// 🎯 ADMOB SERVICE - Gestión de anuncios de Google
/// 
/// Centraliza la configuración de IDs (Test vs Prod) y la inicialización.
class AdMobService {
  
  /// 🚀 MODO DE PRUEBA (Para desarrollo)
  static const bool isTestMode = true; // ACTIVADO PARA PROBAR ANUNCIO NATIVO

  /// IDs de prueba de Google
  static const String _androidBannerTestId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestId = 'ca-app-pub-3940256099942544/2934735716';
  
  /// IDs Reales (Copia aquí tus IDs de la consola de AdMob)
  static const String _androidBannerProdId = 'ca-app-pub-2929540794612262/1236347270'; 
  static const String _iosBannerProdId = 'AQUÍ_TU_ID_REAL_IOS';

  static const String _androidNativeTestId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _iosNativeTestId = 'ca-app-pub-3940256099942544/3986624511';

  /// Retorna el ID de Banner adecuado según plataforma y modo
  static String? get bannerAdUnitId {
    if (isTestMode) {
      return Platform.isAndroid ? _androidBannerTestId : _iosBannerTestId;
    }
    
    // MODO PRODUCCIÓN
    if (Platform.isAndroid) return _androidBannerProdId;
    if (Platform.isIOS) return _iosBannerProdId;
    return null;
  }

  /// 🚀 POOL DE ANUNCIOS: Almacena anuncios precargados para visualización instantánea
  static BannerAd? _preloadedBanner;
  static bool _isLoadingPreload = false;

  /// Retorna el ID de Anuncio Nativo adecuado
  static String? get nativeAdUnitId {
    if (isTestMode) {
      return Platform.isAndroid ? _androidNativeTestId : _iosNativeTestId;
    }
    // TODO: Añadir IDs nativos de producción cuando los crees
    return null;
  }

  /// Calcula el tamaño adaptativo para banners según el ancho de pantalla
  static Future<AdSize?> getAdaptiveSize(double width, Orientation orientation) async {
    return AdSize.getAnchoredAdaptiveBannerAdSize(orientation, width.toInt());
  }

  /// Inicializa el SDK de AdMob y lanza la primera precarga
  static Future<void> initialize() async {
    try {
      final status = await MobileAds.instance.initialize();
      AppLogger.info('[AdMobService] SDK Inicializado correctamente');
      
      // Lanzar primera precarga (silenciosa)
      preloadBanner();
      
      // Log de estado de adaptadores
      status.adapterStatuses.forEach((key, value) {
        AppLogger.debug('[AdMobService] Adaptador: $key, Estado: ${value.state}');
      });
    } catch (e) {
      AppLogger.error('[AdMobService] Error crítico al inicializar AdMob: $e');
    }
  }

  /// ⚡ PRE-CARGA PRO: Descarga un anuncio en background para uso futuro
  static void preloadBanner() {
    if (_preloadedBanner != null || _isLoadingPreload) return;

    final adUnitId = bannerAdUnitId;
    if (adUnitId == null) return;

    _isLoadingPreload = true;
    
    _preloadedBanner = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AppLogger.info('[AdMobService] ✅ Banner precargado y listo en el pool');
          _isLoadingPreload = false;
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.warning('[AdMobService] ❌ Falló precarga: ${error.message}');
          ad.dispose();
          _preloadedBanner = null;
          _isLoadingPreload = false;
          // Reintentar en 30 segundos si falló
          Future.delayed(const Duration(seconds: 30), () => preloadBanner());
        },
      ),
    )..load();
  }

  /// 🎯 CONSUMIR BANNER: Extrae el anuncio del pool si está listo
  static BannerAd? takePreloadedBanner() {
    if (_preloadedBanner == null) {
      preloadBanner(); // Intentar cargar uno para la próxima vez
      return null;
    }
    
    final ad = _preloadedBanner;
    _preloadedBanner = null;
    
    // Inmediatamente empezar a cargar el siguiente para mantener el pool lleno
    Future.delayed(const Duration(seconds: 2), () => preloadBanner());
    
    return ad;
  }
}
