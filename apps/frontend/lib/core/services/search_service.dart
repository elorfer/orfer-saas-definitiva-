import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'http_client_service.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/genre_model.dart';
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

      // Realizar búsqueda principal en el servidor
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

      // 🚀 OPTIMIZACIÓN: Normalizar colecciones en Isolate secundario
      // Esto libera el UI Thread de procesar mapas de JSON grandes
      final resultsLists = await Future.wait([
        DataNormalizer.normalizeArtistsAsync(data['artists'] as List<dynamic>? ?? []),
        DataNormalizer.normalizeSongsAsync(data['songs'] as List<dynamic>? ?? []),
        DataNormalizer.normalizePlaylistsAsync(data['playlists'] as List<dynamic>? ?? []),
      ]);

      final artistsData = resultsLists[0];
      final songsData = resultsLists[1];
      final playlistsData = resultsLists[2];

      // Buscar géneros por nombre (endpoint dedicado)
      List<Genre> genres = [];
      Genre? matchedGenre;
      try {
        genres = await _searchGenres(query.trim(), limit: limit, cancelToken: cancelToken);
        // Si encontramos géneros, usar el primero que coincida (puede ser parcial o exacto)
        if (genres.isNotEmpty) {
          final normalizedQuery = query.trim().toLowerCase();
          // Buscar coincidencia exacta primero
          try {
            matchedGenre = genres.firstWhere(
              (g) => g.name.toLowerCase() == normalizedQuery,
            );
          } catch (_) {
            // Si no hay coincidencia exacta, usar el primer género encontrado
            // (el backend ya filtró por nombre)
            matchedGenre = genres.first;
          }
        }
      } catch (e) {
        // Log del error para debug pero no bloquear resultados
        AppLogger.error('[SearchService] Error buscando géneros: $e');
      }

      final normalizedQuery = query.trim().toLowerCase();

      final artistsList = artistsData.map((json) => Artist.fromJson(json)).toList();

      // Filtrar canciones por coincidencia en título o géneros
      final songsList = await Song.parseList(songsData);
      
      // Si encontramos un género, también buscar canciones que tengan ese género en el array genres
      final genreNameToMatch = matchedGenre?.name.toLowerCase();
      
      final filteredSongs = songsList.where((song) {
        final titleMatch = (song.title ?? '').toLowerCase().contains(normalizedQuery);
        final genreMatch = (song.genres ?? []).any(
          (g) => g.toLowerCase().contains(normalizedQuery),
        );
        // Si tenemos un género coincidente, también buscar por su nombre exacto en el array genres
        final genreNameMatch = genreNameToMatch != null && 
            (song.genres ?? []).any(
              (g) {
                final gLower = g.toLowerCase();
                return gLower == genreNameToMatch || 
                       gLower.contains(genreNameToMatch) ||
                       genreNameToMatch.contains(gLower);
              },
            );
        return titleMatch || genreMatch || genreNameMatch;
      }).toList();

      // Si encontramos un género que coincide, obtener canciones y artistas de ese género
      List<Song> genreSongs = [];
      List<Artist> genreArtists = [];
      if (matchedGenre != null && matchedGenre.id.isNotEmpty) {
        try {
          AppLogger.info('[SearchService] Obteniendo canciones del género: ${matchedGenre.name} (ID: ${matchedGenre.id})');
          final genreResults = await _getSongsByGenre(matchedGenre.id, limit: limit, cancelToken: cancelToken);
          genreSongs = genreResults['songs'] as List<Song>;
          genreArtists = genreResults['artists'] as List<Artist>;
          AppLogger.info('[SearchService] Encontradas ${genreSongs.length} canciones y ${genreArtists.length} artistas del género');
        } catch (e) {
          // Log del error para debug pero continuar con resultados normales
          AppLogger.error('[SearchService] Error obteniendo canciones del género: $e');
        }
      } else {
        AppLogger.info('[SearchService] No se encontró género coincidente para: ${query.trim()}');
      }

      // Combinar resultados: agregar canciones y artistas del género si no están ya en los resultados
      final combinedSongs = <Song>[];
      final songIds = filteredSongs.map((s) => s.id).toSet();
      combinedSongs.addAll(filteredSongs);
      for (final song in genreSongs) {
        if (!songIds.contains(song.id)) {
          combinedSongs.add(song);
          songIds.add(song.id);
        }
      }

      final combinedArtists = <Artist>[];
      final artistIds = artistsList.map((a) => a.id).toSet();
      combinedArtists.addAll(artistsList);
      for (final artist in genreArtists) {
        if (!artistIds.contains(artist.id)) {
          combinedArtists.add(artist);
          artistIds.add(artist.id);
        }
      }

      final playlistsList = playlistsData.map((json) => Playlist.fromJson(json)).toList();

      final results = SearchResults(
        artists: combinedArtists,
        songs: combinedSongs,
        playlists: playlistsList,
        genres: genres,
        totals: SearchTotals(
          artists: combinedArtists.length,
          songs: combinedSongs.length,
          playlists: (data['totals']?['playlists'] as num?)?.toInt() ?? playlistsList.length,
          genres: genres.length,
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

  /// Obtener géneros destacados/listado para explorar
  Future<List<Genre>> getGenres({int limit = 20}) async {
    try {
      await initialize();
      final response = await _httpClient.dio.get(
        '/genres',
        queryParameters: {
          'limit': limit,
          'page': 1,
          'all': true,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final genresData = (data['genres'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizeGenre(item as Map<String, dynamic>))
              .toList() ??
          [];

      return genresData.map((json) => Genre.fromJson(json)).toList();
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SearchService.getGenres');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SearchService.getGenres');
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

  /// Buscar géneros por nombre
  Future<List<Genre>> _searchGenres(String query, {int limit = 10, CancelToken? cancelToken}) async {
    if (query.isEmpty) return [];
    try {
      await initialize();
      final response = await _httpClient.dio.get(
        '/genres/search',
        queryParameters: {
          'q': query,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final genresData = (data['genres'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizeGenre(item as Map<String, dynamic>))
              .toList() ??
          [];

      final genres = genresData.map((json) => Genre.fromJson(json)).toList();
      
      // Log para debug
      if (genres.isNotEmpty && kDebugMode) {
        AppLogger.info('[SearchService._searchGenres] Géneros encontrados: ${genres.length}');
        for (final genre in genres.take(3)) {
          AppLogger.info('[SearchService._searchGenres] Género: ${genre.name}, imageUrl: ${genre.imageUrl}');
        }
      }
      
      return genres;
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SearchService._searchGenres');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SearchService._searchGenres');
      rethrow;
    }
  }

  /// Obtener canciones y artistas por ID de género
  Future<Map<String, dynamic>> _getSongsByGenre(String genreId, {int limit = 20, CancelToken? cancelToken}) async {
    try {
      await initialize();
      AppLogger.info('[SearchService._getSongsByGenre] Llamando a /songs/genre/$genreId con limit=$limit');
      final response = await _httpClient.dio.get(
        '/songs/genre/$genreId',
        queryParameters: {
          'page': 1,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );

      AppLogger.info('[SearchService._getSongsByGenre] Respuesta status: ${response.statusCode}');
      if (kDebugMode) {
        AppLogger.info('[SearchService._getSongsByGenre] Respuesta data: ${response.data}');
      }

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      
      // El backend devuelve { songs: Song[], total: number }
      List<dynamic> songsList = [];
      if (data.containsKey('songs')) {
        final songsValue = data['songs'];
        if (songsValue is List) {
          songsList = songsValue;
        }
      }

      AppLogger.info('[SearchService._getSongsByGenre] Canciones encontradas: ${songsList.length}');

      final songsData = songsList
          .map((item) => DataNormalizer.normalizeSong(item as Map<String, dynamic>))
          .toList();

      final songs = await Song.parseList(songsData);
      
      // Extraer artistas únicos de las canciones
      final artistsMap = <String, Artist>{};
      for (final song in songs) {
        if (song.artist != null && !artistsMap.containsKey(song.artist!.id)) {
          artistsMap[song.artist!.id] = song.artist!;
        }
      }

      AppLogger.info('[SearchService._getSongsByGenre] Artistas extraídos: ${artistsMap.length}');

      return {
        'songs': songs,
        'artists': artistsMap.values.toList(),
      };
    } on DioException catch (e) {
      AppLogger.error('[SearchService._getSongsByGenre] Error DioException: ${e.message}');
      AppLogger.error('[SearchService._getSongsByGenre] Response: ${e.response?.data}');
      ErrorHandler.handleDioError(e, context: 'SearchService._getSongsByGenre');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('[SearchService._getSongsByGenre] Error: $e');
      AppLogger.error('[SearchService._getSongsByGenre] StackTrace: $stackTrace');
      ErrorHandler.handleGenericError(e, context: 'SearchService._getSongsByGenre');
      rethrow;
    }
  }

  /// Obtener artistas destacados/trending
  Future<List<Artist>> getTrendingArtists({int limit = 10, CancelToken? cancelToken}) async {
    try {
      await initialize();
      
      final response = await _httpClient.dio.get(
        '/public/artists/featured',
        queryParameters: {'limit': limit},
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      // El endpoint público devuelve directamente un array
      final data = response.data;
      List<dynamic> artistsList;
      if (data is List) {
        artistsList = data;
      } else if (data is Map<String, dynamic> && data.containsKey('artists')) {
        artistsList = data['artists'] as List<dynamic>? ?? [];
      } else {
        artistsList = [];
      }

      // 🚀 OPTIMIZACIÓN: Normalizar artistas en Isolate secundario
      final artistsData = await DataNormalizer.normalizeArtistsAsync(artistsList);

      return artistsData.map((json) => Artist.fromJson(json)).toList();
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SearchService.getTrendingArtists');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SearchService.getTrendingArtists');
      rethrow;
    }
  }

  /// ⚡ OPTIMIZADO: Obtener canciones top/populares con timeout reducido
  Future<List<Song>> getTopSongs({int limit = 10, CancelToken? cancelToken}) async {
    try {
      await initialize();
      
      // ⚡ OPTIMIZACIÓN: Timeout más corto para respuesta rápida
      final response = await _httpClient.dio.get(
        '/public/songs/top',
        queryParameters: {'limit': limit},
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 5), // ⚡ Reducido de 10 a 5 segundos
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      // El endpoint público devuelve directamente un array
      final data = response.data;
      List<dynamic> songsList;
      if (data is List) {
        songsList = data;
      } else if (data is Map<String, dynamic> && data.containsKey('songs')) {
        songsList = data['songs'] as List<dynamic>? ?? [];
      } else {
        songsList = [];
      }

      // ⚡ OPTIMIZACIÓN: Normalizar canciones en Isolate secundario
      final songsData = await DataNormalizer.normalizeSongsAsync(songsList);

      return await Song.parseList(songsData);
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SearchService.getTopSongs');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SearchService.getTopSongs');
      rethrow;
    }
  }

  /// ⚡ OPTIMIZADO: Obtener todos los géneros disponibles con timeout reducido
  Future<List<Genre>> getAllGenres({CancelToken? cancelToken}) async {
    try {
      await initialize();
      
      // ⚡ OPTIMIZACIÓN: Usar paginación con límite razonable (30 géneros es suficiente)
      // Timeout reducido para respuesta rápida
      final response = await _httpClient.dio.get(
        '/genres',
        queryParameters: {
          'page': 1,
          'limit': 30, // ⚡ Reducido de 50 a 30 para carga más rápida
        },
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 5), // ⚡ Reducido de 10 a 5 segundos
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      
      // ⚡ OPTIMIZACIÓN: Normalizar géneros en Isolate secundario
      final genresData = await DataNormalizer.normalizeGenresAsync(data['genres'] as List<dynamic>? ?? []);

      return genresData.map((json) => Genre.fromJson(json)).toList();
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SearchService.getAllGenres');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SearchService.getAllGenres');
      rethrow;
    }
  }
}

class SearchResults {
  final List<Artist> artists;
  final List<Song> songs;
  final List<Playlist> playlists;
  final List<Genre> genres;
  final SearchTotals totals;

  SearchResults({
    required this.artists,
    required this.songs,
    required this.playlists,
    required this.genres,
    required this.totals,
  });

  factory SearchResults.empty() {
    return SearchResults(
      artists: const [],
      songs: const [],
      playlists: const [],
      genres: const [],
      totals: SearchTotals(artists: 0, songs: 0, playlists: 0, genres: 0),
    );
  }

  bool get isEmpty => artists.isEmpty && songs.isEmpty && playlists.isEmpty && genres.isEmpty;
}

class SearchTotals {
  final int artists;
  final int songs;
  final int playlists;
  final int genres;

  SearchTotals({
    required this.artists,
    required this.songs,
    required this.playlists,
    required this.genres,
  });
}

