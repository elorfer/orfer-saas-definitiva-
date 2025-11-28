import 'package:dio/dio.dart';
import '../models/song_model.dart';
import 'http_client_service.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../utils/response_parser.dart';
import '../utils/data_normalizer.dart';

/// Servicio para gestionar favoritos del usuario
class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final HttpClientService _httpClient = HttpClientService();

  /// Obtener instancia de Dio del HttpClientService
  Dio get _dio => _httpClient.dio;

  /// Inicializar el servicio
  Future<void> initialize() async {
    if (!_httpClient.isInitialized) {
      await _httpClient.initialize();
    }
  }

  /// Toggle de favorito: agregar o remover canción de favoritos
  /// Retorna true si se agregó, false si se removió
  Future<bool> toggleFavorite(String songId) async {
    try {
      await initialize();

      AppLogger.debug('[FavoritesService] Toggle favorito para canción: $songId');
      final response = await _dio.post('/favorites/toggle/$songId');

      AppLogger.debug('[FavoritesService] Respuesta toggle: status=${response.statusCode}, data=${response.data}');

      // Aceptar cualquier código 2xx como éxito
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        final data = response.data;
        
        // El backend puede retornar { isFavorite: true/false } o simplemente un mensaje
        if (data is Map<String, dynamic>) {
          if (data.containsKey('isFavorite')) {
            return data['isFavorite'] as bool;
          }
          // Si tiene 'message' o 'success', asumimos éxito
          if (data.containsKey('message') || data.containsKey('success')) {
            // Si el status es 201, se agregó; si es 200, puede ser toggle
            return response.statusCode == 201;
          }
        }
        
        // Si la respuesta es un string o null, asumimos éxito si el status es 2xx
        // Si el status es 201, se agregó; si es 200, puede ser que se removió
        return response.statusCode == 201;
      }

      // Si llegamos aquí, el status no es 2xx
      throw Exception(
        'Respuesta inesperada del servidor: status=${response.statusCode}, data=${response.data}'
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?.toString() ?? e.message ?? 'Error de conexión';
      
      AppLogger.error('[FavoritesService] Error DioException en toggleFavorite: status=$statusCode, message=$errorMessage');
      
      // Si es 404, el endpoint no existe
      if (statusCode == 404) {
        throw Exception('El endpoint de favoritos no está disponible en el servidor. Verifica que el backend tenga implementado /favorites/toggle/:songId');
      }
      
      // Si es 401, no está autenticado
      if (statusCode == 401) {
        throw Exception('Debes iniciar sesión para agregar favoritos');
      }
      
      ErrorHandler.handleDioError(e, context: 'FavoritesService.toggleFavorite');
      throw Exception('Error al actualizar favorito: $errorMessage');
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesService] Error en toggleFavorite: $e', stackTrace);
      ErrorHandler.handleGenericError(e, context: 'FavoritesService.toggleFavorite');
      rethrow;
    }
  }

  /// Obtener todas las canciones favoritas del usuario actual
  Future<List<Song>> getMyFavorites() async {
    try {
      await initialize();

      AppLogger.debug('[FavoritesService] Obteniendo favoritos del usuario');
      final response = await _dio.get('/favorites/my');

      AppLogger.debug('[FavoritesService] Respuesta getMyFavorites: status=${response.statusCode}, data type=${response.data.runtimeType}');

      // Aceptar cualquier código 2xx como éxito
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        // El backend puede retornar { songs: [...] } o directamente un array
        final songsData = ResponseParser.extractList(response, listKey: 'songs');

        AppLogger.debug('[FavoritesService] Canciones extraídas: ${songsData.length}');

        if (songsData.isEmpty) {
          // Si no hay canciones, retornar lista vacía (no es un error)
          return [];
        }

        return ResponseParser.parseList<Song>(
          data: songsData,
          parser: (json) {
            // Normalizar los datos antes de parsearlos
            final normalized = DataNormalizer.normalizeSong(json);
            return Song.fromJson(normalized);
          },
        );
      }

      // Si llegamos aquí, el status no es 2xx
      throw Exception(
        'Respuesta inesperada del servidor: status=${response.statusCode}, data=${response.data}'
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMessage = e.response?.data?.toString() ?? e.message ?? 'Error de conexión';
      
      AppLogger.error('[FavoritesService] Error DioException en getMyFavorites: status=$statusCode, message=$errorMessage');
      
      // Si es 404, puede ser que el endpoint no exista o el usuario no tenga favoritos
      if (statusCode == 404) {
        // Verificar si el mensaje indica que el endpoint no existe
        final responseData = e.response?.data?.toString().toLowerCase() ?? '';
        if (responseData.contains('not found') || responseData.contains('cannot')) {
          throw Exception('El endpoint de favoritos no está disponible en el servidor. Verifica que el backend tenga implementado /favorites/my');
        }
        // Si no, asumimos que el usuario simplemente no tiene favoritos
        AppLogger.debug('[FavoritesService] Usuario sin favoritos (404), retornando lista vacía');
        return [];
      }
      
      // Si es 401, no está autenticado
      if (statusCode == 401) {
        throw Exception('Debes iniciar sesión para ver tus favoritos');
      }
      
      ErrorHandler.handleDioError(e, context: 'FavoritesService.getMyFavorites');
      throw Exception('Error al cargar favoritos: $errorMessage');
    } catch (e, stackTrace) {
      AppLogger.error('[FavoritesService] Error en getMyFavorites: $e', stackTrace);
      ErrorHandler.handleGenericError(e, context: 'FavoritesService.getMyFavorites');
      rethrow;
    }
  }

  /// Verificar si una canción es favorita
  /// Esto se puede hacer verificando si está en la lista de favoritos
  /// o el backend puede tener un endpoint específico
  Future<bool> isFavorite(String songId) async {
    try {
      final favorites = await getMyFavorites();
      return favorites.any((song) => song.id == songId);
    } catch (e) {
      AppLogger.error('[FavoritesService] Error en isFavorite: $e');
      return false;
    }
  }
}

