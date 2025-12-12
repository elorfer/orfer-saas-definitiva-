# 🧪 Guía de Pruebas: Guard Anti-Loop y Deduplicación

## 📋 Prerequisitos

1. **Backend corriendo**: Asegúrate de que tu backend esté activo en `http://192.168.1.6:3001` o `http://localhost:3001`
2. **Dispositivo conectado**: Emulador Android o dispositivo físico conectado
3. **Logs visibles**: Necesitas ver los logs de Flutter

---

## 🚀 Paso 1: Ejecutar la App con Logs

### Opción A: Desde la raíz del proyecto
```powershell
cd apps/frontend
flutter run
```

### Opción B: Con logs filtrados (solo errores y warnings importantes)
```powershell
cd apps/frontend
flutter run | Select-String -Pattern "GUARD ANTI-LOOP|DEDUP RUNTIME|CORRUPTED|duplicado"
```

### Opción C: Ver todos los logs de Flutter (más detallado)
```powershell
cd apps/frontend
flutter run -v
```

---

## 🛡️ PRUEBA 1: Guard Anti-Loop (Archivos Corruptos)

### Objetivo
Verificar que el sistema detecta y salta automáticamente archivos corruptos.

### Escenario de Prueba

**Método 1: Esperar a que ocurra naturalmente**
1. Reproduce música en modo algoritmo (Radio Infinita)
2. Si alguna canción tiene problemas de MediaCodec CORRUPTED, el sistema debería:
   - Detectar el error automáticamente
   - Intentar reproducir 2 veces más
   - Saltar automáticamente a la siguiente canción

**Método 2: Simular error (requiere código temporal)**
Si quieres forzar la prueba, puedes agregar temporalmente este código en `_checkForSilentCorruption()`:

```dart
// CÓDIGO TEMPORAL PARA PRUEBAS - ELIMINAR DESPUÉS
if (currentSong != null && currentSong.title.contains("TEST_CORRUPT")) {
  AppLogger.warning('[TEST] Simulando archivo corrupto...');
  // Forzar estado idle
  await service.pause();
  await Future.delayed(Duration(milliseconds: 100));
  // El sistema detectará el idle y activará el guard
}
```

### Logs que Deberías Ver

✅ **Detección exitosa:**
```
[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: Posible corrupción silenciosa detectada en nueva canción: [NOMBRE_CANCIÓN]
[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: Posible corrupción silenciosa detectada (intento 2/2): [NOMBRE_CANCIÓN]
[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: Corrupción silenciosa confirmada. Forzando salto...
[PlaybackNotifier] 🛡️ GUARD ANTI-LOOP: Salto forzado por corrupción silenciosa completado.
```

❌ **Si no funciona:**
- No verás los logs de "GUARD ANTI-LOOP"
- La canción se quedará atascada
- El reproductor no avanzará automáticamente

---

## 🔍 PRUEBA 2: Deduplicación en Runtime

### Objetivo
Verificar que el sistema detecta y elimina duplicados de la cola en tiempo real.

### Escenario de Prueba

**Método 1: Esperar duplicados naturales**
1. Reproduce música en modo algoritmo
2. Si el backend devuelve canciones duplicadas, el sistema debería:
   - Detectar los duplicados automáticamente
   - Eliminarlos de la cola
   - Ajustar el índice si es necesario

**Método 2: Forzar duplicados (requiere código temporal)**
Puedes agregar temporalmente este código en `playAlgorithmStart()` después de cargar la cola:

```dart
// CÓDIGO TEMPORAL PARA PRUEBAS - ELIMINAR DESPUÉS
if (state.currentQueue.length > 0) {
  // Duplicar la primera canción al final
  final firstSong = state.currentQueue.first;
  final duplicatedQueue = [...state.currentQueue, firstSong];
  state = state.copyWith(currentQueue: duplicatedQueue);
  AppLogger.warning('[TEST] Duplicado forzado para prueba');
}
```

### Logs que Deberías Ver

✅ **Deduplicación exitosa:**
```
[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] Duplicado detectado en índice X: [NOMBRE_CANCIÓN] (ID: xxxxxxxx...)
[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] Se detectaron N duplicados en runtime. Limpiando cola...
[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] IDs duplicados: xxxxxxxx, yyyyyyyy
[PlaybackNotifier] 🛡️ [DEDUP RUNTIME] Cola deduplicada: M canciones únicas (N duplicados eliminados)
```

❌ **Si no funciona:**
- No verás los logs de "DEDUP RUNTIME"
- Los duplicados permanecerán en la cola
- Puedes ver la misma canción repetida

---

## 🔬 PRUEBA 3: Prueba Combinada (Recomendada)

### Escenario Completo
1. **Inicia la app** con logs visibles
2. **Reproduce música** en modo algoritmo (Radio Infinita)
3. **Observa los logs** durante 5-10 minutos
4. **Busca estos patrones:**

```powershell
# Filtrar solo logs importantes
flutter run | Select-String -Pattern "GUARD|DEDUP|CORRUPTED|duplicado|🛡️"
```

### Qué Buscar

✅ **Sistema funcionando correctamente:**
- Logs de "GUARD ANTI-LOOP" cuando hay problemas
- Logs de "DEDUP RUNTIME" cuando hay duplicados
- La música continúa sin interrupciones
- No hay loops infinitos

❌ **Problemas:**
- La música se atasca en una canción
- Se repiten las mismas canciones sin avanzar
- No aparecen logs de detección

---

## 📊 Verificación Rápida

### Comando para ver logs en tiempo real (PowerShell)
```powershell
cd apps/frontend
flutter run | Select-String -Pattern "GUARD|DEDUP|CORRUPTED|🛡️|Error|Warning" -Context 0,2
```

### Comando para guardar logs en archivo
```powershell
cd apps/frontend
flutter run > logs.txt 2>&1
# Luego busca en logs.txt: "GUARD ANTI-LOOP" o "DEDUP RUNTIME"
```

---

## 🐛 Debugging

### Si no ves los logs:
1. Verifica que estás en modo DEBUG (no RELEASE)
2. Asegúrate de que `AppLogger` está configurado correctamente
3. Revisa que los listeners están activos en `_initSubscriptions()`

### Si el Guard Anti-Loop no se activa:
1. Verifica que el reproductor realmente está en estado `idle`
2. Revisa que `state.isPlaying` es `true` cuando debería reproducir
3. Aumenta temporalmente `_maxCorruptedRetries` para más intentos

### Si la deduplicación no funciona:
1. Verifica que `_isUpdatingQueue` no está bloqueado
2. Revisa que `sequenceStateStream` está emitiendo eventos
3. Asegúrate de que los IDs de las canciones son únicos

---

## ✅ Checklist de Pruebas

- [ ] La app se ejecuta sin errores
- [ ] Los logs muestran "GUARD ANTI-LOOP" cuando hay problemas
- [ ] Los logs muestran "DEDUP RUNTIME" cuando hay duplicados
- [ ] La música continúa reproduciéndose sin atascarse
- [ ] No hay loops infinitos
- [ ] El sistema salta automáticamente archivos problemáticos
- [ ] Los duplicados se eliminan de la cola

---

## 🎯 Resultado Esperado

Después de las pruebas, deberías ver:
1. **Sistema robusto**: La música nunca se atasca
2. **Logs informativos**: Sabes exactamente qué está pasando
3. **Experiencia fluida**: El usuario no nota los problemas técnicos
4. **Auto-recuperación**: El sistema se recupera automáticamente de errores

---

## 📝 Notas

- Los logs de "GUARD ANTI-LOOP" solo aparecen cuando hay problemas reales
- Los logs de "DEDUP RUNTIME" solo aparecen cuando hay duplicados
- Si no ves estos logs, significa que el sistema está funcionando correctamente
- Los errores de MediaCodec CORRUPTED son raros, pero el sistema está preparado

---

## 🆘 ¿Problemas?

Si encuentras problemas:
1. Revisa los logs completos con `flutter run -v`
2. Verifica que el backend está respondiendo correctamente
3. Asegúrate de que las canciones tienen URLs válidas
4. Revisa la conexión de red





