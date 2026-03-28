import 'dart:convert';
import '../utils/universal_file.dart';
import '../utils/platform_utils.dart';
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
/// 🔒 PROFESIONAL: Soporta separación de datos por usuario
class OfflineManagerNotifier extends Notifier<OfflineState> {
  static const String _boxNamePrefix = 'offline_songs_v2'; // v2 para nueva estructura
  static const String _downloadDirName = 'offline_music';
  
  static const String _keyStorageKey = 'offline_mode_encryption_key_v1';
  encrypt.Encrypter? _encrypter;
  // IV fijo para asegurar que lo que se encripta se pueda desencriptar tras reiniciar
  // (En producción ideal: guardar IV junto al archivo, pero para MVP usamos uno fijo de 16 bytes)
  static final _iv = encrypt.IV.fromUtf8('VintageMusicApp1'); // Exactly 16 chars = 16 bytes

  // 🔒 ID del usuario actual - CRÍTICO para separación de datos
  String? _currentUserId;

  Box<String>? _box;
  PlatformDirectory? _baseDir;
  bool _isInitialized = false;

  @override
  OfflineState build() {
    // NO inicializar automáticamente - esperar a que se establezca el userId
    return const OfflineState();
  }

  /// 🔒 Inicializar para un usuario específico
  /// DEBE ser llamado cuando un usuario inicia sesión
  Future<void> initializeForUser(String userId) async {
    if (_currentUserId == userId && _isInitialized) {
      AppLogger.debug('[OfflineManager] Ya inicializado para usuario: $userId');
      return;
    }

    AppLogger.info('[OfflineManager] 🔑 Inicializando para usuario: $userId');
    
    // Si había un usuario anterior, cerrar su sesión primero
    if (_currentUserId != null && _currentUserId != userId) {
      await closeCurrentUserSession();
    }

    _currentUserId = userId;
    await _init();
  }

  /// Cerrar sesión del usuario actual (sin eliminar sus datos)
  Future<void> closeCurrentUserSession() async {
    try {
      AppLogger.info('[OfflineManager] 🔄 Cerrando sesión de usuario: $_currentUserId');
      
      // Cerrar Hive box si está abierto
      if (_box != null && _box!.isOpen) {
        await _box!.close();
        _box = null;
      }
      
      // Limpiar estado
      state = const OfflineState();
      _baseDir = null;
      _isInitialized = false;
      
      AppLogger.debug('[OfflineManager] ✅ Sesión cerrada correctamente');
    } catch (e) {
      AppLogger.error('[OfflineManager] Error cerrando sesión: $e');
    }
  }

  /// 🗑️ Eliminar TODOS los datos del usuario actual
  /// Solo usar al cerrar sesión si quieres borrar las descargas
  Future<void> clearCurrentUserData() async {
    if (_currentUserId == null) {
      AppLogger.warning('[OfflineManager] No hay usuario activo para limpiar');
      return;
    }

    try {
      AppLogger.info('[OfflineManager] 🧹 Eliminando datos de usuario: $_currentUserId');
      
      // Eliminar directorio del usuario
      if (_baseDir != null && await _baseDir!.exists()) {
        await _baseDir!.delete(recursive: true);
      }
      
      // Eliminar y cerrar Hive box del usuario
      if (_box != null) {
        final boxName = _getUserBoxName(_currentUserId!);
        await _box!.clear();
        await _box!.close();
        await Hive.deleteBoxFromDisk(boxName);
        _box = null;
      }
      
      // Limpiar estado
      state = const OfflineState();
      _isInitialized = false;
      
      AppLogger.info('[OfflineManager] ✅ Datos eliminados correctamente');
    } catch (e) {
      AppLogger.error('[OfflineManager] Error eliminando datos: $e');
    }
  }

  /// Obtener nombre del Hive Box para un usuario específico
  String _getUserBoxName(String userId) {
    // Sanitizar userId para nombre de archivo seguro
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${_boxNamePrefix}_$safeUserId';
  }

  /// Obtener directorio de descargas para un usuario específico
  String _getUserDownloadDir(PlatformDirectory appDir, String userId) {
    // Sanitizar userId para nombre de directorio seguro
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return path.join(appDir.path, _downloadDirName, safeUserId);
  }

  Future<void> _init() async {
    if (_currentUserId == null) {
      AppLogger.warning('[OfflineManager] ⚠️ No se puede inicializar sin userId');
      return;
    }

    if (PlatformUtils.isWeb) {
      AppLogger.info('[OfflineManager] 🌐 Web Mode: Offline downloads disabled');
      return;
    }

    try {
      AppLogger.info('[OfflineManager] 🚀 Inicializando para usuario: $_currentUserId');

      // 1. Inicializar Secure Storage y Clave (Configuración Robusta)
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
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
        try {
          key = encrypt.Key.fromBase64(keyBase64);
          AppLogger.info('[OfflineManager] 🔐 Decryption key loaded successfully.');
        } catch (e) {
          AppLogger.error('[OfflineManager] ❌ Corrupted key found. Regenerating...');
          key = encrypt.Key.fromSecureRandom(32);
          final newKeyBase64 = key.base64;
          await secureStorage.write(key: _keyStorageKey, value: newKeyBase64);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyStorageKey, newKeyBase64);
          AppLogger.warning('[OfflineManager] ⚠️ Generated NEW encryption key after corruption.');
        }
      }
      _encrypter ??= encrypt.Encrypter(encrypt.AES(key));

      // 2. Inicializar Hive Box específico del usuario
      final boxName = _getUserBoxName(_currentUserId!);
      _box = await Hive.openBox<String>(boxName);
      AppLogger.info('[OfflineManager] 📦 Hive box abierto: $boxName');

      // 3. Inicializar directorio específico del usuario
      final appDir = await getApplicationDocumentsDirectory();
      final userDirPath = _getUserDownloadDir(PlatformDirectory(appDir.path), _currentUserId!);
      _baseDir = PlatformDirectory(userDirPath);
      
      if (!await _baseDir!.exists()) {
        await _baseDir!.create(recursive: true);
        AppLogger.info('[OfflineManager] 📁 Directorio creado: $userDirPath');
      }

      _loadDownloadedSongs();
      _isInitialized = true;
      
      AppLogger.info('[OfflineManager] ✅ Inicialización completada para usuario: $_currentUserId');
    } catch (e, stackTrace) {
      AppLogger.error('[OfflineManager] ❌ Init failed: $e', e, stackTrace);
      _isInitialized = false;
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
                final song = Song.fromJson(jsonDecode(jsonStr));
                songs[song.id] = song;
            } catch (e, stack) {
                AppLogger.error('[OfflineManager] ❌ Error deserializing song at index $i: $e', e, stack); 
            }
        }
    }
    AppLogger.info('[OfflineManager] ✅ Loaded ${songs.length} songs from disk for user: $_currentUserId');
    state = state.copyWith(downloadedSongs: songs);
  }

  /// Descargar una canción
  Future<void> downloadSong(Song song) async {
    if (_currentUserId == null || !_isInitialized) {
      AppLogger.error('[OfflineManager] ❌ No se puede descargar sin usuario inicializado');
      return;
    }

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

      // 1. Descargar bytes en memoria
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
      final encrypted = _encrypter!.encryptBytes(bytes, iv: _iv);

      // 3. Guardar en disco (.struky)
      final filePath = path.join(_baseDir!.path, '${song.id}.struky');
      final file = PlatformFile(filePath);
      await file.writeAsBytes(encrypted.bytes);

      // 4. Guardar metadatos en Hive
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
      
      AppLogger.info('[OfflineManager] ✅ Downloaded & Encrypted: ${song.title} (User: $_currentUserId)');

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
        final file = PlatformFile(filePath);
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

  /// Eliminar TODAS las descargas del usuario actual
  @Deprecated('Use clearCurrentUserData() para eliminar datos al cerrar sesión')
  Future<void> removeAllDownloads() async {
    await clearCurrentUserData();
  }

  /// Obtener archivo desencriptado (TEMPORAL) para reproducción
  Future<String?> getDecryptedFilePath(String songId) async {
      try {
          if (_baseDir == null) await _init();
          final encryptedPath = path.join(_baseDir!.path, '$songId.struky');
          final encryptedFile = PlatformFile(encryptedPath);
          
          if (!await encryptedFile.exists()) return null;

          // Comprobar existencia en cache
          final tempDir = await getTemporaryDirectory();
          final tempPath = path.join(tempDir.path, '$songId.mp3');
          final tempFile = PlatformFile(tempPath);
          
          if (!await tempFile.exists()) {
               AppLogger.info('[OfflineManager] Decrypting to temp: $tempPath');
               final encryptedBytes = await encryptedFile.readAsBytes();
                final decryptedBytes = _encrypter!.decryptBytes(encrypt.Encrypted(Uint8List.fromList(encryptedBytes)), iv: _iv);
               await tempFile.writeAsBytes(decryptedBytes);
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
