import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔥 PERSISTENCIA: PageStorageBucket compartido a nivel de aplicación
/// Este bucket se mantiene durante toda la vida de la aplicación,
/// permitiendo que las posiciones de scroll se preserven entre navegaciones
final sharedPageStorageBucketProvider = Provider<PageStorageBucket>((ref) {
  return PageStorageBucket();
});
















