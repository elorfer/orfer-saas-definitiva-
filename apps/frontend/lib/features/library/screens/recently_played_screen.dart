import 'dart:async'; // ✅ Para Timer
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // ✅ Para ScrollDirection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/play_history_provider.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/models/song_model.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../core/utils/intersection_observer.dart';
import '../../../core/widgets/optimized_image.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pantalla de canciones recientemente reproducidas
/// ✅ MEJORA: Precarga de imágenes optimizada
class RecentlyPlayedScreen extends ConsumerStatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  ConsumerState<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends ConsumerState<RecentlyPlayedScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 🔥 OPTIMIZACIÓN: Mantener estado al cambiar de pestañas
  
  // 🔥 OPTIMIZACIÓN: ScrollController para precache dinámico de imágenes (como en Home)
  late final ScrollController _scrollController;
  
  // ✅ OPTIMIZACIÓN: Cache de URLs de imágenes para evitar recálculos en _onScroll
  List<String> _cachedImageUrls = [];
  int _cachedSongsCount = 0;
  
  // ✅ OPTIMIZACIÓN: Timer para debounce en _onScroll
  Timer? _scrollDebounceTimer;
  
  @override
  void initState() {
    super.initState();
    // 🔥 OPTIMIZACIÓN: ScrollController para precache dinámico
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // Inicializar cache desde el provider una sola vez y suscribirse a cambios
    final initialHistory = ref.read(playHistoryProvider);
    _cachedImageUrls = initialHistory
        .reversed
        .map((song) => UrlNormalizer.normalizeImageUrl(song.coverArtUrl))
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    _cachedSongsCount = initialHistory.length;

    if (_cachedImageUrls.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        LazyImageLoader.precacheInitialImages(
          imageUrls: _cachedImageUrls,
          context: context,
          count: 10,
        );
      });
    }
  }
  
  @override
  void dispose() {
    // ✅ OPTIMIZACIÓN: Cancelar timer de debounce
    _scrollDebounceTimer?.cancel();
    // 🔥 OPTIMIZACIÓN: Limpiar ScrollController
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 🔥 OPTIMIZACIÓN: Precargar imágenes visibles cuando el usuario hace scroll (como en Home)
  /// ✅ CORRECCIÓN: Agregado debounce para evitar ejecuciones excesivas
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    
    // ✅ OPTIMIZACIÓN: Cancelar timer anterior si existe
    _scrollDebounceTimer?.cancel();
    
    // ✅ OPTIMIZACIÓN: Debounce más ajustado para mejor respuesta sin jank
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !_scrollController.hasClients) return;
      
      try {
        // Ejecutar precarga solo cuando el usuario se desplaza hacia adelante
        final direction = _scrollController.position.userScrollDirection;
        if (direction != ScrollDirection.forward) {
          return; // Evitar trabajo en rebotes/retrocesos
        }
        
        // ✅ OPTIMIZACIÓN: Usar URLs cacheadas en lugar de leer del provider cada vez
        if (_cachedImageUrls.isEmpty) {
          // Si no hay cache, actualizar desde el provider (solo una vez)
          final history = ref.read(playHistoryProvider);
          _cachedImageUrls = history
              .reversed
              .map((song) => UrlNormalizer.normalizeImageUrl(song.coverArtUrl))
              .where((url) => url != null && url.isNotEmpty)
              .cast<String>()
              .toList();
          _cachedSongsCount = history.length;
        }
        
        // Precachear imágenes visibles basado en posición del scroll (IntersectionObserver)
        if (_cachedImageUrls.isNotEmpty) {
          LazyImageLoader.precacheVisibleVerticalImages(
            scrollController: _scrollController,
            itemExtent: 72.0, // ✅ Corregido: usar el mismo itemExtent que en SliverFixedExtentList
            itemCount: _cachedSongsCount,
            imageUrls: _cachedImageUrls,
            context: context,
            precacheCount: 3, // Precachear menos items para bajar memoria
          );
        }
      } catch (e) {
        // ✅ OPTIMIZACIÓN: Manejar errores silenciosamente para no bloquear la app
        debugPrint('[RecentlyPlayedScreen] Error en _onScroll: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Requerido por AutomaticKeepAliveClientMixin
    
    // Observar cambios en el historial para mantener cache/precarga
    final history = ref.watch(playHistoryProvider);
    final recentSongs = List<Song>.from(history.reversed).take(50).toList();

    // Escuchar cambios en el historial aquí (permitido en build) y mantener cache/precarga
    ref.listen<List<Song>>(playHistoryProvider, (previous, next) {
      _cachedImageUrls = next
          .reversed
          .map((song) => UrlNormalizer.normalizeImageUrl(song.coverArtUrl))
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();
      _cachedSongsCount = next.length;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _cachedImageUrls.isEmpty) return;
        try {
          LazyImageLoader.precacheInitialImages(
            imageUrls: _cachedImageUrls,
            context: context,
            count: 10,
          );
        } catch (e) {
          debugPrint('[RecentlyPlayedScreen] Error precaching after listen: $e');
        }
      });
    });
    

    // 🚀 OPTIMIZACIÓN 60 FPS: RepaintBoundary y const donde sea posible
    return RepaintBoundary(
      child: Scaffold(
        key: const ValueKey('recently_played_screen_scaffold'),
        backgroundColor: NeumorphismTheme.surface,
        appBar: AppBar(
        backgroundColor: NeumorphismTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: NeumorphismTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Recientemente Reproducidas',
          style: GoogleFonts.inter(
            color: NeumorphismTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: recentSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay canciones recientes',
                    style: GoogleFonts.inter(
                      color: NeumorphismTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              controller: _scrollController, // 🔥 OPTIMIZACIÓN: Controller para precache dinámico
              // 🔥 OPTIMIZADO: cacheExtent reducido aún más para dispositivos de gama baja
              cacheExtent: 300,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ), // ✅ Scroll estilo iPhone (igual que Home)
              clipBehavior: Clip.none, // Evitar clipping innecesario
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverFixedExtentList(
                    itemExtent: 72.0, // ✅ Reducido de 80 a 72 (tarjetas más pequeñas)
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = recentSongs[index];
                        
                        return RepaintBoundary(
                          key: ValueKey('recent_song_${song.id}'),
                          child: _SongHistoryItem(
                            key: ValueKey('recent_item_${song.id}'),
                            song: song,
                            index: index,
                            onTap: () {
                              // ✅ Navegar a la pantalla de detalle de la canción
                              context.push('/song/${song.id}', extra: song);
                            },
                            onPlay: () {
                              // ✅ Navegar a la pantalla de detalle de la canción
                              context.push('/song/${song.id}', extra: song);
                            },
                          ),
                        );
                      },
                      childCount: recentSongs.length,
                      // 🔥 OPTIMIZACIONES PARA GRANDES VOLÚMENES:
                      addAutomaticKeepAlives: false, // No mantener vivos items fuera de vista (ahorra memoria)
                      addRepaintBoundaries: false, // Ya tenemos RepaintBoundary manual (evita duplicación)
                      addSemanticIndexes: false, // Desactivar índices semánticos (mejor rendimiento)
                    ),
                  ),
                ),
                // ✅ Padding inferior para que el mini player no tape la última canción
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 120),
                ),
              ],
            ),
      ),
    );
  }
}

class _SongHistoryItem extends ConsumerWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  const _SongHistoryItem({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Verificar si la canción está disponible para reproducir
    final isAvailable = song.fileUrl != null && song.fileUrl!.isNotEmpty;
    
    // ✅ OPTIMIZACIÓN: Variables eliminadas ya que el botón play siempre inicia nueva reproducción
    // (no necesita verificar si es la canción actual o si está reproduciéndose)

    // ✅ OPTIMIZACIÓN: Usar URL directamente, OptimizedImage se encarga de normalizarla
    final coverUrl = song.coverArtUrl;

    // OPTIMIZACIÓN: Opacidad simulada con color alpha para evitar `saveLayer`
    return IgnorePointer(
      ignoring: !isAvailable,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), // ✅ Reducido de 12 a 8
        decoration: BoxDecoration(
          color: NeumorphismTheme.surface.withOpacity(isAvailable ? 1.0 : 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: NeumorphismTheme.floatingCardShadow.map((s) => s.copyWith(
            color: s.color.withOpacity(isAvailable ? s.color.opacity : s.color.opacity * 0.5)
          )).toList(),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isAvailable ? onTap : null, // Deshabilitar tap si no está disponible
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ✅ Reducido de all(12) a symmetric(12, 10)
              child: Row(
                children: [
                  // Número de posición
                  Container(
                    width: 28, // ✅ Reducido de 32 a 28
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        color: isAvailable 
                            ? NeumorphismTheme.textSecondary 
                            : NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 14, // ✅ Reducido de 16 a 14
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10), // ✅ Reducido de 12 a 10
                  // Portada optimizada con precarga - Más pequeña y CUADRADA
                  Container(
                    width: 56, // ✅ Reducido de 64 a 56
                    height: 56, // ✅ Reducido de 64 a 56
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      maxWidth: 56,
                      minHeight: 56,
                      maxHeight: 56,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(8)), // ✅ Más cuadrado (reducido de 12 a 8)
                      clipBehavior: Clip.antiAlias,
                      child: coverUrl != null
                          ? OptimizedImage(
                              imageUrl: coverUrl,
                              width: 56, // ✅ CRÍTICO: Especificar width explícitamente para asegurar forma cuadrada
                              height: 56, // ✅ CRÍTICO: Especificar height explícitamente para asegurar forma cuadrada
                              fit: BoxFit.cover,
                              isLargeCover: false,
                              // 🔥 OPTIMIZADO: Tamaños de cache reducidos para mejor rendimiento con muchas imágenes
                              maxCacheWidth: 112, // 2x el tamaño de visualización (56 * 2)
                              maxCacheHeight: 112,
                              useThumbnail: true, // Usar thumbnails cuando estén disponibles
                              skipFade: true, // Sin fade para mejor rendimiento en scroll rápido
                              lazyLoad: false, // ✅ DESACTIVADO: SliverChildBuilderDelegate ya maneja lazy loading
                            )
                          : Container(
                              width: 56, // ✅ Reducido de 64 a 56
                              height: 56, // ✅ Reducido de 64 a 56
                              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                              child: const Icon(Icons.music_note, color: Colors.white30, size: 24), // ✅ Reducido de tamaño por defecto
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Información
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // ✅ Evitar overflow
                      children: [
                        Text(
                          song.title ?? 'Sin título',
                          style: GoogleFonts.inter(
                            color: isAvailable 
                                ? NeumorphismTheme.textPrimary 
                                : NeumorphismTheme.textPrimary.withValues(alpha: 0.6),
                            fontSize: 15, // ✅ Reducido de 16 a 15
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3), // ✅ Reducido de 4 a 3
                        Row(
                          children: [
                            Flexible( // ✅ Cambiado de Expanded a Flexible para evitar overflow
                              child: Text(
                                song.artist?.displayName ?? 'Artista desconocido',
                                style: GoogleFonts.inter(
                                  color: isAvailable 
                                      ? NeumorphismTheme.textSecondary 
                                      : NeumorphismTheme.textSecondary.withValues(alpha: 0.5),
                                  fontSize: 13, // ✅ Reducido de 14 a 13
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isAvailable) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.error_outline,
                                size: 12, // ✅ Reducido de 14 a 12
                                color: Colors.orange.withValues(alpha: 0.7),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6), // ✅ Agregado espacio antes del botón
                  // Botón play - SIEMPRE muestra play ya que siempre inicia nueva reproducción (como tocar la tarjeta)
                  IconButton(
                    icon: Icon(
                      // ✅ SIEMPRE mostrar play ya que siempre inicia nueva reproducción con algoritmo
                      Icons.play_circle_filled,
                      color: isAvailable 
                          ? NeumorphismTheme.coffeeMedium 
                          : NeumorphismTheme.textSecondary.withValues(alpha: 0.3),
                      size: 36, // ✅ Reducido de 40 a 36
                    ),
                    padding: EdgeInsets.zero, // ✅ Reducir padding del botón
                    constraints: const BoxConstraints(), // ✅ Sin constraints para que sea más pequeño
                    onPressed: isAvailable ? onPlay : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

