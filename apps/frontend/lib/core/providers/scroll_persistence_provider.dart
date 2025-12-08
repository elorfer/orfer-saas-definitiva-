import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔥 PERSISTENCIA: Estado que mantiene los ScrollControllers persistentes
class ScrollControllersState {
  final Map<String, ScrollController> controllers;
  
  const ScrollControllersState({
    this.controllers = const {},
  });
  
  ScrollControllersState copyWith({
    Map<String, ScrollController>? controllers,
  }) {
    return ScrollControllersState(
      controllers: controllers ?? this.controllers,
    );
  }
}

/// 🔥 PERSISTENCIA: Notifier para mantener ScrollControllers persistentes
/// Los controllers NO se disponen al navegar, manteniendo el scroll intacto
class ScrollControllersNotifier extends Notifier<ScrollControllersState> {
  @override
  ScrollControllersState build() {
    return const ScrollControllersState();
  }

  /// Obtener o crear un ScrollController persistente
  ScrollController getController(String key, {double initialOffset = 0.0}) {
    if (!state.controllers.containsKey(key)) {
      // Crear nuevo controller con el offset inicial
      final controller = ScrollController(initialScrollOffset: initialOffset);
      state = state.copyWith(
        controllers: {...state.controllers, key: controller},
      );
      return controller;
    }
    
    // Controller ya existe - retornarlo directamente
    // El offset se restaurará desde PageStorage en didChangeDependencies
    return state.controllers[key]!;
  }

  /// Eliminar un controller (solo cuando realmente no se necesita más)
  void removeController(String key) {
    final ctrl = state.controllers[key];
    if (ctrl != null) {
      try {
        ctrl.dispose();
      } catch (_) {
        // Ignorar errores si ya está disposed
      }
    }
    final updatedControllers = Map<String, ScrollController>.from(state.controllers);
    updatedControllers.remove(key);
    state = state.copyWith(controllers: updatedControllers);
  }

  /// Limpiar todos los controllers (solo al cerrar la app)
  void disposeAll() {
    for (final ctrl in state.controllers.values) {
      try {
        ctrl.dispose();
      } catch (_) {
        // Ignorar errores
      }
    }
    state = const ScrollControllersState();
  }
}

/// 🔥 PERSISTENCIA: Provider para mantener ScrollControllers persistentes
final scrollControllersProvider = 
    NotifierProvider<ScrollControllersNotifier, ScrollControllersState>(() {
  return ScrollControllersNotifier();
});
