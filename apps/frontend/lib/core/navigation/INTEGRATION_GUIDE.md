# 🔥 Guía de Integración del Sistema de Persistencia

## Implementación Completa

Este documento explica cómo integrar el sistema de persistencia de pantallas en tu aplicación.

## Paso 1: Verificar que las pantallas tienen KeepAlive

Todas las pantallas principales deben tener `AutomaticKeepAliveClientMixin`:

### ✅ HomeScreen
```dart
class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ IMPORTANTE
    return Scaffold(...);
  }
}
```

### ✅ SearchScreen
```dart
class _SearchScreenState extends ConsumerState<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ IMPORTANTE
    return Scaffold(...);
  }
}
```

### ✅ LibraryScreen
```dart
class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ IMPORTANTE
    return Scaffold(...);
  }
}
```

### ✅ PremiumScreen
```dart
class _PremiumScreenState extends ConsumerState<PremiumScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ IMPORTANTE
    return Scaffold(...);
  }
}
```

## Paso 2: Usar ScrollController Persistente

En cada pantalla, usa el ScrollController del provider:

### HomeScreen
```dart
@override
void initState() {
  super.initState();
  // Usar el controller persistente
  _scrollController = ref.read(homeScrollControllerProvider);
}

@override
void dispose() {
  // NO hacer dispose del controller, el provider lo gestiona
  super.dispose();
}
```

### SearchScreen
```dart
@override
void initState() {
  super.initState();
  _scrollController = ref.read(searchScrollControllerProvider);
}
```

## Paso 3: Integrar en el Router

### Opción A: Reemplazar MainNavigation completamente

En `app_router.dart`, reemplaza el `ShellRoute`:

```dart
ShellRoute(
  builder: (context, state, child) {
    final path = state.matchedLocation;
    if (path == '/splash' || 
        path == '/login' || 
        path == '/register') {
      return child;
    }
    // Usar PersistentNavigation en lugar de MainNavigation
    return const PersistentNavigation();
  },
  routes: [
    // Las rutas /home, /search, /library, /premium ya no son necesarias
    // porque están dentro del IndexedStack
    // Pero mantén las otras rutas (playlists, artist, etc.)
  ],
),
```

### Opción B: Mantener compatibilidad con rutas

Si quieres mantener las rutas funcionando, puedes sincronizar el provider:

```dart
// En persistent_navigation.dart, método _navigateToTab:
void _navigateToTab(int index) {
  ref.read(navigationStateProvider.notifier).setIndex(index);
  
  // También actualizar la ruta (opcional)
  final routes = ['/home', '/search', '/library', '/premium'];
  if (index < routes.length) {
    context.go(routes[index]);
  }
}
```

## Paso 4: Sincronizar el índice con las rutas

Para mantener sincronización entre el provider y GoRouter, puedes agregar un listener:

```dart
// En persistent_navigation.dart, initState:
@override
void initState() {
  super.initState();
  
  // Sincronizar índice cuando cambia la ruta
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final router = GoRouter.of(context);
    final location = router.routerDelegate.currentConfiguration.uri.path;
    
    int index = 0;
    if (location == '/home' || location.startsWith('/home/')) {
      index = 0;
    } else if (location == '/search' || location.startsWith('/search')) {
      index = 1;
    } else if (location == '/library' || location.startsWith('/library')) {
      index = 2;
    } else if (location == '/premium' || location.startsWith('/premium')) {
      index = 3;
    }
    
    ref.read(navigationStateProvider.notifier).setIndex(index);
  });
}
```

## Resultado Final

✅ Al cambiar de Home → Search → Library → Home:
- El feed NO se reinicia
- El scroll NO vuelve a arriba  
- Los datos NO se recargan
- La UI es fluida y profesional
- Similar a Instagram, TikTok, YouTube, Facebook

## Notas Importantes

1. **No hacer dispose de ScrollController**: Los controllers son gestionados por el provider
2. **Llamar super.build()**: Es obligatorio cuando usas AutomaticKeepAliveClientMixin
3. **IndexedStack vs Navigator**: IndexedStack mantiene todas las pantallas en memoria, pero solo muestra una
4. **Memoria**: Este sistema usa más memoria, pero proporciona una UX superior









