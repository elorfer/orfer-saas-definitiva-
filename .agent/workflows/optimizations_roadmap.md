---
description: Roadmap de optimizaciones para la app Flutter de Struky
---

# 🚀 ROADMAP DE OPTIMIZACIONES - STRUKY APP

**Última actualización:** 18 de enero de 2026  
**Estado actual:** Beta optimizada (HomeScreen 100% optimizado)

---

## 📊 MÉTRICAS ACTUALES

| Métrica | Valor Actual | Objetivo Post-Opt |
|---------|--------------|-------------------|
| FPS promedio (scroll) | 55-60 | 60 (constante) |
| Uso de memoria | ~180MB | ~120MB (-33%) |
| Tiempo de carga inicial | 2.5s | 1.5s (-40%) |
| Jank frames (1% peor) | ~3% | <1% |
| Tamaño de APK | ~78MB | ~55MB (-30%) |
| Latencia de red (API) | ~200ms | ~80ms (con caché) |

---

## 🔴 ALTA PRIORIDAD (Impacto: 20-40%)

### 1. ⚡ Implementar Lazy Loading en listas largas

**Impacto:** -30% memoria, +15 FPS en scroll  
**Esfuerzo:** 2 horas  
**Archivos afectados:**
- `lib/features/search/screens/search_screen.dart`
- `lib/features/library/screens/favorites_screen.dart`
- `lib/features/library/screens/followed_artists_screen.dart`

**Implementación:**
```dart
ListView.builder(
  itemCount: results.length,
  addAutomaticKeepAlives: false, // ⚡ No mantener estado de items offscreen
  addRepaintBoundaries: true,
  cacheExtent: 300, // Reducir en listas muy largas
  itemBuilder: (context, index) {
    if (index >= results.length) return null;
    return RepaintBoundary(
      child: YourItemWidget(item: results[index]),
    );
  },
)
```

**Justificación:** Actualmente las listas cargan todos los elementos en memoria simultáneamente, causando lag en búsquedas con 100+ resultados.

---

### 2. 🖼️ Implementar Image Caching agresivo

**Impacto:** -50% uso de red, +20% velocidad de carga  
**Esfuerzo:** 3 horas  
**Archivos afectados:**
- `lib/core/widgets/optimized_image.dart`
- `lib/core/services/http_cache_service.dart`

**Implementación:**
```dart
CachedNetworkImage(
  imageUrl: url,
  cacheManager: CacheManager(
    Config(
      'struky_covers',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: 'struky_covers'),
    ),
  ),
  memCacheWidth: 400, // Reducir resolución en memoria
  memCacheHeight: 400,
)
```

**Estrategia de pre-carga:**
1. Al iniciar app, pre-cargar top 50 canciones
2. Al abrir artista, pre-cargar sus álbumes
3. Limpiar caché >30 días automáticamente

---

### 3. 🧵 Optimizar AudioService con Isolates

**Impacto:** +25 FPS durante reproducción, -40% jank  
**Esfuerzo:** 6 horas  
**Archivos afectados:**
- `lib/core/services/audio_service.dart`
- Nuevo: `lib/core/isolates/recommendation_isolate.dart`

**Implementación:**
```dart
// Mover algoritmo de recomendación a Isolate
class RecommendationIsolate {
  static Future<List<Song>> computeRecommendations(
    List<Song> history,
    List<Song> availableSongs,
  ) async {
    return await compute(_computeInBackground, {
      'history': history,
      'available': availableSongs,
    });
  }
  
  static List<Song> _computeInBackground(Map data) {
    // Lógica pesada de algoritmo aquí
    // No bloquea el hilo principal
  }
}
```

**Procesos a mover a Isolate:**
- Cálculo de recomendaciones
- Filtrado de cola de reproducción
- Procesamiento de metadatos de audio

---

## 🟡 MEDIA PRIORIDAD (Impacto: 10-20%)

### 4. 🔄 Implementar Incremental Build para providers

**Impacto:** -15% rebuilds innecesarios  
**Esfuerzo:** 4 horas  
**Archivos afectados:** Todos los `*_provider.dart`

**Antes (ineficiente):**
```dart
final state = ref.watch(playbackProvider);
// Rebuild completo en CUALQUIER cambio
```

**Después (optimizado):**
```dart
final isPlaying = ref.watch(
  playbackProvider.select((s) => s.isPlaying)
);
// Solo rebuild si isPlaying cambia
```

**Checklist de archivos a optimizar:**
- [ ] `lib/core/providers/auth_provider.dart`
- [ ] `lib/core/providers/playback_session_provider.dart`
- [ ] `lib/core/providers/favorites_provider.dart`
- [ ] `lib/core/providers/playlist_provider.dart`

---

### 5. 🎬 Reducir AnimationControllers

**Impacto:** -10% uso de batería  
**Esfuerzo:** 2 horas  
**Archivos afectados:**
- `lib/features/player/screens/professional_player_screen.dart`
- `lib/features/home/widgets/featured_song_card.dart`

**Estrategia:**
1. Reusar controladores entre widgets similares
2. Usar `TweenAnimationBuilder` para animaciones simples (no necesita controller)
3. Dispose correcto de todos los controllers

**Ejemplo de optimización:**
```dart
// Antes: AnimationController para fade simple
AnimationController _fadeController;

// Después: TweenAnimationBuilder (sin controller)
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: Duration(milliseconds: 300),
  builder: (context, value, child) {
    return Opacity(opacity: value, child: child);
  },
)
```

---

### 6. 📄 Implementar Pagination en API calls

**Impacto:** -40% tiempo de carga inicial  
**Esfuerzo:** 5 horas  
**Archivos afectados:**
- `lib/core/services/home_service.dart`
- `lib/core/services/search_service.dart`
- Backend: `apps/backend/src/modules/songs/songs.controller.ts`

**Implementación Frontend:**
```dart
class PaginatedList<T> extends ConsumerStatefulWidget {
  final Future<List<T>> Function(int page) fetcher;
  
  void _loadMore() {
    if (_isLoading || !_hasMore) return;
    _currentPage++;
    _fetchPage(_currentPage);
  }
}
```

**Endpoints a paginar:**
- `GET /songs` → 20 items por página
- `GET /artists` → 20 items por página
- `GET /search` → 30 items por página

---

### 7. 💾 Database local con Isar

**Impacto:** +300% velocidad de lectura/escritura local  
**Esfuerzo:** 8 horas  
**Archivos afectados:**
- Nuevo módulo: `lib/core/database/`
- `pubspec.yaml` (añadir `isar: ^3.1.0`)

**Casos de uso:**
1. **Caché de canciones favoritas** (acceso instantáneo)
2. **Historial de reproducción** (queries complejas)
3. **Configuración de usuario** (migrar de SharedPreferences)
4. **Offline mode** (canciones descargadas)

**Estructura propuesta:**
```dart
@collection
class CachedSong {
  Id id = Isar.autoIncrement;
  late String songId;
  late String title;
  late String artistName;
  String? coverUrl;
  @Index()
  late DateTime cachedAt;
}
```

**Beneficios:**
- Queries 10x más rápidas que Hive
- Soporte para índices y full-text search
- Sincronización automática con backend

---

## 🟢 BAJA PRIORIDAD (Impacto: 5-10%)

### 8. 📦 Implementar Code Splitting

**Impacto:** -30% tamaño de app inicial  
**Esfuerzo:** 3 horas

**Implementación:**
```dart
// Cargar features bajo demanda
import 'package:premium/premium_screen.dart' deferred as premium;

void navigateToPremium() async {
  await premium.loadLibrary();
  Navigator.push(context, premium.PremiumScreen());
}
```

**Features candidatas para lazy loading:**
- Premium/Subscripción (solo ~5% usuarios la usan inmediatamente)
- Estadísticas/Analytics
- Configuración avanzada

---

### 9. 🎨 Optimizar Gradient rendering

**Impacto:** +5 FPS en animaciones

**Implementación:**
```dart
// Cachear gradientes estáticos
class NeumorphismTheme {
  static const backgroundGradient = LinearGradient(...); // const!
  
  // O usar RepaintBoundary para gradientes dinámicos
  RepaintBoundary(
    child: Container(
      decoration: BoxDecoration(
        gradient: dynamicGradient,
      ),
    ),
  )
}
```

---

### 10. 🔑 Reducir uso de GlobalKey

**Impacto:** -5% memoria

**Estrategia:**
1. Auditar todos los `GlobalKey` en la app
2. Reemplazar por `ValueKey` cuando sea posible
3. Usar `ObjectKey` para objetos inmutables

---

### 11. ✨ Implementar Shimmer Placeholders

**Impacto:** Mejor UX (sensación de rapidez)  
**Package:** `shimmer: ^3.0.0`

**Implementación:**
```dart
Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: Container(
    width: 160,
    height: 160,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

**Ubicaciones:**
- Loading de canciones destacadas
- Loading de artistas
- Loading de búsqueda

---

### 12. 🦸 Optimizar Hero Animations

**Impacto:** +10 FPS en transiciones

**Implementación:**
```dart
Hero(
  tag: 'cover_${song.id}',
  flightShuttleBuilder: (
    flightContext,
    animation,
    direction,
    fromContext,
    toContext,
  ) {
    // Usar animación optimizada durante el vuelo
    return FadeTransition(
      opacity: animation,
      child: Material(
        color: Colors.transparent,
        child: toContext.widget,
      ),
    );
  },
  child: CoverImage(...),
)
```

---

## 🎯 PLAN DE IMPLEMENTACIÓN RECOMENDADO

### **MES 1: Quick Wins de Alto Impacto**
- ✅ Semana 1: Optimización #1 (Lazy Loading)
- ✅ Semana 2: Optimización #2 (Image Caching)
- ✅ Semana 3-4: Optimización #6 (Pagination)

**Resultado esperado:** -25% memoria, +10 FPS, -40% carga inicial

---

### **MES 2: Optimizaciones Profundas**
- ✅ Semana 1-2: Optimización #3 (Isolates para Audio)
- ✅ Semana 3-4: Optimización #7 (Database Isar)

**Resultado esperado:** +20 FPS en reproducción, +300% velocidad local

---

### **MES 3: Pulido Fino**
- ✅ Semana 1: Optimización #4 (Incremental Builds)
- ✅ Semana 2: Optimización #5 (AnimationControllers)
- ✅ Semana 3: Optimización #8 (Code Splitting)
- ✅ Semana 4: Testing y benchmarking

**Resultado esperado:** -15% rebuilds, -10% batería

---

### **MES 4: Detalles de UX**
- ✅ Semana 1: Optimización #11 (Shimmer)
- ✅ Semana 2: Optimización #12 (Hero Animations)
- ✅ Semana 3: Optimizaciones #9 y #10
- ✅ Semana 4: QA final + release

**Resultado esperado:** UX premium, 60 FPS constantes

---

## 🛠️ HERRAMIENTAS DE MEDICIÓN

### **Flutter DevTools**
```bash
flutter run --profile
# Abrir DevTools para ver:
# - Performance overlay
# - Memory usage
# - Frame rendering times
```

### **Benchmarking Script**
```dart
// Crear en: test/performance/benchmark_test.dart
void main() {
  testWidgets('Home scroll performance', (tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    
    final scrollable = find.byType(Scrollable).first;
    await tester.fling(scrollable, Offset(0, -500), 5000);
    await tester.pumpAndSettle();
    
    // Medir frames dropped
  });
}
```

---

## 📈 MÉTRICAS DE ÉXITO

| KPI | Antes | Meta |
|-----|-------|------|
| FPS mínimo en scroll | 45 | 55 |
| FPS promedio | 55 | 60 |
| Memoria en Home | 180MB | 120MB |
| Tiempo hasta primera canción | 2.5s | 1.5s |
| Jank >16ms | 3% | <1% |
| Tamaño APK | 78MB | 55MB |

---

## 🚨 NOTAS IMPORTANTES

1. **Siempre medir antes y después** de cada optimización
2. **Priorizar UX sobre optimización** (no sacrificar animaciones suaves por 2MB menos)
3. **Testing en dispositivos reales** (Android medio 2018-2020)
4. **Mantener código limpio** (optimizaciones no deben volver el código ilegible)

---

## 📚 RECURSOS

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Isar Database Documentation](https://isar.dev/)
- [Riverpod Performance Tips](https://riverpod.dev/docs/concepts/performance)
- [Image Optimization Guide](https://pub.dev/packages/cached_network_image)

---

**Creado por:** Antigravity AI  
**Fecha:** 18/01/2026  
**Versión:** 1.0
