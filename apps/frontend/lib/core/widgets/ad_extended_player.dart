import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../utils/url_normalizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../features/ads/models/audio_ad_model.dart';
import '../../features/ads/widgets/ads_skip_button.dart';
import '../../features/ads/widgets/ad_duration_counter.dart';

/// Widget para mostrar anuncios en el reproductor extendido
/// Similar a _StaticPlayerUI pero adaptado para anuncios
class AdExtendedPlayer extends ConsumerStatefulWidget {
  final AudioAd ad;
  final bool isPlaying;

  const AdExtendedPlayer({
    super.key,
    required this.ad,
    required this.isPlaying,
  });

  @override
  ConsumerState<AdExtendedPlayer> createState() => _AdExtendedPlayerState();
}

class _AdExtendedPlayerState extends ConsumerState<AdExtendedPlayer> {
  // Estilos para el anuncio
  static final TextStyle _AdTitleStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static final TextStyle _AdvertiserStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.9),
    letterSpacing: -0.3,
  );

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    
    // ✅ FIX CRÍTICO: Verificar que realmente se esté reproduciendo un anuncio
    // Si el estado cambió y ya no hay anuncio, ocultar este widget inmediatamente
    if (!playbackState.isPlayingAd || playbackState.currentAd?.id != widget.ad.id) {
      // El anuncio terminó o cambió, ocultar este widget
      return const SizedBox.shrink();
    }
    
    final showSkipControl = widget.ad.isSkippable;
    final currentPosition = playbackState.currentPosition;
    // ✅ FIX: Usar duración del modelo AudioAd como fallback si totalDuration es cero
    // Esto asegura que la barra de progreso siempre tenga una duración válida
    final totalDuration = playbackState.totalDuration.inMilliseconds > 0 
        ? playbackState.totalDuration 
        : widget.ad.duration;
    
    double progress = 0.0;
    if (totalDuration.inMilliseconds > 0) {
      progress = (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    }
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Fondo con carátula del anuncio o color sólido
          SizedBox.expand(
            child: widget.ad.coverImageUrl != null && widget.ad.coverImageUrl!.isNotEmpty
                ? Builder(
                    builder: (context) {
                      // ✅ OPTIMIZACIÓN: Calcular tamaño de cache basado en el tamaño de pantalla
                      final screenSize = MediaQuery.of(context).size;
                      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
                      final maxScreenDimension = screenSize.width > screenSize.height 
                          ? screenSize.width 
                          : screenSize.height;
                      // Limitar a un máximo razonable para evitar uso excesivo de memoria
                      final maxCacheSize = (maxScreenDimension * devicePixelRatio * 1.2).round().clamp(0, 1200);
                      
                      return CachedNetworkImage(
                        imageUrl: UrlNormalizer.normalizeImageUrl(widget.ad.coverImageUrl) ?? widget.ad.coverImageUrl!,
                        fit: BoxFit.cover,
                        // ✅ FIX CRÍTICO: Agregar parámetros de cache para optimizar memoria
                        memCacheWidth: maxCacheSize,
                        memCacheHeight: maxCacheSize,
                        maxWidthDiskCache: maxCacheSize,
                        maxHeightDiskCache: maxCacheSize,
                        filterQuality: FilterQuality.medium,
                        errorWidget: (context, url, error) => Container(
                          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                        ),
                      );
                    },
                  )
                : Container(
                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                  ),
          ),
          
          // Blur overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),

          // Contenido
          SafeArea(
            bottom: true,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(top: 48, bottom: 12),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "ANUNCIO",
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Carátula del anuncio
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: MediaQuery.of(context).size.width * 0.85,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: widget.ad.coverImageUrl != null && widget.ad.coverImageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: UrlNormalizer.normalizeImageUrl(widget.ad.coverImageUrl) ?? widget.ad.coverImageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                      child: Icon(
                                        Icons.volume_up,
                                        color: Colors.white.withValues(alpha: 0.5),
                                        size: 64,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                      child: Icon(
                                        Icons.volume_up,
                                        color: Colors.white.withValues(alpha: 0.5),
                                        size: 64,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                    child: Icon(
                                      Icons.volume_up,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 64,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Información del anuncio
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Column(
                          children: [
                            // Título y Anunciante
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.ad.title,
                                        style: _AdTitleStyle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.ad.advertiserName,
                                        style: _AdvertiserStyle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Botón de skip o contador
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: showSkipControl
                                      ? AdsSkipButton(ad: widget.ad)
                                      : AdDurationCounter(ad: widget.ad),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Barra de progreso
                            Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: Slider(
                                    value: progress,
                                    onChanged: null, // No permitir seek durante anuncios
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        child: Text(
                                          _formatDuration(currentPosition),
                                          style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 50,
                                        child: Text(
                                          _formatDuration(totalDuration),
                                          style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Controles (deshabilitados durante anuncios excepto play/pause)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.shuffle,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 24,
                                  ),
                                  onPressed: null,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 42,
                                  ),
                                  onPressed: null,
                                ),
                                // Botón play/pause (BLOQUEADO durante anuncios - no se puede pausar)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final isPlaying = ref.watch(
                                      unifiedAudioProviderFixed.select((state) => state.isPlaying),
                                    );
                                    final isPlayingAd = ref.watch(
                                      unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
                                    );
                                    return IconButton(
                                      icon: Icon(
                                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                        color: Colors.white.withValues(alpha: isPlayingAd ? 0.5 : 1.0),
                                        size: 64,
                                      ),
                                      onPressed: isPlayingAd ? null : () {
                                        ref.read(unifiedAudioProviderFixed.notifier).togglePlayPause();
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 42,
                                  ),
                                  onPressed: null,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.repeat,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 24,
                                  ),
                                  onPressed: null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

