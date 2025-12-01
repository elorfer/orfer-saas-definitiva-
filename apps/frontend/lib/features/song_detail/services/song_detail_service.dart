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
          final normalized = DataNormalizer.normalizeSong(data);
          
          // Normalizar URL de portada
          final rawCoverUrl = normalized['cover_art_url'] as String?;
          final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
          if (normalizedCoverUrl != null) {
            normalized['cover_art_url'] = normalizedCoverUrl;
            normalized['coverArtUrl'] = normalizedCoverUrl;
          }
          
          // Normalizar URL del archivo de audio
          final rawFileUrl = normalized['file_url'] as String?;
          if (rawFileUrl != null && rawFileUrl.isNotEmpty) {
            final normalizedFileUrl = UrlNormalizer.normalizeUrl(rawFileUrl);
            normalized['file_url'] = normalizedFileUrl;
            normalized['fileUrl'] = normalizedFileUrl;
          }
          
          // 🆕 Normalizar URL del avatar del artista si existe
          if (normalized['artist'] is Map<String, dynamic>) {
            final artistData = normalized['artist'] as Map<String, dynamic>;
            final rawArtistAvatarUrl = artistData['profile_photo_url'] as String?;
            debugPrint('🔍 [SONG DETAIL SERVICE] Artista encontrado: ${artistData['stage_name'] ?? artistData['name']}');
            debugPrint('🔍 [SONG DETAIL SERVICE] profile_photo_url raw: $rawArtistAvatarUrl');
            
            // 🆕 OPTIMIZACIÓN: No cargar artista completo aquí (se hace de forma asíncrona en la UI)
            // Esto permite que la pantalla se muestre inmediatamente mientras se carga el avatar en segundo plano
            if (rawArtistAvatarUrl != null && rawArtistAvatarUrl.isNotEmpty) {
              final normalizedArtistAvatarUrl = UrlNormalizer.normalizeImageUrl(rawArtistAvatarUrl);
              debugPrint('🔍 [SONG DETAIL SERVICE] profile_photo_url normalizado: $normalizedArtistAvatarUrl');
              if (normalizedArtistAvatarUrl != null) {
                artistData['profile_photo_url'] = normalizedArtistAvatarUrl;
                normalized['artist'] = artistData;
                debugPrint('✅ [SONG DETAIL SERVICE] Avatar del artista normalizado correctamente');
              } else {
                debugPrint('⚠️ [SONG DETAIL SERVICE] No se pudo normalizar la URL del avatar');
              }
            } else {
              debugPrint('⚠️ [SONG DETAIL SERVICE] Artista sin profile_photo_url - se cargará asíncronamente en la UI');
            }
          } else {
            debugPrint('⚠️ [SONG DETAIL SERVICE] No hay datos de artista en la respuesta');
          }
          
          return Song.fromJson(normalized);
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

