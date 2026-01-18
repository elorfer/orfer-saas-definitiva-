
import 'dart:typed_data';

/// Implementación Mock de File para Web
class PlatformFile {
  final String path;
  PlatformFile(this.path);

  Future<bool> exists() async => false;
  Future<void> delete({bool recursive = false}) async {}
  Future<List<int>> readAsBytes() async => [];
  Future<PlatformFile> writeAsBytes(List<int> bytes, {dynamic mode, bool flush = false}) async => this;
  Future<int> length() async => 0;
  
  // Propiedades comunes
  String get parent => '';
}

/// Implementación Mock de Directory para Web
class PlatformDirectory {
  final String path;
  PlatformDirectory(this.path);

  Future<bool> exists() async => false;
  Future<PlatformDirectory> create({bool recursive = false}) async => this;
  Future<void> delete({bool recursive = false}) async {}
  List<FileSystemEntity> listSync({bool recursive = false}) => [];
}

class FileSystemEntity {
  String get path => '';
}
