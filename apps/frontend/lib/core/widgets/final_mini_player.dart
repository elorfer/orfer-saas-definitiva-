import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../models/song_model.dart';
import '../services/player_navigation_service.dart';
import '../services/audio_service.dart';
import '../theme/neumorphism_theme.dart';
import 'mini_player_components.dart';

/// Mini reproductor final - Diseño neumórfico con funcionalidad perfecta
/// Usa directamente el provider unificado para máxima confiabilidad
class FinalMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const FinalMiniPlayer({
    super.key,
    this.onTap,
    this.onNext,
    this.onPrevious,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ ÚNICA FUENTE DE VERDAD: Usar el provider que siempre devuelve la canción que realmente se está reproduciendo
    final currentSong = ref.watch(realCurrentSongProvider);
    // ✅ FIX PARPADEO: Solo observar isPlayingAd, no todo el estado
    // Esto evita rebuilds cuando cambia isInsertingAd u otros campos irrelevantes
    final isPlayingAd = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
    );
    
    // ✅ FIX: Si hay un anuncio reproduciéndose, no mostrar el mini reproductor de canción
    // El AdsMiniPlayer se mostrará en su lugar
    if (isPlayingAd) {
      return const SizedBox.shrink();
    }
    
    // Si no hay canción, no mostrar nada
    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final song = currentSong;

    return Builder(
      builder: (builderContext) {
        // ✅ SOLUCIÓN B: Escuchar DIRECTAMENTE el latido del motor de audio (currentIndexStream)
        // Esto fuerza un rebuild del widget cuando cambia la canción, independientemente 
        // de si el Notifier decidió notificar o si está dormido.
        // Es la "Resurrección" del MiniPlayer.
        final audioService = ref.watch(audioServiceProvider);
        
        return StreamBuilder<int?>(
          stream: audioService.currentIndexStream,
          builder: (context, snapshot) {
            // ✅ SOLUCIÓN ROBUSTA: "Direct Queue Fetch"
            // Calcular la canción directamente usando el índice fresco del stream y la cola actual.
            // Esto evita depender de que el PlaybackNotifier actualice su estado 'currentSong' (que puede fallar o tardar).
            final currentIndex = snapshot.data;
            final playbackState = ref.watch(unifiedAudioProviderFixed);
            final queue = playbackState.currentQueue;
            
            Song? freshSong;
            
            if (currentIndex != null && currentIndex >= 0 && currentIndex < queue.length) {
              // 🎯 ALCANCE DIRECTO: Si el índice es válido, mostrar esa canción EXACTA de la cola.
              freshSong = queue[currentIndex];
            } else {
              // Fallback: Si no hay stream data, confiar en el provider
              freshSong = ref.watch(realCurrentSongProvider) ?? song;
            }

            return GestureDetector(
              onTap: onTap ?? () {
                // ✅ MEJOR PRÁCTICA: Usar servicio centralizado para navegación
                PlayerNavigationService.openFullPlayer(
                  context: builderContext,
                  ref: ref,
                );
              },
              child: Container(
                height: 72, // Altura ajustada para incluir la barra de progreso
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: NeumorphismTheme.background, // ⚡ Color original del tema
                    borderRadius: const BorderRadius.all(Radius.circular(32)), // Bordes redondeados
                    border: Border.all(
                      color: NeumorphismTheme.background, // Borde del mismo color para solidez
                      width: 2,
                    ),
                    boxShadow: [
                      // Sombra exterior suavizada para menor overdraw
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ⚡ OPTIMIZACIÓN: Contenido principal usando widgets separados
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center, // ✅ FIX: Centrar verticalmente para igualar con AdsMiniPlayer
                        children: [
                          // ⚡ Widget optimizado: solo se reconstruye si cambia coverArtUrl
                          // ✅ FIX PARPADEO: Pasar songId para Key única que previene parpadeos durante inserción de anuncios
                          MiniPlayerComponents.albumImage(freshSong.coverArtUrl, songId: freshSong.id),
                          
                          const SizedBox(width: 12),
                          
                          // ⚡ Widget optimizado: solo se reconstruye si cambia título o artista
                          Expanded(
                            child: MiniPlayerComponents.songInfo(
                              freshSong.title ?? 'Sin título',
                              freshSong.artist?.displayName ?? 'Artista desconocido',
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // ⚡ Widget optimizado: solo se reconstruye si cambia isPlaying
                          MiniPlayerComponents.playButton(),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // ⚡ Widget optimizado: solo se reconstruye si cambia progress
                      MiniPlayerComponents.progressBar(),
                    ],
                ),
              ),
            );
          }
        );
      },
    );
  }
}
