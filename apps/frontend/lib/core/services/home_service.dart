import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/app_message_model.dart';
import 'http_client_service.dart';
import '../utils/url_normalizer.dart';
import '../utils/retry_handler.dart';
import '../utils/error_handler.dart';
import '../utils/data_normalizer.dart';
import '../utils/response_parser.dart';

// Función top-level para procesar playlist en isolate
FeaturedPlaylist? _parseFeaturedPlaylist(Map<String, dynamic> item, int rank) {
  try {
    if (item['id'] == null || item['id'].toString().isEmpty) {
      throw Exception('Playlist sin ID válido');
    }
    
    final normalized = DataNormalizer.normalizePlaylist(item);
    
    if (normalized['isFeatured'] == null) {
      normalized['isFeatured'] = true;
    }
    
    final playlist = Playlist.fromJson(normalized);
    
    if (playlist.id.isEmpty) {
      throw Exception('Playlist con ID vacío');
    }
    
    return FeaturedPlaylist(
      playlist: playlist,
      featuredReason: 'Destacada',
      rank: rank,
    );
  } catch (e) {
    return null;
  }
}

// Función top-level para procesar lista de playlists en isolate
List<FeaturedPlaylist> _parseFeaturedPlaylistsList(List<Map<String, dynamic>> validData) {
  final results = <FeaturedPlaylist>[];
  for (int i = 0; i < validData.length; i++) {
    final item = validData[i];
    final featuredPlaylist = _parseFeaturedPlaylist(item, i + 1);
    if (featuredPlaylist != null) {
      results.add(featuredPlaylist);
    }
  }
  return results;
}

class HomeService {
  static final HomeService _instance = HomeService._internal();
  factory HomeService() => _instance;
  HomeService._internal();

  final HttpClientService _httpClient = HttpClientService();

  /// Obtener instancia de Dio del HttpClientService
  Dio get _dio => _httpClient.dio;

  /// Inicializar el servicio
  Future<void> initialize() async {
    // Asegurar que HttpClientService esté inicializado
    if (!_httpClient.isInitialized) {
      await _httpClient.initialize();
    }
  }

  /// Obtener artistas destacados
  /// - Normaliza claves camelCase/snake_case
  /// - ✅ OPTIMIZACIÓN: Usa cache HTTP normal (solo fuerza refresh si se solicita)
  /// - Tolera respuestas en arreglo plano o con wrapper { artists: [] }
  /// - Incluye retry automático con backoff exponencial
  Future<List<FeaturedArtist>> getFeaturedArtists({int limit = 6, bool forceRefresh = false}) async {
    try {
      final url = '/public/featured/artists';
      
      // ✅ OPTIMIZACIÓN: Solo usar cache-busting si forceRefresh es true
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      
      if (forceRefresh) {
        queryParams['_t'] = DateTime.now().millisecondsSinceEpoch;
      }
      
      final options = Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      );
      
      // ✅ OPTIMIZACIÓN: Solo forzar refresh del cache si se solicita explícitamente
      if (forceRefresh) {
        options.extra = {
          'dio_cache_force_refresh': true,
        };
      }
      
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          url,
          queryParameters: queryParams,
          options: options,
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response, listKey: 'artists');

        if (data.isEmpty) {
          return const [];
        }

        // 🚀 OPTIMIZACIÓN: Normalizar artistas en Isolate secundario
        final normalizedData = await DataNormalizer.normalizeArtistsAsync(data);

        final result = ResponseParser.parseList<FeaturedArtist>(
          data: normalizedData,
          parser: (normalized) {
            // Imagen preferida - buscar en múltiples lugares
            final rawImage = normalized['profile_photo_url'] as String? ??
                normalized['cover_photo_url'] as String?;
            
            final normalizedImage = UrlNormalizer.normalizeImageUrl(rawImage, enableLogging: false);

            final artist = Artist.fromJson(normalized);
            
            // Usar la imagen normalizada o la del artista parseado
            final finalImageUrl = normalizedImage ?? 
                (artist.profilePhotoUrl != null ? UrlNormalizer.normalizeImageUrl(artist.profilePhotoUrl) : null) ??
                (artist.coverPhotoUrl != null ? UrlNormalizer.normalizeImageUrl(artist.coverPhotoUrl) : null);
            
            return FeaturedArtist(
              artist: artist,
              featuredReason: 'Destacado',
              rank: normalizedData.indexOf(normalized) + 1,
              imageUrl: finalImageUrl,
            );
          },
          logErrors: true,
        );

        return result;
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'HomeService.getFeaturedArtists');
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'HomeService.getFeaturedArtists');
      return [];
    }
  }


  /// Obtener canciones destacadas desde el admin
  /// Estas son las canciones que el administrador ha marcado como destacadas
  Future<List<FeaturedSong>> getFeaturedSongs({int limit = 20, bool forceRefresh = false}) async {
    try {
      final url = '/public/featured/songs';
      
      // ✅ OPTIMIZACIÓN: Solo usar cache-busting si forceRefresh es true
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      
      if (forceRefresh) {
        queryParams['_t'] = DateTime.now().millisecondsSinceEpoch;
      }
      
      final options = Options();
      
      // ✅ OPTIMIZACIÓN: Solo forzar refresh del cache si se solicita explícitamente
      if (forceRefresh) {
        options.extra = {
          'dio_cache_force_refresh': true,
        };
      }
      
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          url,
          queryParameters: queryParams,
          options: options,
        ),
      );
      // Depuración: imprimir solo status y tamaño de body (sin volcar el contenido)
      try {
        final status = response.statusCode;
        final body = response.data;
        final bodyStr = body is String ? body : body.toString();
        debugPrint('🔍 [HomeService] GET $url status=$status bodyLen=${bodyStr.length}');
        // NOTA: Evitamos imprimir el contenido del body en modo profile/release
        // porque volcar JSON grande en la consola bloquea el hilo UI.
      } catch (_) {}

      if (ResponseParser.isSuccess(response)) {
          // Usar ResponseParser para extraer la lista
          final data = ResponseParser.extractList(response, listKey: 'songs');
          
          if (data.isEmpty) {
            return [];
          }

          // 🚀 OPTIMIZACIÓN: Normalizar canciones en Isolate secundario
          final normalizedList = await DataNormalizer.normalizeSongsAsync(data);
          
          // Post-procesamiento necesario para URLs (esto es rápido)
          for (final normalizedSong in normalizedList) {
            final rawCoverUrl = normalizedSong['cover_art_url'] as String?;
            final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
            if (normalizedCoverUrl != null) {
              normalizedSong['cover_art_url'] = normalizedCoverUrl;
            }

            final rawFileUrl = normalizedSong['file_url'] as String?;
            if (rawFileUrl != null && rawFileUrl.isNotEmpty) {
              final normalizedFileUrl = UrlNormalizer.normalizeUrl(rawFileUrl);
              normalizedSong['file_url'] = normalizedFileUrl;
              normalizedSong['fileUrl'] = normalizedFileUrl;
            }
          }

          // Parsear las canciones. Si es solo una (caso Adrenalina), saltar compute para ahorrar overhead.
          List<Song> songs;
          if (normalizedList.length == 1) {
            songs = [Song.fromJson(normalizedList.first)];
          } else {
            // Parsear todas las canciones en un isolate para no bloquear el UI thread
            songs = await Song.parseList(normalizedList);
          }

          final parsedSongs = <FeaturedSong>[];
          for (int i = 0; i < songs.length; i++) {
            parsedSongs.add(FeaturedSong(
              song: songs[i],
              featuredReason: 'Destacada por el administrador',
              rank: i + 1,
            ));
          }

          return parsedSongs;
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'HomeService.getFeaturedSongs', logError: false);
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'HomeService.getFeaturedSongs', logError: false);
      return [];
    }
  }

  /// Obtener mensaje público para el banner del home
  Future<HomeMessage?> getHomeMessage({bool forceRefresh = false}) async {
    try {
      final options = Options();
      if (forceRefresh) {
        options.extra = {
          'dio_cache_force_refresh': true,
        };
      }

      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '/public/app-messages/home',
          options: options,
        ),
      );

      if (!ResponseParser.isSuccess(response)) {
        return null;
      }

      final data = response.data as Map<String, dynamic>? ?? {};
      final rawMessage = data['message']?.toString() ?? '';
      final isActive = data['isActive'] as bool? ?? data['is_active'] as bool? ?? false;

      if (rawMessage.isEmpty || !isActive) {
        return null;
      }

      final updatedAt = data['updatedAt'] ?? data['updated_at'] ?? data['publishedAt'] ?? data['published_at'];

      return HomeMessage.fromJson({
        'id': data['id'],
        'message': rawMessage,
        'updatedAt': updatedAt,
        'isActive': isActive,
      });
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'HomeService.getHomeMessage', logError: false);
      return null;
    } catch (_) {
      return null;
    }
  }


  /// Obtiene una canción recomendada basándose en los géneros de la canción actual
  /// 
  /// LÓGICA:
  /// 1. Obtiene los géneros de la canción actual
  /// 2. Busca canciones que compartan al menos un género
  /// 3. Si encuentra coincidencias, elige una al azar
  /// 4. Si no encuentra coincidencias, elige una canción aleatoria de todas las disponibles
  /// 
  /// @param currentSongId ID de la canción actual
  /// @param currentGenres Géneros de la canción actual (opcional, se obtienen de la BD si no se proporcionan)
  /// @returns Canción recomendada o null si no hay canciones disponibles
  Future<Song?> getRecommendedSong(String currentSongId, {List<String>? currentGenres}) async {
    try {
      final url = '/songs/recommended/$currentSongId';
      
      // Agregar géneros como query params si se proporcionan
      final queryParams = <String, dynamic>{};
      if (currentGenres != null && currentGenres.isNotEmpty) {
        queryParams['genres'] = currentGenres;
      }
      
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          url,
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = response.data;
        
        if (data == null || data['song'] == null) {
          return null;
        }

        // Normalizar y parsear la canción recomendada
        final normalizedSong = DataNormalizer.normalizeSong(data['song']);
        
        // Normalizar URL de portada
        final rawCoverUrl = normalizedSong['cover_art_url'] as String?;
        final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
        if (normalizedCoverUrl != null) {
          normalizedSong['cover_art_url'] = normalizedCoverUrl;
        }
        
        final song = await Song.parse(normalizedSong);
        return song;
      } else {
        return null;
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'HomeService.getRecommendedSong', logError: true);
      return null;
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'HomeService.getRecommendedSong', logError: true);
      return null;
    }
  }

  /// Obtener canciones populares
  /// Si el endpoint falla, retorna lista vacía silenciosamente (no afecta la UI)
  /// Incluye retry automático con backoff exponencial
  Future<List<Song>> getPopularSongs({int limit = 10}) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '/public/songs/top',
          queryParameters: {'limit': limit},
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response, listKey: 'songs');
        final validData = ResponseParser.validateList(data);
        
        if (validData.isEmpty) {
          return [];
        }
        
        // 🚀 OPTIMIZACIÓN: Normalizar canciones en Isolate secundario
        final normalizedList = await DataNormalizer.normalizeSongsAsync(validData);

        try {
          return await Song.parseList(normalizedList);
        } catch (_) {
          final parsed = <Song>[];
          for (final n in normalizedList) {
            try {
              parsed.add(Song.fromJson(n));
            } catch (_) {}
          }
          return parsed;
        }
      } else {
        // Error silencioso - el endpoint puede no estar disponible (500, etc.)
        return [];
      }
    } on DioException catch (e) {
      // Error silencioso - no loguear para evitar spam en consola
      ErrorHandler.handleDioError(e, context: 'HomeService.getPopularSongs', logError: false);
      return [];
    } catch (_) {
      // Error silencioso
      return [];
    }
  }

  /// Obtener artistas más escuchados
  /// Incluye retry automático con backoff exponencial
  Future<List<Artist>> getTopArtists({int limit = 8}) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '/public/artists/top',
          queryParameters: {'limit': limit},
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response, listKey: 'artists');
        final validData = ResponseParser.validateList(data);
        
        if (validData.isEmpty) {
          return [];
        }
        
        // 🚀 OPTIMIZACIÓN: Normalizar artistas en Isolate secundario
        final normalizedData = await DataNormalizer.normalizeArtistsAsync(validData);

        return ResponseParser.parseList<Artist>(
          data: normalizedData,
          parser: (json) {
            return Artist.fromJson(json);
          },
          logErrors: false,
        );
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'HomeService.getTopArtists', logError: false);
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'HomeService.getTopArtists', logError: false);
      return [];
    }
  }

  /// Obtener playlists destacadas
  /// Incluye retry automático con backoff exponencial
  Future<List<FeaturedPlaylist>> getFeaturedPlaylists({int limit = 6}) async {
    try {
      final url = '/public/featured/playlists';
      
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          url,
          queryParameters: {'limit': limit},
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response);
        
        if (data.isEmpty) {
          return [];
        }

        final validData = ResponseParser.validateList(data);
        
        // Procesar JSON en isolate para evitar bloqueo del UI thread
        final featuredPlaylists = await compute(_parseFeaturedPlaylistsList, validData);
        
        // Retornar lista (ya filtrada de nulls en el isolate)
        return featuredPlaylists;
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'HomeService.getFeaturedPlaylists', logError: true);
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'HomeService.getFeaturedPlaylists', logError: false);
      return [];
    }
  }


}
