import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔥 SISTEMA PROFESIONAL DE PERSISTENCIA DE NAVEGACIÓN
/// 
/// Este provider gestiona el índice actual de navegación y mantiene
/// todas las pantallas vivas usando IndexedStack.
/// 
/// Comportamiento:
/// - Mantiene el estado de cada pantalla al cambiar de pestaña
/// - Evita reconstrucciones innecesarias
/// - Similar a Instagram, TikTok, YouTube, Facebook

/// Estado del índice de navegación
class NavigationState {
  final int currentIndex;
  
  const NavigationState({
    this.currentIndex = 0,
  });
  
  NavigationState copyWith({
    int? currentIndex,
  }) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

/// Notifier para gestionar el estado de navegación
class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() {
    return const NavigationState();
  }
  
  /// Cambiar al índice especificado
  void setIndex(int index) {
    if (index != state.currentIndex) {
      state = state.copyWith(currentIndex: index);
    }
  }
  
  /// Obtener el índice actual
  int get currentIndex => state.currentIndex;
}

/// Provider del estado de navegación
final navigationStateProvider = 
    NotifierProvider<NavigationNotifier, NavigationState>(() {
  return NavigationNotifier();
});

/// Provider para obtener el índice actual (más fácil de usar)
final currentNavigationIndexProvider = Provider<int>((ref) {
  return ref.watch(navigationStateProvider).currentIndex;
});

