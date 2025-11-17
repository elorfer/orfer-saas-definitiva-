import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider simple para manejar el índice de navegación
final navigationIndexProvider = Provider.family<int, int>((ref, initialIndex) => initialIndex);

/// Provider para obtener el índice actual (por defecto 0)
final currentNavigationIndexProvider = Provider<int>((ref) => 0);
