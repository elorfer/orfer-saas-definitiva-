import 'package:dio/dio.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import 'http_client_service.dart';
import '../utils/url_normalizer.dart';
import '../utils/retry_handler.dart';
import '../utils/error_handler.dart';
import '../utils/data_normalizer.dart';
import '../utils/response_parser.dart';
import '../utils/logger.dart';

class PlaylistService {
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal();

  final HttpClientService _httpClient = HttpClientService();
  bool _initialized = false;

  /// Obtener instancia de Dio del HttpClientService
  Dio get _dio => _httpClient.dio;
  
  /// Obtener instancia de Dio (público para uso en isolates)
  Dio get dio => _httpClient.dio;

  /// Inicializar el servicio
  Future<void> initialize() async {
    if (_initialized) {
      return; // Ya está inicializado
    }
    
    // Asegurar que HttpClientService esté inicializado
    if (!_httpClient.isInitialized) {
      await _httpClient.initialize();
    }
    
    _initialized = true;
  }

  /// Obtener todas las playlists
  Future<List<Playlist>> getPlaylists({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '/public/playlists',
          queryParameters: {
            'page': page,
            'limit': limit,
          },
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response, listKey: 'playlists');
        final validData = ResponseParser.validateList(data);
        
        if (validData.isEmpty) {
          return [];
        }
        
        return ResponseParser.parseList<Playlist>(
          data: validData,
          parser: (jsonData) {
            // Usar DataNormalizer para normalizar la playlist
            final normalizedData = DataNormalizer.normalizePlaylist(jsonData);
            
            // Normalizar URL de portada
            final coverUrl = normalizedData['cover_art_url'] as String?;
            if (coverUrl != null && coverUrl.isNotEmpty) {
              final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(coverUrl);
              if (normalizedCoverUrl != null) {
                normalizedData['cover_art_url'] = normalizedCoverUrl;
              }
            }
            
            return Playlist.fromJson(normalizedData);
          },
          logErrors: false,
        );
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'PlaylistService.getPlaylists', logError: false);
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'PlaylistService.getPlaylists', logError: false);
      return [];
    }
  }

  /// Obtener playlist por ID con sus canciones
  Future<Playlist?> getPlaylistById(String id) async {
    try {
      // Validar que el ID no esté vacío
      if (id.isEmpty || id.trim().isEmpty) {
        return null;
      }
      
      final url = '/public/playlists/${id.trim()}';
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(url),
      );

      if (ResponseParser.isSuccess(response)) {
        // Para playlists, el backend devuelve el objeto directamente, no envuelto
        // No usar extractObject porque podría extraer el objeto 'user' anidado
        Map<String, dynamic> jsonData;
        if (response.data is Map<String, dynamic>) {
          final rawData = response.data as Map<String, dynamic>;
          // Verificar que sea realmente una playlist (debe tener campos de playlist)
          final hasPlaylistFields = rawData.containsKey('id') && 
                                   (rawData.containsKey('userId') || rawData.containsKey('name') || rawData.containsKey('totalTracks'));
          
          if (!hasPlaylistFields) {
            // Intentar buscar en claves comunes
            if (rawData.containsKey('playlist') && rawData['playlist'] is Map<String, dynamic>) {
              jsonData = rawData['playlist'] as Map<String, dynamic>;
            } else if (rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>) {
              jsonData = rawData['data'] as Map<String, dynamic>;
            } else {
              return null;
            }
          } else {
            jsonData = rawData;
          }
        } else {
          return null;
        }
        
        // Usar DataNormalizer para normalizar la playlist
        final normalizedData = DataNormalizer.normalizePlaylist(jsonData);
        
        try {
          final playlist = Playlist.fromJson(normalizedData);
          return playlist;
        } catch (e, stackTrace) {
          AppLogger.error('[PlaylistService] Error al parsear playlist $id', e, stackTrace);
          return null;
        }
      } else {
        return null;
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'PlaylistService.getPlaylistById', logError: true);
      return null;
    } catch (e, stackTrace) {
      ErrorHandler.handleGenericError(e, context: 'PlaylistService.getPlaylistById', logError: true);
      AppLogger.error('[PlaylistService] Error inesperado al obtener playlist $id', e, stackTrace);
      return null;
    }
  }

  /// Obtener canciones de una playlist
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    try {
      // Obtener la playlist completa que incluye las canciones
      final playlist = await getPlaylistById(playlistId);
      
      if (playlist == null) {
        return [];
      }

      return playlist.songs;
    } catch (e) {
      return [];
    }
  }

  /// Obtener playlists destacadas
  Future<List<Playlist>> getFeaturedPlaylists({int limit = 10}) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '/public/playlists/featured',
          queryParameters: {'limit': limit},
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response);
        final validData = ResponseParser.validateList(data);
        
        if (validData.isEmpty) {
          return [];
        }
        
        return ResponseParser.parseList<Playlist>(
          data: validData,
          parser: (jsonData) {
            // Usar DataNormalizer para normalizar la playlist
            final normalizedData = DataNormalizer.normalizePlaylist(jsonData);
            
            // Normalizar URL de portada
            final coverUrl = normalizedData['cover_art_url'] as String?;
            if (coverUrl != null && coverUrl.isNotEmpty) {
              final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(coverUrl);
              if (normalizedCoverUrl != null) {
                normalizedData['cover_art_url'] = normalizedCoverUrl;
              }
            }
            
            return Playlist.fromJson(normalizedData);
          },
          logErrors: false,
        );
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'PlaylistService.getFeaturedPlaylists', logError: false);
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'PlaylistService.getFeaturedPlaylists', logError: false);
      return [];
    }
  }

}

