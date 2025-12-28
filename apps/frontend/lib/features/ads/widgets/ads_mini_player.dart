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
  // AnimationController eliminado
  Duration? _lastPosition;
  DateTime? _lastUpdateTime;
  
  @override
  void initState() {
    super.initState();
    // Animación de entrada eliminada para evitar flashes
  }
  
  @override
  void dispose() {
    // Controller eliminado
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
    
    // ✅ FIX: Resetear progreso animado cuando cambia el anuncio
    if (widget.ad.id != _lastAdId) {
      _lastAdId = widget.ad.id;
      _animatedProgress = 0.0;
      _lastPosition = null;
      _lastUpdateTime = null;
      // Se eliminó _enterController.reset()
    }
    
    // 🧠 HEURÍSTICA DE ESTADO OBSOLETO ("STALE STATE"): detection
    // Cuando se salta manualmente a un anuncio, el provider puede reportar brevemente
    // la duración/posición de la canción ANTERIOR antes de actualizarse.
    // Si la duración reportada difiere significativamente de la del anuncio, asumimos estado obsoleto.
    final durationDiff = (totalDuration - widget.ad.duration).inSeconds.abs();
    final isStateStale = durationDiff > 2; // Tolerancia de 2 segundos
    
    // Usar duración segura
    final effectiveDuration = isStateStale 
        ? widget.ad.duration 
        : (totalDuration.inMilliseconds > 0 ? totalDuration : widget.ad.duration);
        
    // Usar posición segura
    // Si el estado es obsoleto y la posición es mayor que la duración del anuncio,
    // es casi seguro que es la posición de la canción anterior -> Forzar 0.
    final effectivePosition = (isStateStale && currentPosition > widget.ad.duration)
        ? Duration.zero
        : currentPosition;
    
    double targetProgress = 0.0;
    if (effectiveDuration.inMilliseconds > 0) {
      targetProgress = (effectivePosition.inMilliseconds / effectiveDuration.inMilliseconds).clamp(0.0, 1.0);
    }
    
    // ✅ FIX CRÍTICO: Detectar si la posición está avanzando constantemente
    // Si la posición cambia rápidamente, usar el valor directamente sin animación para mantener fluidez
    final now = DateTime.now();
    final isPositionAdvancing = _lastPosition != null && 
        effectivePosition > _lastPosition! &&
        (_lastUpdateTime == null || now.difference(_lastUpdateTime!).inMilliseconds < 200);
    
    // ✅ FIX: Cuando se salta a un anuncio, la posición puede empezar en 0 o saltar
    // Si el cambio es grande (salto), actualizar directamente sin animación para evitar "ruido"
    final positionDelta = _lastPosition != null 
        ? (effectivePosition - _lastPosition!).inMilliseconds.abs()
        : 0;
    final isLargeJump = positionDelta > 1000; // Si el cambio es > 1 segundo, es un salto
    
    // ✅ FIX CRÍTICO: Actualizar directamente si está avanzando activamente O si es un salto grande
    if (isPositionAdvancing || isLargeJump) {
      _animatedProgress = targetProgress; // ✅ Actualizar directamente cuando está avanzando o saltando
    }
    
    _lastPosition = effectivePosition;
    _lastUpdateTime = now;
    
    // ✅ FIX: Si la posición está avanzando activamente o hay un salto, usar animación mínima
    // para evitar el efecto de "ruido" o "detención"
    final animationDuration = (isPositionAdvancing || isLargeJump)
        ? const Duration(milliseconds: 50) // ✅ Animación muy rápida cuando avanza o salta
        : const Duration(milliseconds: 150); // ✅ Animación normal cuando está estático
    
    // ✅ FIX: Animar suavemente hacia el progreso objetivo
    // Se eliminó la animación de entrada "fly-in" que causaba mala experiencia
    return SizedBox(
      height: 2, // ✅ Barra delgada igual al player normal
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: _animatedProgress, end: targetProgress),
        duration: animationDuration,
        curve: (isPositionAdvancing || isLargeJump) 
            ? Curves.linear 
            : Curves.easeOutCubic,
        onEnd: () {
          if (mounted) {
            setState(() {
              _animatedProgress = targetProgress;
            });
          }
        },
        builder: (context, progress, child) {
          return LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: NeumorphismTheme.textSecondary.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeMedium),
            minHeight: 2,
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
    
    // 🧠 HEURÍSTICA DE ESTADO OBSOLETO: Misma lógica que en barra de progreso
    final durationDiff = (totalDuration - ad.duration).inSeconds.abs();
    final isStateStale = durationDiff > 2;

    final effectiveDuration = isStateStale 
        ? ad.duration 
        : (totalDuration.inMilliseconds > 0 ? totalDuration : ad.duration);
        
    final effectivePosition = (isStateStale && currentPosition > ad.duration)
        ? Duration.zero
        : currentPosition;
        
    final remainingMs = (effectiveDuration.inMilliseconds - effectivePosition.inMilliseconds).clamp(0, effectiveDuration.inMilliseconds);
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
        PlayerNavigationService.openFullPlayer(context: context, ref: ref);
      },
      child: Container(
        height: 72, // ✅ FIX: Altura exacta igual a FinalMiniPlayer (Floating)
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // ✅ FIX: Margen idéntico
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // ✅ FIX: Padding idéntico
        decoration: BoxDecoration(
          color: NeumorphismTheme.background,
          borderRadius: const BorderRadius.all(Radius.circular(32)), // ✅ FIX: Radio idéntico
          border: Border.all(
            color: NeumorphismTheme.background,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4), // ✅ FIX: Sombra idéntica
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Contenido Principal (Row)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Carátula Circular (40x40)
                _buildAdCover(ad),
                
                const SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 1), // Micro-ajuste alineación óptica
                        child: Text(
                          ad.advertiserName, // Titulo (Anunciante) - Match Song Title hierarchy
                          style: GoogleFonts.inter(
                            color: NeumorphismTheme.textPrimary,
                            fontSize: 13, // Match Song Title size
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('AD', 
                              style: TextStyle(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold,
                                color: NeumorphismTheme.coffeeMedium,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ad.title, // Match Artist hierarchy
                              style: GoogleFonts.inter(
                                color: NeumorphismTheme.textSecondary,
                                fontSize: 11, // Match Artist size
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Botón de Skip o Contador (en lugar de PlayButton)
                _AdSkipOrCounter(ad: ad),
              ],
            ),

            const SizedBox(height: 8), // Gap for Progress Bar

            // Barra de Progreso ABAJO
            RepaintBoundary(
              child: _AdProgressBar(ad: ad),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir carátula del anuncio
  /// ✅ FIX: Tamaño igual a FinalMiniPlayer (40x40 Círculo)
  Widget _buildAdCover(AudioAd ad) {
    if (ad.coverImageUrl != null && ad.coverImageUrl!.isNotEmpty) {
      final normalizedUrl = UrlNormalizer.normalizeImageUrl(ad.coverImageUrl);
      if (normalizedUrl != null) {
        return RepaintBoundary(
          child: Hero(
            tag: 'ad_cover_${ad.id}', 
            child: Container(
              width: 40, // ✅ 40px (Match FinalMiniPlayer)
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle, // ✅ Circle (Match FinalMiniPlayer)
                color: NeumorphismTheme.coffeeMedium,
              ),
              child: ClipOval( // ✅ ClipOval (Match FinalMiniPlayer)
                child: CachedNetworkImage(
                  imageUrl: normalizedUrl,
                  cacheManager: AlbumArtCacheManager.instance,
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                  fadeInDuration: Duration.zero,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                ),
              ),
            ),
          ),
        );
      }
    }
    return _buildPlaceholder();
  }

  /// Placeholder cuando no hay carátula
  Widget _buildPlaceholder() {
    return Container(
      width: 40, // ✅ 40px
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle, // ✅ Circle
        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
      ),
      child: const Icon(
        Icons.campaign_rounded,
        color: NeumorphismTheme.coffeeMedium,
        size: 20, // ✅ Match FinalMiniPlayer icon size
      ),
    );
  }
}
