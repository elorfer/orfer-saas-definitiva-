import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'http_client_service.dart';
import '../utils/logger.dart';
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
  /// - Aplica cache-busting y fuerza refresh del caché HTTP
  /// - Tolera respuestas en arreglo plano o con wrapper { artists: [] }
  /// - Incluye retry automático con backoff exponencial
  Future<List<FeaturedArtist>> getFeaturedArtists({int limit = 6}) async {
    try {
      final url = '/public/featured/artists';
      
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          url,
          queryParameters: {
            'limit': limit,
            '_t': DateTime.now().millisecondsSinceEpoch,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            extra: {
              'dio_cache_force_refresh': true,
            },
          ),
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response, listKey: 'artists');

        if (data.isEmpty) {
          return const [];
        }

        // Validar y parsear usando ResponseParser
        final validData = ResponseParser.validateList(data);
        final result = ResponseParser.parseList<FeaturedArtist>(
          data: validData,
          parser: (item) {
            // Usar DataNormalizer para normalizar el artista
            final normalized = DataNormalizer.normalizeArtist(item);
            AppLogger.data('[HomeService] Datos normalizados: ${normalized.keys.toList()}');

            // Imagen preferida - buscar en múltiples lugares
            final rawImage = normalized['profile_photo_url'] as String? ??
                normalized['cover_photo_url'] as String?;

            AppLogger.media('[HomeService] Imagen raw encontrada: $rawImage');
            
            final normalizedImage = UrlNormalizer.normalizeImageUrl(rawImage, enableLogging: true);
            AppLogger.media('[HomeService] Imagen normalizada: $normalizedImage');

            final artist = Artist.fromJson(normalized);
            AppLogger.success('[HomeService] Artista parseado correctamente: ${artist.stageName ?? artist.id}');
            
            // Usar la imagen normalizada o la del artista parseado
            final finalImageUrl = normalizedImage ?? 
                (artist.profilePhotoUrl != null ? UrlNormalizer.normalizeImageUrl(artist.profilePhotoUrl) : null) ??
                (artist.coverPhotoUrl != null ? UrlNormalizer.normalizeImageUrl(artist.coverPhotoUrl) : null);
            
            
            return FeaturedArtist(
              artist: artist,
              featuredReason: 'Destacado',
              rank: validData.indexOf(item) + 1,
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
      
      // Agregar timestamp para evitar caché si se fuerza el refresh
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      
      if (forceRefresh) {
        queryParams['_t'] = DateTime.now().millisecondsSinceEpoch;
      }
      
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          url,
          queryParameters: queryParams,
        ),
      );

        if (ResponseParser.isSuccess(response)) {
          // Usar ResponseParser para extraer la lista
          final data = ResponseParser.extractList(response, listKey: 'songs');
          
          if (data.isEmpty) {
            return [];
          }

          // Validar y parsear usando ResponseParser y DataNormalizer
          final validData = ResponseParser.validateList(data);
          return ResponseParser.parseList<FeaturedSong>(
            data: validData,
            parser: (songData) {
              // Usar DataNormalizer para normalizar la canción
              final normalizedSong = DataNormalizer.normalizeSong(songData);
              
              // Normalizar URL de portada
              final rawCoverUrl = normalizedSong['cover_art_url'] as String?;
              final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
              if (normalizedCoverUrl != null) {
                normalizedSong['cover_art_url'] = normalizedCoverUrl;
              }
              
              final song = Song.fromJson(normalizedSong);
              
              return FeaturedSong(
                song: song,
                featuredReason: 'Destacada por el administrador',
                rank: validData.indexOf(songData) + 1,
              );
            },
            logErrors: false,
          );
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
        
        return ResponseParser.parseList<Song>(
          data: validData,
          parser: (json) {
            final normalized = DataNormalizer.normalizeSong(json);
            return Song.fromJson(normalized);
          },
          logErrors: false,
        );
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
        
        return ResponseParser.parseList<Artist>(
          data: validData,
          parser: (json) {
            final normalized = DataNormalizer.normalizeArtist(json);
            return Artist.fromJson(normalized);
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
    } catch (e, stackTrace) {
      ErrorHandler.handleGenericError(e, context: 'HomeService.getFeaturedPlaylists', logError: true);
      AppLogger.error('[HomeService] Error inesperado al obtener playlists destacadas', e, stackTrace);
      return [];
    }
  }


}
