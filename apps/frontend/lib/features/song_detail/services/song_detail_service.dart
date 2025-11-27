import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/song_model.dart';
import '../../../core/services/http_client_service.dart';
import '../../../core/utils/retry_handler.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/data_normalizer.dart';
import '../../../core/utils/response_parser.dart';
import '../../../core/utils/url_normalizer.dart';

/// Servicio para obtener información de canciones y canciones por artista
class SongDetailService {
  static final SongDetailService _instance = SongDetailService._internal();
  factory SongDetailService() => _instance;
  SongDetailService._internal();

  final HttpClientService _httpClient = HttpClientService();

  /// Obtener instancia de Dio del HttpClientService
  Dio get _dio => _httpClient.dio;

  /// Inicializar el servicio
  Future<void> initialize() async {
    if (!_httpClient.isInitialized) {
      await _httpClient.initialize();
    }
  }

  /// Obtener canciones por artista
  Future<List<Song>> getSongsByArtist(String artistId, {int limit = 50}) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '/public/songs',
          queryParameters: {
            'artistId': artistId,
            'limit': limit,
            'all': 'true', // Incluir todas las canciones publicadas
          },
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
            
            // Normalizar URL de portada
            final rawCoverUrl = normalized['cover_art_url'] as String?;
            final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
            if (normalizedCoverUrl != null) {
              normalized['cover_art_url'] = normalizedCoverUrl;
            }
            
            return Song.fromJson(normalized);
          },
          logErrors: true,
        );
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SongDetailService.getSongsByArtist');
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SongDetailService.getSongsByArtist');
      return [];
    }
  }

  /// Obtener una canción por ID
  Future<Song?> getSongById(String songId) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get('/public/songs/$songId'),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          // DEBUG: Ver qué viene del backend
          debugPrint('[SongDetailService] Datos recibidos del backend:');
          debugPrint('[SongDetailService] genres en data: ${data['genres']}');
          debugPrint('[SongDetailService] Tipo de genres: ${data['genres'].runtimeType}');
          
          final normalized = DataNormalizer.normalizeSong(data);
          
          // DEBUG: Ver qué queda después de normalizar
          debugPrint('[SongDetailService] Después de normalizar:');
          debugPrint('[SongDetailService] genres en normalized: ${normalized['genres']}');
          debugPrint('[SongDetailService] Tipo de genres normalizado: ${normalized['genres']?.runtimeType}');
          
          // Normalizar URL de portada
          final rawCoverUrl = normalized['cover_art_url'] as String?;
          final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
          if (normalizedCoverUrl != null) {
            normalized['cover_art_url'] = normalizedCoverUrl;
          }
          
          // IMPORTANTE: También normalizar URL del archivo de audio
          final rawFileUrl = normalized['file_url'] as String?;
          if (rawFileUrl != null && rawFileUrl.isNotEmpty) {
            final normalizedFileUrl = UrlNormalizer.normalizeUrl(rawFileUrl);
            normalized['file_url'] = normalizedFileUrl;
          }
          
          final song = Song.fromJson(normalized);
          debugPrint('[SongDetailService] Canción parseada. Géneros: ${song.genres}');
          return song;
        }
      }
      return null;
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SongDetailService.getSongById');
      return null;
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SongDetailService.getSongById');
      return null;
    }
  }
}

