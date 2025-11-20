import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../artists/models/artist.dart';

class ArtistsApi {
  final String baseUrl;
  final http.Client _client;
  final _logger = Logger();

  ArtistsApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: '${uri.path.replaceAll(RegExp(r'\/$'), '')}/public/artists$path',
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<List<ArtistLite>> getFeatured({int limit = 20}) async {
    final res = await _client.get(_u('/featured', {'limit': limit}));
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}');
    }
    final List data = json.decode(res.body) as List;
    return data.map((e) => ArtistLite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ArtistLite>> getTop({int limit = 20}) async {
    final res = await _client.get(_u('/top', {'limit': limit}));
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}');
    }
    final List data = json.decode(res.body) as List;
    return data.map((e) => ArtistLite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ArtistLite>> getPage({int page = 1, int limit = 20}) async {
    final res = await _client.get(_u('', {'page': page, 'limit': limit}));
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}');
    }
    final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;
    final List list = (data['artists'] as List?) ?? [];
    return list.map((e) => ArtistLite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getById(String id) async {
    _logger.d('🔍 Obteniendo artista con ID: $id');
    final res = await _client.get(_u('/$id', {'_t': DateTime.now().millisecondsSinceEpoch}));
    if (res.statusCode != 200) {
      _logger.e('❌ Error al obtener artista: ${res.statusCode}');
      throw Exception('Error ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    _logger.d('✅ Artista obtenido: ${data['id']} - ${data['name'] ?? data['stageName']}');
    return data;
  }

  Future<List<Map<String, dynamic>>> getSongsByArtist(String id, {int limit = 50}) async {
    _logger.d('🔍 Buscando canciones para artista ID: $id');
    final uri = Uri.parse(baseUrl);
    final songsUrl = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: '${uri.path.replaceAll(RegExp(r'\/$'), '')}/public/songs',
      queryParameters: {'artistId': id, 'limit': '$limit'},
    );
    _logger.d('📡 URL: ${songsUrl.toString()}');
    final res = await _client.get(songsUrl.replace(queryParameters: {
      ...songsUrl.queryParameters,
      '_t': '${DateTime.now().millisecondsSinceEpoch}',
    }));
    if (res.statusCode != 200) {
      _logger.e('❌ Error al obtener canciones: ${res.statusCode}');
      throw Exception('Error ${res.statusCode}');
    }
    final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;
    final List list = (data['songs'] as List?) ?? [];
    _logger.d('✅ Canciones obtenidas: ${list.length}');
    return list.cast<Map<String, dynamic>>();
  }
}


