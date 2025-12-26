import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/services/player_navigation_service.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/services/http_cache_service.dart';
import '../models/audio_ad_model.dart';
import 'ads_skip_button.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ⚡ OPTIMIZACIÓN: Widget separado para la barra de progreso del anuncio
/// Solo se reconstruye cuando cambia currentPosition o totalDuration
/// ✅ FIX: Animación suave para evitar saltos visuales durante la transición
class _AdProgressBar extends ConsumerStatefulWidget {
  final AudioAd ad;
  
  const _AdProgressBar({required this.ad});
  
  @override
  ConsumerState<_AdProgressBar> createState() => _AdProgressBarState();
}

class _AdProgressBarState extends ConsumerState<_AdProgressBar> 
    with SingleTickerProviderStateMixin {
  double _animatedProgress = 0.0;
  String? _lastAdId;
  late AnimationController _enterController;
  Duration? _lastPosition;
  DateTime? _lastUpdateTime;
  
  @override
  void initState() {
    super.initState();
    // ✅ FIX: Animación de entrada suave y segura para la barra
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Reducido para entrada más rápida
    );
    _enterController.forward();
  }
  
  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // ⚡ OPTIMIZACIÓN: Solo escuchar los valores necesarios
    final currentPosition = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentPosition),
    );
    final totalDuration = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.totalDuration),
    );
    
    // ✅ FIX: Resetear progreso animado cuando cambia el anuncio y reiniciar animación de entrada
    if (widget.ad.id != _lastAdId) {
      _lastAdId = widget.ad.id;
      _animatedProgress = 0.0;
      _lastPosition = null;
      _lastUpdateTime = null;
      _enterController.reset();
      _enterController.forward(); // Reiniciar animación de entrada para nuevo anuncio
    }
    
    // Usar duración del modelo como fallback
    final effectiveDuration = totalDuration.inMilliseconds > 0 
        ? totalDuration 
        : widget.ad.duration;
    
    double targetProgress = 0.0;
    if (effectiveDuration.inMilliseconds > 0) {
      targetProgress = (currentPosition.inMilliseconds / effectiveDuration.inMilliseconds).clamp(0.0, 1.0);
    }
    
    // ✅ FIX CRÍTICO: Detectar si la posición está avanzando constantemente
    // Si la posición cambia rápidamente, usar el valor directamente sin animación para mantener fluidez
    final now = DateTime.now();
    final isPositionAdvancing = _lastPosition != null && 
        currentPosition > _lastPosition! &&
        (_lastUpdateTime == null || now.difference(_lastUpdateTime!).inMilliseconds < 200);
    
    // ✅ FIX: Cuando se salta a un anuncio, la posición puede empezar en 0 o saltar
    // Si el cambio es grande (salto), actualizar directamente sin animación para evitar "ruido"
    final positionDelta = _lastPosition != null 
        ? (currentPosition - _lastPosition!).inMilliseconds.abs()
        : 0;
    final isLargeJump = positionDelta > 1000; // Si el cambio es > 1 segundo, es un salto
    
    // ✅ FIX CRÍTICO: Actualizar directamente si está avanzando activamente O si es un salto grande
    if (isPositionAdvancing || isLargeJump) {
      _animatedProgress = targetProgress; // ✅ Actualizar directamente cuando está avanzando o saltando
    }
    
    _lastPosition = currentPosition;
    _lastUpdateTime = now;
    
    // ✅ FIX: Si la posición está avanzando activamente o hay un salto, usar animación mínima
    // para evitar el efecto de "ruido" o "detención"
    final animationDuration = (isPositionAdvancing || isLargeJump)
        ? const Duration(milliseconds: 50) // ✅ Animación muy rápida cuando avanza o salta
        : const Duration(milliseconds: 150); // ✅ Animación normal cuando está estático
    
    // ✅ FIX: Animar suavemente hacia el progreso objetivo con animación de entrada
    // Removido ValueKey para evitar reconstrucciones constantes que causan "ruido"
    return SizedBox(
      height: 2, // ✅ Barra más delgada
      child: AnimatedBuilder(
        animation: _enterController,
        builder: (context, child) {
          // ✅ FIX: Animación de entrada suave (fade in + scale)
          final enterOpacity = Curves.easeOutCubic.transform(_enterController.value);
          final enterScale = Tween<double>(begin: 0.95, end: 1.0)
              .animate(CurvedAnimation(
                parent: _enterController,
                curve: Curves.easeOutCubic,
              ))
              .value;
          
          return Opacity(
            opacity: enterOpacity,
            child: Transform.scale(
              scaleX: enterScale, // Escalar solo horizontalmente para efecto de "llenado"
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                // ✅ FIX CRÍTICO: Removido ValueKey(targetProgress) para evitar reconstrucciones constantes
                // Esto previene el "ruido" visual causado por reconstrucciones innecesarias
                tween: Tween<double>(begin: _animatedProgress, end: targetProgress),
                duration: animationDuration,
                curve: (isPositionAdvancing || isLargeJump) 
                    ? Curves.linear 
                    : Curves.easeOutCubic, // ✅ Curva lineal cuando avanza/salta para suavidad constante
                onEnd: () {
                  // ✅ Actualizar _animatedProgress al final de la animación para mantener sincronización
                  if (mounted) {
                    setState(() {
                      _animatedProgress = targetProgress;
                    });
                  }
                },
                builder: (context, progress, child) {
                  return LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
                    borderRadius: const BorderRadius.all(Radius.circular(1.0)), // ✅ Ajustado para barra más delgada
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ⚡ OPTIMIZACIÓN: Widget separado para el contador/botón de skip
/// Solo se reconstruye cuando cambia el estado del anuncio
class _AdSkipOrCounter extends ConsumerWidget {
  final AudioAd ad;
  
  const _AdSkipOrCounter({required this.ad});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚡ OPTIMIZACIÓN: Solo escuchar valores necesarios para el contador
    final currentPosition = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentPosition),
    );
    final totalDuration = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.totalDuration),
    );
    
    if (ad.isSkippable) {
      return AdsSkipButton(ad: ad);
    }
    
    // Calcular tiempo restante para anuncios no saltables
    final effectiveDuration = totalDuration.inMilliseconds > 0 
        ? totalDuration 
        : ad.duration;
    final remainingMs = (effectiveDuration.inMilliseconds - currentPosition.inMilliseconds).clamp(0, effectiveDuration.inMilliseconds);
    final remaining = Duration(milliseconds: remainingMs);
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        '-$minutes:${seconds.toString().padLeft(2, '0')}',
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: NeumorphismTheme.textSecondary,
        ),
      ),
    );
  }
}

/// Mini reproductor de anuncios optimizado
/// Se muestra cuando isPlayingAd es true
class AdsMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;

  const AdsMiniPlayer({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚡ OPTIMIZACIÓN: Solo escuchar los campos necesarios
    final ad = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentAd),
    );
    final isPlayingAd = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
    );
    
    // Si no hay anuncio o no se está reproduciendo, no mostrar nada
    if (ad == null || !isPlayingAd) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap ?? () {
        // ✅ MEJOR PRÁCTICA: Usar servicio centralizado para navegación
        PlayerNavigationService.openFullPlayer(
          context: context,
          ref: ref,
        );
      },
      child: Container(
      height: 72, // ✅ FIX: Altura fija igual a FinalMiniPlayer
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // ✅ FIX: Padding igual a FinalMiniPlayer
      decoration: BoxDecoration(
        color: NeumorphismTheme.background,
        borderRadius: const BorderRadius.all(Radius.circular(32)),
        border: Border.all(
          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ FIX: Mantener min para evitar overflow
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // ✅ FIX: Centrar verticalmente el Row
            children: [
              // Carátula del anuncio
              _buildAdCover(ad),
              
              const SizedBox(width: 12),
              
              // Información del anuncio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center, // ✅ FIX: Centrar verticalmente igual que FinalMiniPlayer
                  children: [
                    // Badge "ANUNCIO" - más compacto para igualar altura con canción
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                      ),
                      child: Text(
                        'ANUNCIO',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: NeumorphismTheme.coffeeDark,
                          letterSpacing: 0.3,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1), // ✅ FIX: Espacio igual a FinalMiniPlayer entre título y artista
                    // Nombre del anunciante - mismo estilo que título de canción
                    Text(
                      ad.advertiserName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: NeumorphismTheme.textPrimary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // ⚡ Widget optimizado: solo se reconstruye cuando cambia el estado del skip
              RepaintBoundary(
                child: _AdSkipOrCounter(ad: ad),
              ),
            ],
          ),
          
          const SizedBox(height: 8), // ✅ FIX: Espacio igual a FinalMiniPlayer
          
          // ⚡ Widget optimizado: solo se reconstruye cuando cambia la posición
          RepaintBoundary(
            child: _AdProgressBar(ad: ad),
          ),
        ],
      ),
      ),
    );
  }

  /// Construir carátula del anuncio
  /// ✅ FIX: Tamaño igual a FinalMiniPlayer (40x40 circular)
  Widget _buildAdCover(AudioAd ad) {
    if (ad.coverImageUrl != null && ad.coverImageUrl!.isNotEmpty) {
      // ✅ FIX: Normalizar URL de imagen para evitar problemas de duplicación
      final normalizedUrl = UrlNormalizer.normalizeImageUrl(ad.coverImageUrl);
      if (normalizedUrl != null) {
        return RepaintBoundary(
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: NeumorphismTheme.coffeeMedium,
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: normalizedUrl,
                cacheManager: AlbumArtCacheManager.instance, // ✅ Cache persistente 90 días
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero, // ✅ Sin animación
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              ),
            ),
          ),
        );
      }
    }
    return _buildPlaceholder();
  }

  /// Placeholder cuando no hay carátula
  /// ✅ FIX: Tamaño igual a FinalMiniPlayer (40x40 circular)
  Widget _buildPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: NeumorphismTheme.coffeeMedium,
      ),
      child: const Icon(
        Icons.volume_up,
        color: Colors.white,
        size: 20, // ✅ FIX: Tamaño igual al icono de música en FinalMiniPlayer
      ),
    );
  }
}
