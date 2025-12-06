// ignore_for_file: avoid_print
// Utilidad temporal para debuggear streams
// Nota: Remover después de verificar que funciona
import '../models/song_model.dart';

class DebugStreams {
  static void logSongStreams(Song song, {String context = ''}) {
    print('🎵 [DEBUG STREAMS] $context');
    print('   Song ID: ${song.id}');
    print('   Title: ${song.title}');
    print('   totalStreams: ${song.totalStreams}');
    print('   totalStreams type: ${song.totalStreams.runtimeType}');
    print('   totalStreams == 0: ${song.totalStreams == 0}');
  }
  
  static void logSongJson(Map<String, dynamic> json, {String context = ''}) {
    print('📦 [DEBUG JSON] $context');
    print('   Song ID: ${json['id']}');
    print('   Title: ${json['title']}');
    print('   totalStreams (raw): ${json['totalStreams']}');
    print('   total_streams (raw): ${json['total_streams']}');
    print('   totalStreams type: ${json['totalStreams']?.runtimeType}');
    print('   total_streams type: ${json['total_streams']?.runtimeType}');
    print('   All keys: ${json.keys.toList()}');
  }
}


