import 'package:dio/dio.dart';
import 'http_client_service.dart';
import '../utils/error_handler.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../utils/data_normalizer.dart';

/// Cache entry para resultados de búsqueda
class _SearchCacheEntry {
  final SearchResults results;
  final DateTime timestamp;

  _SearchCacheEntry(this.results, this.timestamp);

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inMinutes >= 5; // ✅ TTL de 5 minutos
  }
}

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final HttpClientService _httpClient = HttpClientService();
  
  // ✅ OPTIMIZACIÓN: Cache de búsquedas con TTL de 5 minutos
  final Map<String, _SearchCacheEntry> _searchCache = {};
  
  /// Limpiar cache expirado
  void _cleanExpiredCache() {
    _searchCache.removeWhere((key, entry) => entry.isExpired);
  }
  
  /// Generar clave única para cache basada en query y limit
  String _generateCacheKey(String query, int limit) {
    return '${query.trim().toLowerCase()}_$limit';
  }

  /// Inicializar el servicio
  Future<void> initialize() async {
    if (!_httpClient.isInitialized) {
      await _httpClient.initialize();
    }
  }

  /// Realiza una búsqueda global de artistas, canciones y playlists
  /// ✅ OPTIMIZACIÓN: Implementa cache con TTL de 5 minutos para reducir llamadas API
  Future<SearchResults> search(String query, {int limit = 10, CancelToken? cancelToken, bool forceRefresh = false}) async {
    try {
      // Asegurar que el servicio esté inicializado
      await initialize();

      if (query.trim().isEmpty) {
        return SearchResults.empty();
      }

      // ✅ OPTIMIZACIÓN: Limpiar cache expirado antes de buscar
      _cleanExpiredCache();
      
      // ✅ OPTIMIZACIÓN: Verificar cache si no se fuerza refresh
      if (!forceRefresh) {
        final cacheKey = _generateCacheKey(query, limit);
        final cachedEntry = _searchCache[cacheKey];
        
        if (cachedEntry != null && !cachedEntry.isExpired) {
          // Retornar resultado del cache
          return cachedEntry.results;
        }
      }

      // Realizar búsqueda en el servidor
      final response = await _httpClient.dio.get(
        '/search',
        queryParameters: {
          'q': query.trim(),
          'limit': limit,
        },
        cancelToken: cancelToken, // OPTIMIZACIÓN: Permitir cancelación de búsquedas
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;

      // Normalizar y parsear resultados
      final artistsData = (data['artists'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizeArtist(item as Map<String, dynamic>))
              .toList() ??
          [];
      final songsData = (data['songs'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizeSong(item as Map<String, dynamic>))
              .toList() ??
          [];
      final playlistsData = (data['playlists'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizePlaylist(item as Map<String, dynamic>))
              .toList() ??
          [];

      final results = SearchResults(
        artists: artistsData.map((json) => Artist.fromJson(json)).toList(),
        songs: songsData.map((json) => Song.fromJson(json)).toList(),
        playlists: playlistsData.map((json) => Playlist.fromJson(json)).toList(),
        totals: SearchTotals(
          artists: (data['totals']?['artists'] as num?)?.toInt() ?? 0,
          songs: (data['totals']?['songs'] as num?)?.toInt() ?? 0,
          playlists: (data['totals']?['playlists'] as num?)?.toInt() ?? 0,
        ),
      );
      
      // ✅ OPTIMIZACIÓN: Guardar en cache
      final cacheKey = _generateCacheKey(query, limit);
      _searchCache[cacheKey] = _SearchCacheEntry(results, DateTime.now());
      
      // ✅ OPTIMIZACIÓN: Limitar tamaño del cache (máximo 50 entradas)
      if (_searchCache.length > 50) {
        // Eliminar la entrada más antigua
        final oldestKey = _searchCache.entries
            .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
            .key;
        _searchCache.remove(oldestKey);
      }
      
      return results;
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SearchService.search');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SearchService.search');
      rethrow;
    }
  }
  
  /// Limpiar todo el cache de búsquedas
  void clearCache() {
    _searchCache.clear();
  }
  
  /// Obtener estadísticas del cache
  Map<String, dynamic> getCacheStats() {
    _cleanExpiredCache();
    return {
      'size': _searchCache.length,
      'maxSize': 50,
      'entries': _searchCache.keys.toList(),
    };
  }
}

class SearchResults {
  final List<Artist> artists;
  final List<Song> songs;
  final List<Playlist> playlists;
  final SearchTotals totals;

  SearchResults({
    required this.artists,
    required this.songs,
    required this.playlists,
    required this.totals,
  });

  factory SearchResults.empty() {
    return SearchResults(
      artists: [],
      songs: [],
      playlists: [],
      totals: SearchTotals(artists: 0, songs: 0, playlists: 0),
    );
  }

  bool get isEmpty => artists.isEmpty && songs.isEmpty && playlists.isEmpty;
}

class SearchTotals {
  final int artists;
  final int songs;
  final int playlists;

  SearchTotals({
    required this.artists,
    required this.songs,
    required this.playlists,
  });
}

