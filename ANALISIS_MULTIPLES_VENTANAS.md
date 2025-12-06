# Análisis: Manejo de Múltiples Ventanas Abiertas

## Problemas Identificados

### 1. **Mezcla de Sistemas de Navegación** ⚠️ CRÍTICO

**Problema:**
- La aplicación usa `go_router` como sistema principal de navegación
- Pero `SongDetailScreen.navigateToSong()` usa `Navigator.push()` con `MaterialPageRoute`
- Esto crea **dos stacks de navegación separados** que no están sincronizados

**Ubicaciones afectadas:**
- `apps/frontend/lib/features/song_detail/screens/song_detail_screen.dart` (líneas 42-86)
- `apps/frontend/lib/features/home/widgets/intelligent_featured_songs_section.dart` (líneas 445-463)
- `apps/frontend/lib/features/home/widgets/featured_songs_section.dart` (líneas 274-290)
- `apps/frontend/lib/features/artists/pages/artist_page.dart` (línea 173-178)

**Consecuencias:**
- El botón de retroceso puede no funcionar correctamente
- Pueden existir múltiples instancias de la misma pantalla en memoria
- El estado de navegación se vuelve inconsistente
- Problemas con el manejo del ciclo de vida de widgets

### 2. **Protección Insuficiente Contra Duplicados**

**Problema:**
`SongDetailScreen.navigateToSong()` tiene protección básica pero:
- Solo verifica la ruta actual (`currentRouteName`)
- No verifica si ya existe una instancia en el stack completo
- El debounce de 500ms puede ser insuficiente en conexiones rápidas
- No limpia pantallas duplicadas existentes

**Código actual:**
```dart
// Solo verifica la ruta actual, no el stack completo
if (currentRouteName == routeName) return;
```

### 3. **Falta de Limpieza del Stack**

**Problema:**
- Cuando se navega a una canción que ya está abierta, debería volver a esa pantalla
- Actualmente crea una nueva instancia en lugar de reutilizar la existente
- No hay mecanismo para limpiar pantallas duplicadas del stack

### 4. **Cache Estático Puede Acumularse**

**Problema en `ArtistPage`:**
- Usa cache estático (`_artistCache`) que puede acumularse
- La limpieza solo ocurre cuando hay más de 10 entradas
- No hay límite máximo de memoria

**Código actual:**
```dart
static final Map<String, Map<String, dynamic>> _artistCache = {};

// Limpiar solo si hay más de 10 entradas
if (_artistCache.length > 10) {
  // limpiar...
}
```

## Soluciones Propuestas

### Solución 1: Unificar Navegación con go_router ✅ RECOMENDADO

**Cambios necesarios:**

1. **Agregar ruta para SongDetailScreen en go_router:**
```dart
// En app_router.dart
GoRoute(
  path: '/song/:id',
  pageBuilder: (context, state) {
    final songId = state.pathParameters['id'] ?? '';
    final song = state.extra as Song?;
    if (song == null) {
      // Redirigir si no hay canción
      return CustomTransitionPage<void>(
        key: state.pageKey,
        child: const HomeScreen(),
      );
    }
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: SongDetailScreen(song: song),
      transitionsBuilder: SpotifyPageTransitions.horizontalTransition,
      transitionDuration: const Duration(milliseconds: 200),
    );
  },
),
```

2. **Modificar `SongDetailScreen.navigateToSong()` para usar go_router:**
```dart
static void navigateToSong(BuildContext context, Song song) {
  if (!context.mounted) return;
  
  final router = GoRouter.of(context);
  final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
  final targetLocation = '/song/${song.id}';
  
  // Si ya estamos en esa pantalla, no hacer nada
  if (currentLocation == targetLocation) return;
  
  // Verificar si la canción ya está en el stack
  final canPop = router.canPop();
  if (canPop) {
    // Intentar encontrar si ya existe en el stack
    final navigator = Navigator.of(context);
    // Si podemos hacer pop y volver a la misma canción, hacerlo
    // (esto requiere verificación adicional del stack)
  }
  
  // Navegar usando go_router
  context.push(targetLocation, extra: song);
}
```

### Solución 2: Mejorar Protección Contra Duplicados

**Implementar verificación del stack completo:**

```dart
static void navigateToSong(BuildContext context, Song song) {
  if (!context.mounted) return;
  
  // Debounce mejorado
  final now = DateTime.now();
  if (_lastNavigationTime != null && 
      _lastNavigatedSongId == song.id &&
      now.difference(_lastNavigationTime!) < const Duration(milliseconds: 300)) {
    return;
  }
  
  _lastNavigationTime = now;
  _lastNavigatedSongId = song.id;
  
  // Verificar stack completo usando Navigator
  final navigator = Navigator.of(context);
  final routeName = '/song_detail/${song.id}';
  
  // Intentar encontrar ruta existente en el stack
  bool routeExists = false;
  navigator.popUntil((route) {
    if (route.settings.name == routeName) {
      routeExists = true;
      return true; // Detener aquí
    }
    return false; // Continuar buscando
  });
  
  if (routeExists) {
    // Ya existe, no crear nueva
    return;
  }
  
  // Si no existe, crear nueva
  navigator.push(
    MaterialPageRoute(
      builder: (context) => SongDetailScreen(song: song),
      settings: RouteSettings(name: routeName, arguments: song),
    ),
  );
}
```

### Solución 3: Limitar Cache de ArtistPage

**Mejorar gestión de memoria:**

```dart
// Limitar cache a máximo 5 artistas
static const int _maxCacheSize = 5;

static void _cleanOldCache() {
  final now = DateTime.now();
  final expiredKeys = <String>[];
  
  _artistCache.forEach((key, value) {
    final lastLoad = value['lastLoadTime'] as DateTime?;
    if (lastLoad != null && now.difference(lastLoad) > _cacheValidDuration) {
      expiredKeys.add(key);
    }
  });
  
  // Limpiar siempre que haya más del máximo permitido
  if (_artistCache.length > _maxCacheSize) {
    // Ordenar por fecha de acceso y eliminar los más antiguos
    final sortedEntries = _artistCache.entries.toList()
      ..sort((a, b) {
        final aTime = a.value['lastLoadTime'] as DateTime? ?? DateTime(1970);
        final bTime = b.value['lastLoadTime'] as DateTime? ?? DateTime(1970);
        return aTime.compareTo(bTime);
      });
    
    // Eliminar los más antiguos hasta llegar al límite
    for (int i = 0; i < sortedEntries.length - _maxCacheSize; i++) {
      _artistCache.remove(sortedEntries[i].key);
    }
  }
  
  // También limpiar expirados
  for (final key in expiredKeys) {
    _artistCache.remove(key);
  }
}
```

### Solución 4: Agregar PopScope para Manejo de Retroceso

**En SongDetailScreen y ArtistPage:**

```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: true,
    onPopInvoked: (didPop) {
      if (didPop) {
        // Limpiar recursos específicos si es necesario
        _cleanupResources();
      }
    },
    child: Scaffold(
      // ... resto del código
    ),
  );
}
```

## Recomendaciones de Implementación

### Prioridad Alta 🔴
1. **Unificar navegación con go_router** - Elimina problemas de sincronización
2. **Mejorar protección contra duplicados** - Previene múltiples instancias

### Prioridad Media 🟡
3. **Limitar cache de ArtistPage** - Previene acumulación de memoria
4. **Agregar PopScope** - Mejor manejo del ciclo de vida

### Prioridad Baja 🟢
5. **Agregar logging** - Para debugging de problemas de navegación
6. **Tests de navegación** - Asegurar que no se creen duplicados

## Archivos a Modificar

1. `apps/frontend/lib/core/navigation/app_router.dart` - Agregar ruta para SongDetailScreen
2. `apps/frontend/lib/features/song_detail/screens/song_detail_screen.dart` - Cambiar a go_router
3. `apps/frontend/lib/features/artists/pages/artist_page.dart` - Mejorar cache y navegación
4. `apps/frontend/lib/features/home/widgets/intelligent_featured_songs_section.dart` - Usar go_router
5. `apps/frontend/lib/features/home/widgets/featured_songs_section.dart` - Usar go_router

## Notas Adicionales

- **go_router** maneja automáticamente el stack de navegación
- **MaterialPageRoute** crea su propio stack que puede causar inconsistencias
- La solución recomendada es migrar completamente a go_router para consistencia












