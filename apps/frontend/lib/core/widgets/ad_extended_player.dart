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

/// Custom Track Shape que permite diferentes alturas para track activo e inactivo
class _CustomSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _CustomSliderTrackShape({
    this.inactiveTrackHeight = 3.0,
    this.activeTrackHeight = 2.0,
  });

  final double inactiveTrackHeight;
  final double activeTrackHeight;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    assert(sliderTheme.disabledActiveTrackColor != null);
    assert(sliderTheme.disabledInactiveTrackColor != null);
    assert(sliderTheme.activeTrackColor != null);
    assert(sliderTheme.inactiveTrackColor != null);
    assert(sliderTheme.thumbShape != null);

    // Usar colores habilitados o deshabilitados
    final Color activeColor = sliderTheme.activeTrackColor!;
    final Color inactiveColor = sliderTheme.inactiveTrackColor!;

    final Paint activePaint = Paint()..color = activeColor;
    final Paint inactivePaint = Paint()..color = inactiveColor;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Rect leftTrackSegment = Rect.fromLTRB(
      trackRect.left,
      trackRect.top + (trackRect.height - activeTrackHeight) / 2,
      thumbCenter.dx,
      trackRect.top + (trackRect.height - activeTrackHeight) / 2 + activeTrackHeight,
    );
    if (!leftTrackSegment.isEmpty) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(leftTrackSegment, const Radius.circular(1.0)),
        activePaint,
      );
    }

    final Rect rightTrackSegment = Rect.fromLTRB(
      thumbCenter.dx,
      trackRect.top + (trackRect.height - inactiveTrackHeight) / 2,
      trackRect.right,
      trackRect.top + (trackRect.height - inactiveTrackHeight) / 2 + inactiveTrackHeight,
    );
    if (!rightTrackSegment.isEmpty) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(rightTrackSegment, const Radius.circular(1.0)),
        inactivePaint,
      );
    }
  }

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    // Usar la altura máxima (inactiva) para el rectángulo preferido
    final double trackHeight = inactiveTrackHeight;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

/// ⚡ OPTIMIZACIÓN: Widget separado para la barra de progreso del anuncio extendido
/// Solo se reconstruye cuando cambia currentPosition o totalDuration
class _AdExtendedProgressSection extends ConsumerWidget {
  final AudioAd ad;
  
  const _AdExtendedProgressSection({required this.ad});
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚡ OPTIMIZACIÓN: Solo escuchar los valores necesarios
    final currentPosition = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentPosition),
    );
    final totalDuration = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.totalDuration),
    );
    
    // Usar duración del modelo como fallback
    final effectiveDuration = totalDuration.inMilliseconds > 0 
        ? totalDuration 
        : ad.duration;
    
    double progress = 0.0;
    if (effectiveDuration.inMilliseconds > 0) {
      progress = (currentPosition.inMilliseconds / effectiveDuration.inMilliseconds).clamp(0.0, 1.0);
    }
    
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4, // ✅ Altura base (usada por el track inactivo)
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: Colors.white.withValues(alpha: 0.7), // ✅ Opacidad reducida
            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            trackShape: const _CustomSliderTrackShape(
              activeTrackHeight: 3.0, // ✅ Barra activa más gruesa
              inactiveTrackHeight: 4.0, // ✅ Barra inactiva más gruesa
            ),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: progress,
            onChanged: null, // No permitir seek durante anuncios
          ),
        ),
        Padding(
          padding: EdgeInsets.zero,
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
                  _formatDuration(effectiveDuration),
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
    );
  }
}

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
  static final TextStyle _adTitleStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static final TextStyle _advertiserStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.9),
    letterSpacing: -0.3,
  );

  @override
  Widget build(BuildContext context) {
    // ⚡ OPTIMIZACIÓN: Solo escuchar los campos necesarios
    final isPlayingAd = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
    );
    final currentAdId = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentAd?.id),
    );
    
    // ✅ FIX CRÍTICO: Verificar que realmente se esté reproduciendo un anuncio
    if (!isPlayingAd || currentAdId != widget.ad.id) {
      return const SizedBox.shrink();
    }
    
    final showSkipControl = widget.ad.isSkippable;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ✅ FIX: Fondo con color sólido profesional (sin imagen de carátula)
          // Eliminado completamente cualquier referencia a imágenes de fondo
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NeumorphismTheme.coffeeMedium.withValues(alpha: 0.85),
                    NeumorphismTheme.coffeeDark.withValues(alpha: 0.95),
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
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            child: widget.ad.coverImageUrl != null && widget.ad.coverImageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: UrlNormalizer.normalizeImageUrl(widget.ad.coverImageUrl) ?? widget.ad.coverImageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                      child: const Icon(
                                        Icons.volume_up,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                      child: const Icon(
                                        Icons.volume_up,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
                                    child: const Icon(
                                      Icons.volume_up,
                                      color: Colors.white,
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
                                        style: _adTitleStyle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.ad.advertiserName,
                                        style: _advertiserStyle,
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
                            
                            // ⚡ Widget optimizado: solo se reconstruye cuando cambia el progreso
                            RepaintBoundary(
                              child: _AdExtendedProgressSection(ad: widget.ad),
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
}

