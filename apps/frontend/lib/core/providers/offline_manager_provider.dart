import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/song_model.dart';
import '../utils/logger.dart';

/// Estado del gestor de descargas
class OfflineState {
  final Map<String, Song> downloadedSongs; // Songs disponibles offline
  final Set<String> downloadingIds; // Songs en proceso de carga
  final Map<String, double> downloadProgress; // Progreso 0.0 - 1.0

  const OfflineState({
    this.downloadedSongs = const {},
    this.downloadingIds = const {},
    this.downloadProgress = const {},
  });

  OfflineState copyWith({
    Map<String, Song>? downloadedSongs,
    Set<String>? downloadingIds,
    Map<String, double>? downloadProgress,
  }) {
    return OfflineState(
      downloadedSongs: downloadedSongs ?? this.downloadedSongs,
      downloadingIds: downloadingIds ?? this.downloadingIds,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

/// Provider para el gestor de descargas y modo offline
class OfflineManagerNotifier extends Notifier<OfflineState> {
  static const String _boxName = 'offline_songs_v1';
  static const String _downloadDirName = 'offline_music';
  
  static const String _keyStorageKey = 'offline_mode_encryption_key_v1';
  late final encrypt.Encrypter _encrypter;
  // IV fijo para asegurar que lo que se encripta se pueda desencriptar tras reiniciar
  // (En producción ideal: guardar IV junto al archivo, pero para MVP usamos uno fijo de 16 bytes)
  static final _iv = encrypt.IV.fromUtf8('VintageMusicApp1'); // Exactly 16 chars = 16 bytes


  Box<String>? _box;
  Directory? _baseDir;
  final _secureStorage = const FlutterSecureStorage();

  @override
  OfflineState build() {
    _init();
    return const OfflineState();
  }

  Future<void> _init() async {
    try {
      // 1. Inicializar Secure Storage y Clave (Configuración Robusta)
      // Usamos la misma configuración que en AuthService para evitar conflictos
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: false,
          sharedPreferencesName: 'vintage_offline_key_store', 
          resetOnError: true,
        ),
      );

      String? keyBase64 = await secureStorage.read(key: _keyStorageKey);
      
      // Fallback: Si falla SecureStorage, intentar SharedPreferences estándar
      if (keyBase64 == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          keyBase64 = prefs.getString(_keyStorageKey);
          if (keyBase64 != null) {
            AppLogger.info('[OfflineManager] 🔐 Clave recuperada desde SharedPreferences (Fallback)');
          }
        } catch (e) {
          AppLogger.warning('[OfflineManager] Falló lectura de SharedPreferences: $e');
        }
      }

      encrypt.Key key;
      
      if (keyBase64 == null) {
        // Generar nueva clave segura
        key = encrypt.Key.fromSecureRandom(32);
        final newKeyBase64 = key.base64;
        
        // Guardar en ambos almacenamientos
        await secureStorage.write(key: _keyStorageKey, value: newKeyBase64);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyStorageKey, newKeyBase64);
        
        AppLogger.warning('[OfflineManager] ⚠️ Key not found. Generated NEW encryption key. (Old downloads will be unreadable)');
      } else {
        AppLogger.info('[OfflineManager] 🔐 Decryption key loaded successfully.');
        key = encrypt.Key.fromBase64(keyBase64);
      }
      _encrypter = encrypt.Encrypter(encrypt.AES(key));

      // 2. Inicializar Hive y Directorios
      _box = await Hive.openBox<String>(_boxName);
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = Directory(path.join(appDir.path, _downloadDirName));
      
      if (!await _baseDir!.exists()) {
        await _baseDir!.create(recursive: true);
      }

      _loadDownloadedSongs();
    } catch (e) {
      AppLogger.error('[OfflineManager] Init failed: $e');
    }
  }

  void _loadDownloadedSongs() {
    if (_box == null) {
      AppLogger.warning('[OfflineManager] ⚠️ Box is null in _loadDownloadedSongs');
      return;
    }
    
    AppLogger.info('[OfflineManager] 📦 Loading from Hive. Box Size: ${_box!.length}');
    final songs = <String, Song>{};
    for (var i = 0; i < _box!.length; i++) {
        final jsonStr = _box!.getAt(i);
        if (jsonStr != null) {
            try {
                // Loguear los primeros 100 caracteres para debug
                final debugStr = jsonStr.length > 100 ? jsonStr.substring(0, 100) + '...' : jsonStr;
                // AppLogger.debug('[OfflineManager] Parsing: $debugStr');
                
                final song = Song.fromJson(jsonDecode(jsonStr));
                songs[song.id] = song;
            } catch (e, stack) {
                AppLogger.error('[OfflineManager] ❌ Error deserializing song at index $i: $e', e, stack); 
            }
        }
    }
    AppLogger.info('[OfflineManager] ✅ Loaded ${songs.length} songs from disk.');
    state = state.copyWith(downloadedSongs: songs);
  }

  /// Descargar una canción
  Future<void> downloadSong(Song song) async {
    if (_box == null || _baseDir == null) await _init();
    if (state.downloadingIds.contains(song.id)) return; // Ya descargando
    if (state.downloadedSongs.containsKey(song.id)) return; // Ya descargada

    // Marcar como descargando
    final newDownloading = Set<String>.from(state.downloadingIds)..add(song.id);
    state = state.copyWith(downloadingIds: newDownloading);

    try {
      final dio = Dio();
      final url = song.fileUrl; // Asumimos URL válida
      
      if (url == null || url.isEmpty) throw Exception('URL inválida');

      // 1. Descargar bytes en memoria (buffer)
      // Nota: Para archivos muy grandes, sería mejor stream, pero canciones MP3 < 10MB ok en memoria.
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
            if (total != -1) {
                final progress = received / total;
                final newProgress = Map<String, double>.from(state.downloadProgress);
                newProgress[song.id] = progress;
                state = state.copyWith(downloadProgress: newProgress);
            }
        },
      );

      final bytes = Uint8List.fromList(response.data!);

      // 2. Encriptar
      final encrypted = _encrypter.encryptBytes(bytes, iv: _iv);

      // 3. Guardar en disco (.struky)
      final filePath = path.join(_baseDir!.path, '${song.id}.struky');
      final file = File(filePath);
      await file.writeAsBytes(encrypted.bytes);

      // 4. Guardar metadatos en Hive (Referencia al path local)
      // IMPORTANTE: Guardamos el path local en una propiedad 'localPath' o 'fileUrl' modificada?
      // Para evitar conflictos con el modelo Song inmutable, guardamos el original en Hive,
      // pero al servirlo inyectaremos el path.
      
      await _box!.put(song.id, jsonEncode(song.toJson()));

      // 5. Actualizar estado
      final newDownloaded = Map<String, Song>.from(state.downloadedSongs);
      newDownloaded[song.id] = song;
      
      final newDownloadingEnd = Set<String>.from(state.downloadingIds)..remove(song.id);
      final newProgressEnd = Map<String, double>.from(state.downloadProgress)..remove(song.id);

      state = state.copyWith(
        downloadedSongs: newDownloaded,
        downloadingIds: newDownloadingEnd,
        downloadProgress: newProgressEnd,
      );
      
      AppLogger.info('[OfflineManager] Downloaded & Encrypted: ${song.title}');

    } catch (e) {
      AppLogger.error('[OfflineManager] Download failed for ${song.title}: $e');
      // Limpieza de estado de error
      final newDownloadingError = Set<String>.from(state.downloadingIds)..remove(song.id);
      final newProgressError = Map<String, double>.from(state.downloadProgress)..remove(song.id);
      state = state.copyWith(downloadingIds: newDownloadingError, downloadProgress: newProgressError);
    }
  }

  /// Eliminar descarga
  Future<void> removeDownload(String songId) async {
    if (!state.downloadedSongs.containsKey(songId)) return;

    try {
        // Borrar archivo
        final filePath = path.join(_baseDir!.path, '$songId.struky');
        final file = File(filePath);
        if (await file.exists()) {
            await file.delete();
        }

        // Borrar de Hive
        await _box!.delete(songId);

        // Actualizar estado
        final newDownloaded = Map<String, Song>.from(state.downloadedSongs)..remove(songId);
        state = state.copyWith(downloadedSongs: newDownloaded);
        
        AppLogger.info('[OfflineManager] Removed: $songId');
    } catch (e) {
        AppLogger.error('[OfflineManager] Remove failed: $e');
    }
  }

  /// Eliminar TODAS las descargas
  Future<void> removeAllDownloads() async {
    try {
      if (_baseDir != null && await _baseDir!.exists()) {
        await _baseDir!.delete(recursive: true);
        await _baseDir!.create(); // Recrear directorio vacío
      }
      
      await _box?.clear();
      
      state = state.copyWith(
        downloadedSongs: {},
        downloadingIds: {},
        downloadProgress: {},
      );
      
      AppLogger.info('[OfflineManager] 🧹 All downloads removed');
    } catch (e) {
      AppLogger.error('[OfflineManager] Remove all failed: $e');
    }
  }

  /// Obtener archivo desencriptado (TEMPORAL) para reproducción
  /// Devuelve la ruta a un archivo temporal desencriptado.
  /// NOTA: Idealmente, el player leería stream desencriptado, pero just_audio requiere archivo o URL.
  Future<String?> getDecryptedFilePath(String songId) async {
      try {
          if (_baseDir == null) await _init();
          final encryptedPath = path.join(_baseDir!.path, '$songId.struky');
          final encryptedFile = File(encryptedPath);
          
          if (!await encryptedFile.exists()) return null;

          // Comprobar existencia en cache
          final tempDir = await getTemporaryDirectory();
          final tempPath = path.join(tempDir.path, '$songId.mp3');
          final tempFile = File(tempPath);
          
          if (!await tempFile.exists()) {
               AppLogger.info('[OfflineManager] Decrypting to temp: $tempPath');
               final encryptedBytes = await encryptedFile.readAsBytes();
               final decryptedBytes = _encrypter.decryptBytes(encrypt.Encrypted(encryptedBytes), iv: _iv);
               await tempFile.writeAsBytes(decryptedBytes);
          } else {
             // AppLogger.debug('[OfflineManager] Using cached decrypted file: $tempPath');
          }
          
          return tempPath;
          
      } catch (e) {
          AppLogger.error('[OfflineManager] Decryption failed: $e');
          return null;
      }
  }

  bool isDownloaded(String id) => state.downloadedSongs.containsKey(id);
  bool isDownloading(String id) => state.downloadingIds.contains(id);
  double getProgress(String id) => state.downloadProgress[id] ?? 0.0;
}

final offlineManagerProvider = NotifierProvider<OfflineManagerNotifier, OfflineState>(() {
  return OfflineManagerNotifier();
});
