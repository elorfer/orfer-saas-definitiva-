# 📋 INSTRUCCIONES PARA VER LOS CAMBIOS

## 🚀 PASOS PARA PROBAR LOS CAMBIOS

### **1. Reiniciar el Backend (TypeScript/NestJS)**

Si tienes el backend corriendo, **debes reiniciarlo** para que los cambios en los pesos del algoritmo y el historial de exclusión tomen efecto.

```bash
# Detener el backend (Ctrl+C en la terminal donde está corriendo)
# Luego reiniciarlo:

cd apps/backend
npm run start:dev
# o
yarn start:dev
```

**⚠️ IMPORTANTE:** Los cambios en el backend (pesos del algoritmo y `HISTORY_SIZE`) solo se aplican después de reiniciar el servidor.

---

### **2. Reiniciar el Frontend (Flutter)**

Si tienes el frontend corriendo, **debes hacer un Hot Restart** (no solo Hot Reload) para que los cambios en el código Dart tomen efecto.

**Opción A: Hot Restart desde VS Code/Android Studio**
- Presiona `Ctrl+Shift+F5` (Windows/Linux) o `Cmd+Shift+F5` (Mac)
- O busca "Hot Restart" en la paleta de comandos

**Opción B: Desde la terminal**
```bash
# Detener la app (Ctrl+C)
# Luego reiniciarla:

cd apps/frontend
flutter run
```

**Opción C: Hot Restart desde la app (si está en modo debug)**
- Presiona `R` en la terminal donde está corriendo Flutter
- O agita el dispositivo y selecciona "Hot Restart"

---

### **3. Probar el Flujo de Radio Infinita**

Una vez que ambos servicios estén corriendo:

#### **Prueba 1: Iniciar Radio desde una Tarjeta**
1. Abre la app
2. Toca cualquier tarjeta de canción (botón de play)
3. La canción debe empezar a reproducirse
4. Al terminar, debe continuar con recomendaciones (Radio Infinita)
5. **Verifica:** Las recomendaciones deben ser más variadas (diferentes artistas, géneros)

#### **Prueba 2: Iniciar Radio sin Canción Específica**
1. Si tienes un botón "Iniciar Radio" genérico, tócalo
2. El sistema debe obtener una semilla dinámica (del historial, popular o destacada)
3. Debe empezar a reproducir y continuar con recomendaciones
4. **Verifica:** La semilla debe ser diferente cada vez

#### **Prueba 3: Verificar Menos Repeticiones**
1. Reproduce Radio Infinita durante al menos 15-20 canciones
2. **Verifica:** No debe repetir canciones que ya escuchaste en las últimas 10
3. **Verifica:** Debe haber más variedad de artistas y géneros

---

### **4. Verificar los Logs**

#### **Backend (Terminal del servidor)**

Busca estos mensajes en los logs del backend:

```
✅ Recomendación seleccionada: [Canción] (posición X de 10)
🧮 Top 5 recomendaciones:
  [Factor: género:0.XX, popularidad:0.XX, artista:0.XX, novedad:0.XX, afinidad:0.XX]
```

**Verifica:**
- Los pesos deben reflejar los nuevos valores (género: 0.30, novedad: 0.20, afinidad: 0.20)
- La posición debe variar (no siempre la misma)
- El historial debe excluir 10 canciones (no 3)

#### **Frontend (Logs de Flutter)**

Busca estos mensajes en los logs del frontend:

```
🎲 Obteniendo semilla dinámica para Radio Infinita...
✅ Semilla desde historial: [Canción]
✅ Semilla desde canciones populares: [Canción]
[PlaybackNotifier] Modo algoritmo iniciado: X canciones iniciales
```

**Verifica:**
- La semilla debe variar (no siempre la misma canción)
- El historial debe tener 10 canciones excluidas

---

### **5. Verificar Cambios Específicos**

#### **A. Pesos del Algoritmo (Backend)**

Abre: `apps/backend/src/modules/recommendations/recommendation.service.ts`

Busca la función `applySimilarityScoring()` (línea ~759) y verifica:

```typescript
// Debe mostrar estos pesos:
score += genreScore * 0.30;        // ✅ 30% (antes 40%)
score += popularityScore * 0.20;   // ✅ 20% (antes 25%)
score += artistScore * 0.10;       // ✅ 10% (antes 15%)
score += noveltyScore * 0.20;     // ✅ 20% (antes 10%)
score += userScore * 0.20;         // ✅ 20% (antes 10%)
```

#### **B. Historial de Exclusión (Backend)**

Busca `HISTORY_SIZE` (línea ~28) y verifica:

```typescript
private readonly HISTORY_SIZE = 10; // ✅ Debe ser 10 (antes 5)
```

Busca todos los `.slice(0, 10)` y verifica que no haya `.slice(0, 3)`:

```typescript
const recentIds = recentSongs.slice(0, 10); // ✅ Debe ser 10
```

#### **C. Exclusión en Frontend**

Abre: `apps/frontend/lib/core/providers/playback_notifier.dart`

Busca `_generateInitialAlgorithmQueue()` (línea ~222) y verifica:

```dart
final playHistory = ref.read(playHistoryProvider.notifier).getRecentHistory(limit: 10); // ✅ Debe ser 10
```

Busca `_appendMoreAlgorithmSongs()` (línea ~280) y verifica:

```dart
final playHistory = ref.read(playHistoryProvider.notifier).getRecentHistory(limit: 10); // ✅ Debe ser 10
```

---

### **6. Qué Esperar Ver**

#### **Antes (Comportamiento Anterior):**
- ❌ Misma canción como semilla repetidamente
- ❌ Recomendaciones muy similares (mismo artista, mismo género)
- ❌ Repeticiones después de 3-5 canciones
- ❌ Género dominando las recomendaciones

#### **Ahora (Comportamiento Nuevo):**
- ✅ Semilla dinámica variada (historial, popular, destacada)
- ✅ Recomendaciones más diversas (diferentes artistas, géneros)
- ✅ Sin repeticiones durante al menos 10 canciones
- ✅ Más canciones nuevas y personalizadas
- ✅ Balance mejorado entre todos los factores

---

### **7. Troubleshooting**

#### **Si no ves cambios:**

1. **Backend no reiniciado:**
   - Detén y reinicia el servidor backend
   - Verifica que no haya errores en la consola

2. **Frontend no reiniciado:**
   - Haz Hot Restart (no Hot Reload)
   - O reinicia completamente la app

3. **Cache del backend:**
   - El cache tiene TTL de 5 minutos
   - Espera 5 minutos o reinicia el backend para limpiar el cache

4. **Cache del frontend:**
   - Limpia el cache de la app
   - O desinstala y reinstala la app

5. **Verifica los logs:**
   - Revisa los logs del backend para ver los pesos aplicados
   - Revisa los logs del frontend para ver la semilla dinámica

---

### **8. Comandos Rápidos**

```bash
# Backend
cd apps/backend
npm run start:dev

# Frontend (en otra terminal)
cd apps/frontend
flutter run

# Ver logs del backend
# (Los verás en la terminal donde corre el backend)

# Ver logs del frontend
# (Los verás en la terminal donde corre Flutter)
# O presiona 'v' en la terminal de Flutter para ver más logs
```

---

## ✅ CHECKLIST DE VERIFICACIÓN

- [ ] Backend reiniciado
- [ ] Frontend reiniciado (Hot Restart)
- [ ] Radio Infinita iniciada desde tarjeta
- [ ] Semilla dinámica variada (ver logs)
- [ ] Recomendaciones más diversas
- [ ] Sin repeticiones en las últimas 10 canciones
- [ ] Logs muestran nuevos pesos (30%, 20%, 10%, 20%, 20%)
- [ ] Logs muestran exclusión de 10 canciones

---

**¡Listo!** Con estos pasos deberías poder ver todos los cambios funcionando. 🎉


