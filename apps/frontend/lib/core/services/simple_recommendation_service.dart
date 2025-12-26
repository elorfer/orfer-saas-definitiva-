import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import 'http_client_service.dart';

/// Servicio SÚPER SIMPLE para recomendaciones por género
class SimpleRecommendationService {
  final Dio _dio = HttpClientService().dio;

  /// Obtener siguiente canción con el mismo género - MEJORADO
  Future<Song?> getNextSong(String currentSongId, List<String>? genres) async {
    try {
      AppLogger.info('[SimpleRecommendation] 🔍 MEJORADO: Buscando siguiente canción con género similar');
      AppLogger.info('[SimpleRecommendation] Canción actual ID: $currentSongId');
      AppLogger.info('[SimpleRecommendation] Géneros solicitados: ${genres?.join(', ') ?? 'ninguno'}');

      // Validar que tenemos géneros
      if (genres == null || genres.isEmpty) {
        AppLogger.warning('[SimpleRecommendation] ⚠️ Sin géneros proporcionados, el backend usará fallback');
      }

      // Llamar al endpoint público mejorado (sin autenticación)
      final response = await _dio.get(
        '/public/songs/recommended/$currentSongId',
        queryParameters: genres != null && genres.isNotEmpty 
          ? {'genres': genres} 
          : null,
      );

      AppLogger.info('[SimpleRecommendation] Respuesta del servidor: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        AppLogger.info('[SimpleRecommendation] Datos recibidos: ${data.toString()}');
        
        if (data['song'] != null) {
          final songData = Map<String, dynamic>.from(data['song']);
          
          // LOG PARA VER LA URL ORIGINAL
          AppLogger.info('[SimpleRecommendation] 🔍 URL original: ${songData['fileUrl']}');
          
          // CORREGIR URL DE ARCHIVO: cambiar localhost:3000 por localhost:3001
          if (songData['fileUrl'] != null) {
            String originalUrl = songData['fileUrl'].toString();
            if (originalUrl.contains('localhost:3000')) {
              songData['fileUrl'] = originalUrl.replaceAll('localhost:3000', 'localhost:3001');
              AppLogger.info('[SimpleRecommendation] 🔧 URL corregida de $originalUrl a ${songData['fileUrl']}');
            }
          }
          
          // VALIDAR QUE LA URL NO ESTÉ VACÍA O SEA NULL
          if (songData['fileUrl'] == null || songData['fileUrl'].toString().isEmpty) {
            AppLogger.error('[SimpleRecommendation] ❌ URL de archivo es null o vacía');
            return null;
          }
          
          final song = await Song.parse(songData);
          AppLogger.info('[SimpleRecommendation] ✅ ÉXITO: Siguiente canción encontrada');
          AppLogger.info('[SimpleRecommendation] 🎵 Título: ${song.title}');
          AppLogger.info('[SimpleRecommendation] 🏷️ Géneros de la recomendación: ${song.genres?.join(', ') ?? 'ninguno'}');
          AppLogger.info('[SimpleRecommendation] 👤 Artista: ${song.artist?.stageName ?? 'Desconocido'}');
          
          // Verificar si los géneros coinciden
          if (genres != null && genres.isNotEmpty && song.genres != null && song.genres!.isNotEmpty) {
            final hasMatchingGenre = genres.any((currentGenre) => 
              song.genres!.any((songGenre) => 
                songGenre.toLowerCase().contains(currentGenre.toLowerCase()) ||
                currentGenre.toLowerCase().contains(songGenre.toLowerCase())
              )
            );
            
            if (hasMatchingGenre) {
              AppLogger.info('[SimpleRecommendation] ✅ COINCIDENCIA DE GÉNERO CONFIRMADA');
            } else {
              AppLogger.warning('[SimpleRecommendation] ⚠️ Sin coincidencia de género (posible fallback)');
            }
          }
          
          return song;
        } else {
          AppLogger.warning('[SimpleRecommendation] ❌ Respuesta sin canción recomendada');
          AppLogger.info('[SimpleRecommendation] Mensaje del servidor: ${data['message'] ?? 'Sin mensaje'}');
          return null;
        }
      } else {
        AppLogger.warning('[SimpleRecommendation] ❌ Error HTTP: ${response.statusCode}');
        AppLogger.warning('[SimpleRecommendation] Respuesta: ${response.data}');
        return null;
      }
    } catch (e) {
      AppLogger.error('[SimpleRecommendation] ❌ Error de conexión o parsing: $e');
      return null;
    }
  }
}

/// Provider para el servicio
final simpleRecommendationServiceProvider = Provider<SimpleRecommendationService>((ref) {
  return SimpleRecommendationService();
});
