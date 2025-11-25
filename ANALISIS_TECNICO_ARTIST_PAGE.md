# Análisis Técnico Profundo - ArtistPage

## 1. ✅ Verificación: ListView con shrinkWrap → SliverList

### Estado Actual:
```dart
SliverList(
  delegate: SliverChildBuilderDelegate(
    (context, index) {
      if (index.isOdd) return const Divider(...);
      final songIndex = index ~/ 2;
      return RepaintBoundary(child: _buildSongRow(...));
    },
    childCount: _songs.isEmpty ? 0 : (_songs.length * 2) - 1,
  ),
)
```

### ✅ CORRECTO:
- ✅ SliverList implementado correctamente
- ✅ Renderizado lazy (solo items visibles)
- ✅ Separadores integrados en el delegate
- ✅ RepaintBoundary en cada item

### ⚠️ PROBLEMAS DETECTADOS:

1. **Cálculo de childCount puede ser incorrecto:**
   ```dart
   childCount: _songs.isEmpty ? 0 : (_songs.length * 2) - 1
   ```
   - Si `_songs.length = 1`, childCount = 1 (correcto)
   - Si `_songs.length = 2`, childCount = 3 (correcto: canción, separador, canción)
   - ✅ Lógica correcta

2. **Normalización de URL en cada build de canción:**
   ```dart
   final songCover = s.coverArtUrl != null
       ? UrlNormalizer.normalizeImageUrl(s.coverArtUrl)
       : null;
   ```
   - ⚠️ Se ejecuta en cada rebuild de cada canción
   - ⚠️ Debería cachearse en el modelo Song o pre-procesarse

### 🔧 RECOMENDACIÓN:
- Pre-procesar URLs normalizadas al cargar las canciones
- Cachear URLs normalizadas en el estado

---

## 2. ⚠️ Verificación: Operaciones costosas fuera de build()

### Estado Actual:

**✅ BIEN HECHO:**
- Variables calculadas: `_effectiveName`, `_coverUrl`, `_profileUrl`, `_bio`, etc.
- Se actualizan solo cuando cambian los datos

**❌ PROBLEMA CRÍTICO DETECTADO:**

```dart
@override
Widget build(BuildContext context) {
  final currentUser = ref.watch(currentUserProvider);
  final bool isAdmin = currentUser?.isAdmin == true;
  
  // ⚠️ PROBLEMA: Recalcular bio y phone en build()
  if (_details != null) {
    final rawBio = ((_details?['biography'] as String?) ?? 
                   (_details?['bio'] as String?))?.trim();
    final newBio = _sanitizeBio(rawBio, isAdmin);
    if (newBio != _bio) {
      _bio = newBio; // ⚠️ Mutación de estado en build()
    }
    
    if (isAdmin) {
      final social = (_details?['socialLinks'] as Map<String, dynamic>?) ?? 
                     (_details?['social_links'] as Map<String, dynamic>?) ?? 
                     const <String, dynamic>{};
      _phone = (social['phone'] as String?)?.trim(); // ⚠️ Mutación en build()
    }
  }
}
```

### ❌ PROBLEMAS:
1. **Mutación de estado en build()** - Anti-pattern de Flutter
2. **Cálculo redundante** - Se ejecuta en cada rebuild
3. **Lógica condicional compleja** - Debería estar en `_updateCalculatedValues()`

### 🔧 SOLUCIÓN:
- Mover toda la lógica a `_updateCalculatedValues()`
- Usar `ref.listen` para detectar cambios en `currentUserProvider`
- O usar `useMemoized` de Riverpod

---

## 3. ✅ Verificación: Future.wait() y Race Conditions

### Estado Actual:
```dart
final results = await Future.wait([
  _api.getById(widget.artist.id),
  _api.getSongsByArtist(widget.artist.id, limit: 50),
]);
```

### ✅ CORRECTO:
- ✅ Implementación correcta de `Future.wait()`
- ✅ No hay race conditions (ambas usan el mismo `widget.artist.id`)
- ✅ Verificación de `mounted` antes de `setState()`

### ⚠️ MEJORA POSIBLE:
```dart
// Agregar timeout para evitar esperas infinitas
final results = await Future.wait([
  _api.getById(widget.artist.id),
  _api.getSongsByArtist(widget.artist.id, limit: 50),
]).timeout(
  const Duration(seconds: 30),
  onTimeout: () => throw TimeoutException('Timeout cargando datos del artista'),
);
```

---

## 4. ⚠️ Verificación: CachedNetworkImage - Optimización

### Estado Actual:
```dart
NetworkImageWithFallback(
  imageUrl: _coverUrl,
  fit: BoxFit.cover,
  useCachedImage: true,
)
```

### ⚠️ PROBLEMAS DETECTADOS:

1. **Falta cacheWidth y cacheHeight:**
   ```dart
   // En NetworkImageWithFallback, CachedNetworkImage no tiene:
   cacheWidth: (MediaQuery.of(context).size.width * 2).toInt(),
   cacheHeight: ((MediaQuery.of(context).size.width * 2.4) * 2).toInt(),
   ```

2. **Falta memCacheWidth y memCacheHeight:**
   - Reduce uso de memoria
   - Mejora rendimiento en scroll

3. **FadeInDuration puede ser optimizado:**
   - Actual: 200ms
   - Recomendado: 150ms para mejor percepción

### 🔧 RECOMENDACIÓN:
Modificar `NetworkImageWithFallback` para aceptar parámetros de caché:
```dart
final int? cacheWidth;
final int? cacheHeight;
```

Y pasarlos a `CachedNetworkImage`:
```dart
CachedNetworkImage(
  imageUrl: normalizedUrl,
  fit: fit,
  width: width,
  height: height,
  memCacheWidth: cacheWidth,
  memCacheHeight: cacheHeight,
  // ...
)
```

---

## 5. ⚠️ Verificación: RepaintBoundary - Ubicación

### Estado Actual:
- ✅ RepaintBoundary en header (portada + avatar)
- ✅ RepaintBoundary en biografía
- ✅ RepaintBoundary en contacto
- ✅ RepaintBoundary en cada canción

### ⚠️ PROBLEMAS:

1. **Exceso de RepaintBoundary:**
   - RepaintBoundary en secciones pequeñas que raramente cambian
   - Overhead innecesario

2. **Falta RepaintBoundary en:**
   - Título "Canciones" (cambia cuando se cargan datos)
   - Loading indicator (cambia frecuentemente)

### 🔧 RECOMENDACIÓN:
- Mantener RepaintBoundary solo en:
  - Header completo (portada + avatar)
  - Lista de canciones completa (no en cada item)
- Remover de secciones pequeñas que no cambian

---

## 6. ❌ Verificación: Procesamiento JSON fuera del UI Thread

### Estado Actual:
```dart
// Procesar JSON fuera del setState para mejor rendimiento
final songs = songsRaw.map((e) => Song.fromJson(e)).toList();
```

### ❌ PROBLEMA CRÍTICO:
- ⚠️ **NO está fuera del UI thread**
- ⚠️ `Song.fromJson()` se ejecuta en el UI thread
- ⚠️ Con 50 canciones, puede causar jank

### 🔧 SOLUCIÓN:
```dart
// Usar compute() para procesar en isolate
final songs = await compute(_parseSongs, songsRaw);

static List<Song> _parseSongs(List<Map<String, dynamic>> songsRaw) {
  return songsRaw.map((e) => Song.fromJson(e)).toList();
}
```

**IMPORTANTE:** `Song.fromJson` debe ser una función top-level o static para usar `compute()`.

---

## 7. ✅ Verificación: Reducción de setState()

### Estado Actual:
```dart
setState(() {
  _details = details;
  _songs = songs;
  _updateCalculatedValues();
  _loading = false;
});
```

### ✅ CORRECTO:
- ✅ Un solo `setState()` que actualiza todo
- ✅ `_updateCalculatedValues()` se llama dentro del setState

### ⚠️ MEJORA:
- `_updateCalculatedValues()` hace `ref.read()` que puede causar rebuilds
- Considerar pasar `isAdmin` como parámetro

---

## 8. ✅ Verificación: Mounted Checks

### Estado Actual:
```dart
if (!mounted) return;
setState(() { ... });
```

### ✅ CORRECTO:
- ✅ Verificaciones antes de cada `setState()`
- ✅ Verificación después de `Future.wait()`

### ⚠️ MEJORA:
Agregar verificación después de procesar JSON:
```dart
final songs = songsRaw.map((e) => Song.fromJson(e)).toList();
if (!mounted) return; // Agregar aquí también
```

---

## 9. ✅ Verificación: CustomScrollView + Slivers

### Estado Actual:
- ✅ CustomScrollView con Slivers correctamente implementado
- ✅ SliverToBoxAdapter para contenido fijo
- ✅ SliverList para lista lazy

### ⚠️ PROBLEMAS DETECTADOS:

1. **Falta cacheExtent:**
   ```dart
   CustomScrollView(
     cacheExtent: 500, // Agregar para mejor scroll
     slivers: [...]
   )
   ```

2. **Falta physics personalizado:**
   - Usar `ClampingScrollPhysics` o `BouncingScrollPhysics` según plataforma

---

## 10. ⚠️ Verificación: Widgets reconstruyéndose sin necesidad

### PROBLEMAS DETECTADOS:

1. **Normalización de URL en _buildSongRow:**
   ```dart
   final songCover = s.coverArtUrl != null
       ? UrlNormalizer.normalizeImageUrl(s.coverArtUrl)
       : null;
   ```
   - ⚠️ Se ejecuta en cada rebuild de cada canción
   - ⚠️ Debería pre-procesarse

2. **ref.watch en build():**
   ```dart
   final currentUser = ref.watch(currentUserProvider);
   ```
   - ⚠️ Causa rebuild cuando cambia el usuario
   - ⚠️ Pero la pantalla no necesita actualizarse si el usuario cambia

3. **Cálculo de _effectiveName en build:**
   ```dart
   _effectiveName ?? widget.artist.name
   ```
   - ✅ Ya está cacheado, pero se accede en múltiples lugares

### 🔧 SOLUCIÓN:
- Pre-procesar URLs al cargar canciones
- Usar `ref.read` en lugar de `ref.watch` si no necesitamos rebuilds
- Cachear `_effectiveName` y usarlo directamente

---

## 11. 🚀 Optimizaciones Adicionales Recomendadas

### A. Performance

1. **Lazy Loading de Imágenes:**
   ```dart
   // Usar ListView.builder con itemExtent para mejor scroll
   SliverFixedExtentList(
     itemExtent: 60.0, // Altura fija mejora rendimiento
     delegate: SliverChildBuilderDelegate(...)
   )
   ```

2. **Pre-cache de Imágenes:**
   ```dart
   // Pre-cachear portada y avatar antes de mostrar
   if (_coverUrl != null) {
     precacheImage(CachedNetworkImageProvider(_coverUrl!), context);
   }
   ```

3. **Debounce en Scroll:**
   - Si hay animaciones, usar `ScrollController` con debounce

### B. Arquitectura

1. **Usar Riverpod AsyncValue:**
   ```dart
   final artistProvider = FutureProvider.family<ArtistDetails, String>((ref, id) async {
     // Lógica de carga
   });
   ```
   - Mejor manejo de estados (loading, error, data)
   - Cache automático
   - Menos código manual

2. **Separar lógica de UI:**
   - Mover `_load()` a un provider
   - UI solo consume el estado

### C. Memoria

1. **Limitar número de canciones cargadas:**
   ```dart
   limit: 50 // Considerar paginación
   ```

2. **Dispose de imágenes:**
   - `CachedNetworkImage` ya maneja esto, pero verificar

3. **Limpiar listeners:**
   - No hay listeners manuales, ✅ correcto

### D. Estados

1. **Usar AutomaticKeepAliveClientMixin:**
   ```dart
   class _ArtistPageState extends ConsumerState<ArtistPage> 
       with AutomaticKeepAliveClientMixin {
     @override
     bool get wantKeepAlive => true;
     
     @override
     Widget build(BuildContext context) {
       super.build(context); // Importante
       // ...
     }
   }
   ```
   - Mantiene el estado al navegar

2. **PageStorageKey:**
   ```dart
   CustomScrollView(
     key: PageStorageKey('artist_${widget.artist.id}'),
     // ...
   )
   ```
   - Restaura posición de scroll

### E. Red

1. **Retry automático:**
   - Usar `RetryHandler` que ya existe en el proyecto

2. **Cache HTTP:**
   - Verificar que `ArtistsApi` use el cache HTTP configurado

3. **Compresión:**
   - Backend debería comprimir respuestas (gzip)

### F. Scroll

1. **Physics personalizado:**
   ```dart
   CustomScrollView(
     physics: const ClampingScrollPhysics(), // Android
     // o
     physics: const BouncingScrollPhysics(), // iOS
   )
   ```

2. **ScrollController:**
   ```dart
   final _scrollController = ScrollController();
   // Usar para animaciones o detección de scroll
   ```

### G. Painter

1. **Custom Painters:**
   - No necesario para esta pantalla

2. **RepaintBoundary optimizado:**
   - Ya implementado, pero puede optimizarse más

### H. Layout

1. **Const widgets:**
   - Ya hay muchos `const`, pero pueden agregarse más

2. **Evitar rebuilds innecesarios:**
   - Usar `ValueKey` en items de lista si cambian

---

## 12. ⚠️ Riesgos de Jank Detectados

### ALTO RIESGO:

1. **Procesamiento JSON en UI thread:**
   - ⚠️ Con 50 canciones, puede causar jank de 50-100ms
   - **Solución:** Usar `compute()`

2. **Normalización de URLs en build:**
   - ⚠️ Se ejecuta múltiples veces
   - **Solución:** Pre-procesar

3. **Carga inicial de imágenes:**
   - ⚠️ Portada grande sin cache puede causar jank
   - **Solución:** Pre-cache o usar placeholder mejor

### MEDIO RIESGO:

1. **Rebuilds por ref.watch:**
   - ⚠️ Cambios en `currentUserProvider` causan rebuilds
   - **Solución:** Usar `ref.read` o `select`

2. **Scroll con muchas imágenes:**
   - ⚠️ Si hay muchas canciones, scroll puede ser laggy
   - **Solución:** Lazy loading + cache de imágenes

---

## 13. 🔧 AutomaticKeepAliveClientMixin y PageStorageKey

### RECOMENDACIÓN: SÍ USAR

**AutomaticKeepAliveClientMixin:**
- ✅ Mantiene el estado al navegar
- ✅ Evita recargar datos al volver
- ✅ Mejor UX

**PageStorageKey:**
- ✅ Restaura posición de scroll
- ✅ Mejor UX al volver a la pantalla

**Implementación:**
```dart
class _ArtistPageState extends ConsumerState<ArtistPage> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: CustomScrollView(
        key: PageStorageKey('artist_${widget.artist.id}'),
        // ...
      ),
    );
  }
}
```

---

## 14. 🔍 Detección de Leaks y Listeners

### ✅ NO HAY LEAKS DETECTADOS:

1. **No hay StreamControllers:**
   - ✅ No hay streams manuales

2. **No hay AnimationControllers:**
   - ✅ No hay animaciones manuales

3. **No hay TextEditingControllers:**
   - ✅ No hay campos de texto

4. **No hay FocusNodes:**
   - ✅ No hay campos de texto

5. **No hay listeners manuales:**
   - ✅ Solo `ref.watch` que Riverpod maneja automáticamente

### ⚠️ VERIFICAR:

1. **ArtistsApi:**
   - Verificar que `http.Client` se cierre correctamente
   - Si es singleton, está bien

2. **Logger:**
   - Verificar que no acumule logs en memoria
   - Usar nivel de log apropiado

---

## 📊 Resumen de Problemas Críticos

### 🔴 CRÍTICOS (Deben arreglarse):

1. **Mutación de estado en build()** (líneas 139-153)
2. **Procesamiento JSON en UI thread** (línea 108)
3. **Normalización de URL en cada rebuild** (línea 449)

### 🟡 IMPORTANTES (Mejoran rendimiento):

1. **Falta cacheWidth/cacheHeight en imágenes**
2. **Exceso de RepaintBoundary**
3. **ref.watch causa rebuilds innecesarios**

### 🟢 OPCIONALES (Nice to have):

1. **AutomaticKeepAliveClientMixin**
2. **PageStorageKey**
3. **Pre-cache de imágenes**
4. **Timeout en Future.wait**

---

## 🎯 Prioridad de Optimizaciones

1. **P1 - Crítico:** Arreglar mutación en build()
2. **P1 - Crítico:** Mover procesamiento JSON a isolate
3. **P1 - Crítico:** Pre-procesar URLs normalizadas
4. **P2 - Importante:** Optimizar CachedNetworkImage
5. **P2 - Importante:** Reducir RepaintBoundary
6. **P3 - Opcional:** AutomaticKeepAliveClientMixin
7. **P3 - Opcional:** PageStorageKey




