# 🔍 ¿Qué son los Memory Leaks (Fugas de Memoria)?

## 📚 Concepto Básico

**Memory Leak (Fuga de Memoria)** = Cuando tu aplicación **retiene objetos en memoria que ya no necesita**, impidiendo que el Garbage Collector (recolector de basura) los elimine.

### 🔄 Ciclo Normal (SIN Memory Leak)

```
1. Widget se crea → Usa recursos (memoria)
2. Widget se destruye → Libera recursos
3. Garbage Collector elimina los objetos
4. ✅ Memoria liberada
```

### ❌ Ciclo con Memory Leak

```
1. Widget se crea → Usa recursos (memoria)
2. Widget se destruye → PERO los recursos NO se liberan
3. Garbage Collector NO puede eliminar los objetos
4. ❌ Memoria queda ocupada PARA SIEMPRE
```

---

## 💡 Analogía Simple

Imagina que tu aplicación es una **casa** y la memoria es el **espacio disponible**:

### ✅ Sin Memory Leak (Correcto)
```
🔑 Abres una habitación (creas widget)
📦 Usas objetos en la habitación
🚪 Cierras y devuelves la llave (dispose())
🗑️ Limpieza automática elimina objetos innecesarios
✅ Habitación queda libre para usar de nuevo
```

### ❌ Con Memory Leak (Incorrecto)
```
🔑 Abres una habitación (creas widget)
📦 Usas objetos en la habitación
🚪 Cierras PERO olvidas devolver la llave (NO dispose())
❌ Objetos quedan dentro bloqueando la habitación
❌ La habitación NO puede ser usada de nuevo
💥 Con el tiempo, se acaban todas las habitaciones → CRASH
```

---

## 🔴 Problemas que Causan Memory Leaks en Flutter

### 1. **Controladores NO Disponidos**

```dart
// ❌ MALO: Memory Leak
class _MyScreenState extends State<MyScreen> {
  late final ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }
  
  // ❌ PROBLEMA: No hay dispose() → Memory Leak
  // El ScrollController queda en memoria para siempre
}
```

**Qué pasa:**
- El `ScrollController` se crea pero **nunca se libera**
- Cada vez que abres esta pantalla, se crea otro controlador
- **100 pantallas = 100 controladores en memoria** (aunque ya no los uses)
- Con el tiempo, la memoria se llena → **CRASH** 💥

**Solución:**
```dart
// ✅ BUENO: Sin Memory Leak
class _MyScreenState extends State<MyScreen> {
  late final ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }
  
  @override
  void dispose() {
    _scrollController.dispose(); // ✅ Liberar memoria
    super.dispose();
  }
}
```

---

### 2. **Streams NO Cancelados**

```dart
// ❌ MALO: Memory Leak
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    // Escuchar stream pero NO guardar la suscripción
    audioStream.listen((data) {
      // ... hacer algo
    });
    // ❌ PROBLEMA: No hay forma de cancelar esto
  }
  
  // ❌ PROBLEMA: Cuando el widget se destruye, 
  // el listener sigue activo en memoria
}
```

**Qué pasa:**
- El listener sigue "escuchando" aunque el widget ya no exista
- El callback apunta al widget destruido
- Garbage Collector **no puede eliminar** el widget porque hay una referencia activa
- **Acumulación infinita de widgets en memoria** → **CRASH** 💥

**Solución:**
```dart
// ✅ BUENO: Sin Memory Leak
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription; // ✅ Guardar suscripción
  
  @override
  void initState() {
    super.initState();
    _subscription = audioStream.listen((data) {
      // ... hacer algo
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel(); // ✅ Cancelar suscripción
    super.dispose();
  }
}
```

---

### 3. **Timers NO Cancelados**

```dart
// ❌ MALO: Memory Leak
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    Timer.periodic(Duration(seconds: 1), (timer) {
      // ... hacer algo cada segundo
    });
    // ❌ PROBLEMA: Timer sigue corriendo aunque el widget muera
  }
}
```

**Qué pasa:**
- El Timer sigue ejecutándose **para siempre**
- Cada segundo intenta actualizar un widget que ya no existe
- Consume CPU y memoria innecesariamente
- **Acumulación de timers activos** → **Ralentización y CRASH** 💥

**Solución:**
```dart
// ✅ BUENO: Sin Memory Leak
class _MyWidgetState extends State<MyWidget> {
  Timer? _timer; // ✅ Guardar timer
  
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      // ... hacer algo cada segundo
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel(); // ✅ Cancelar timer
    super.dispose();
  }
}
```

---

### 4. **Callbacks en Widgets Destruidos**

```dart
// ❌ MALO: Memory Leak
void _loadData() async {
  final data = await fetchData();
  setState(() {  // ❌ PROBLEMA: Widget puede estar destruido
    _myData = data;
  });
}
```

**Qué pasa:**
- Si el widget se destruye mientras `fetchData()` está ejecutándose
- `setState()` se llama en un widget que ya no existe
- El callback mantiene una referencia al widget destruido
- **Memory Leak** + **Error en consola**

**Solución:**
```dart
// ✅ BUENO: Sin Memory Leak
void _loadData() async {
  final data = await fetchData();
  if (!mounted) return; // ✅ Verificar que el widget existe
  setState(() {
    _myData = data;
  });
}
```

---

## 🔥 Ejemplo Real: Qué Pasa con Memory Leaks

### Escenario: Usuario navega mucho

**Sin Memory Leak (Correcto)**:
```
1. Abre Home → Usa 10 MB
2. Va a Search → Libera Home (10 MB libres), usa 8 MB
3. Va a Playlist → Libera Search (8 MB libres), usa 12 MB
4. Regresa a Home → Libera Playlist (12 MB libres), usa 10 MB
✅ Memoria total: ~10 MB (constante)
✅ App funciona bien
```

**Con Memory Leak (Incorrecto)**:
```
1. Abre Home → Usa 10 MB (NO se libera)
2. Va a Search → Home sigue en memoria (10 MB), usa 8 MB → Total: 18 MB
3. Va a Playlist → Home (10 MB) + Search (8 MB) siguen, usa 12 MB → Total: 30 MB
4. Regresa a Home → Todas siguen en memoria → Total: 30+ MB
❌ Memoria total: Crece sin parar
❌ App se ralentiza
💥 Después de 50 navegaciones: MEMORIA LLENA → CRASH
```

---

## 📊 Síntomas de Memory Leaks

### 1. **App se vuelve lenta con el tiempo**
- Empieza rápido
- Después de usar 10-15 minutos → Más lenta
- Después de 30 minutos → MUY lenta

### 2. **Memoria aumenta sin parar**
```
Minuto 1:  100 MB
Minuto 5:  150 MB
Minuto 10: 200 MB
Minuto 20: 350 MB
💥 Minuto 30: CRASH (memoria llena)
```

### 3. **Crashes inesperados**
- App se cierra sin razón aparente
- Mensaje: "Out of Memory" o "Memory exhausted"

### 4. **Batería se agota rápido**
- Timers corriendo innecesariamente
- Streams escuchando sin necesidad
- CPU trabajando constantemente

---

## ✅ Cómo Verificar Memory Leaks

### 1. **Usar Flutter DevTools**

```bash
# Ejecutar app con DevTools
flutter run

# Abrir DevTools
# En el navegador, ir a la pestaña "Memory"
# Ver gráfico de memoria mientras usas la app
```

**Qué buscar:**
- ✅ **Memoria estable**: Sube y baja normalmente
- ❌ **Memoria crece sin parar**: Memory Leak detectado

### 2. **Performance Overlay**

```bash
flutter run

# Presionar 'P' en la consola para activar overlay
# Ver FPS y uso de memoria en tiempo real
```

### 3. **Logs de Memoria**

```dart
// Agregar logs para monitorear
debugPrint('🔍 Memoria usada: ${ProcessInfo.currentRss / 1024 / 1024} MB');
```

---

## 🛡️ Prevención: Reglas de Oro

### Regla #1: Si inicializas, dispone
```dart
// ✅ SIEMPRE que crees un controlador, dispónelo
ScrollController → dispose()
AnimationController → dispose()
TextEditingController → dispose()
Timer → cancel()
```

### Regla #2: Si escuchas, cancela
```dart
// ✅ SIEMPRE que escuches un stream, cancélalo
stream.listen() → subscription.cancel()
```

### Regla #3: Si usas async, verifica mounted
```dart
// ✅ SIEMPRE verifica mounted antes de setState
if (!mounted) return;
setState(() { ... });
```

### Regla #4: Usa Riverpod ref.onDispose()
```dart
// ✅ Riverpod maneja cleanup automáticamente
ref.onDispose(() {
  // Limpiar recursos
});
```

---

## 📋 Checklist para Prevenir Memory Leaks

Al crear un nuevo widget con controladores/streams:

- [ ] ¿Tengo `ScrollController`? → Agregar `dispose()`
- [ ] ¿Tengo `AnimationController`? → Agregar `dispose()`
- [ ] ¿Tengo `TextEditingController`? → Agregar `dispose()`
- [ ] ¿Tengo `Timer`? → Agregar `cancel()` en dispose()
- [ ] ¿Tengo `StreamSubscription`? → Agregar `cancel()` en dispose()
- [ ] ¿Uso `setState()` después de async? → Verificar `mounted`
- [ ] ¿Uso `ref.read()` en dispose? → Guardar notifier antes
- [ ] ¿Llamo `super.dispose()`? → SIEMPRE al final

---

## 🎯 Resumen

### Memory Leak = Objetos que NO se liberan de memoria

**Consecuencias:**
1. 🔴 App se vuelve lenta
2. 🔴 Memoria aumenta sin parar
3. 🔴 Crashes inesperados
4. 🔴 Batería se agota rápido

**Prevención:**
1. ✅ Dispose de controladores
2. ✅ Cancel de streams
3. ✅ Cancel de timers
4. ✅ Verificar `mounted` en async

**En tu app:**
- ✅ **0 memory leaks encontrados**
- ✅ **Todos los controladores dispuestos**
- ✅ **Todos los streams cancelados**
- ✅ **Patrones correctos implementados**

---

## 💡 Conclusión

**Memory Leak** = Cuando tu app "olvida" liberar memoria que ya no necesita.

**En tu aplicación**: ✅ **NO hay memory leaks** - Todo está correctamente manejado.

**Tu app es segura** porque:
- Todos los controladores se disponen
- Todos los streams se cancelan
- Se siguen los patrones correctos
- Riverpod ayuda a prevenir leaks automáticamente

---

**¿Quieres más información sobre algún tipo específico de memory leak o cómo detectarlos?**










