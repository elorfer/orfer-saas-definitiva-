# Sistema de Streams estilo Spotify

## 📋 Descripción

Sistema completo de registro de streams con validación robusta, rate limiting y prevención de fraude. Implementa las reglas exactas de Spotify para contar reproducciones válidas.

## 🎯 Reglas de Validación

1. **30 segundos mínimos**: Solo cuenta si el usuario escuchó al menos 30 segundos reales
2. **Rate limiting**: Máximo 1 stream por usuario cada 30 segundos para la misma canción
3. **Anti-fraude**: Ignora reproducciones sin interacción, volumen 0, app en background

## 🔄 Flujo de Trabajo

### 1. Frontend envía progreso

```typescript
POST /streams/track-progress
{
  "songId": "uuid",
  "progressMs": 45000,
  "durationMs": 210000,
  "volume": 0.8,
  "isForeground": true
}
```

### 2. Backend valida y registra

- Valida progreso ≥ 30 segundos
- Verifica rate limit (Redis)
- Crea/actualiza sesión de escucha
- Si cumple condiciones, registra stream automáticamente

### 3. Stream registrado

- Incrementa `totalStreams` en `songs`
- Incrementa `totalStreams` en `artists`
- Crea registro en tabla `streams`
- Marca sesión como validada

## 📁 Estructura

```
streams/
├── dto/
│   └── track-progress.dto.ts
├── streams.controller.ts
├── streams.service.ts
├── streams.module.ts
└── README.md
```

## 🗄️ Base de Datos

### Tabla `streams`
- Registra cada stream válido
- Índices optimizados para consultas

### Tabla `user_listening_sessions`
- Tracking de progreso en tiempo real
- Previene duplicados
- Anti-fraude

## ⚙️ Configuración

### Variables de entorno

```env
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
```

### Instalar dependencias

```bash
npm install ioredis
```

## 🚀 Uso

### Registrar progreso (Frontend)

```typescript
// Cada 5-10 segundos enviar progreso
const response = await fetch('/api/v1/streams/track-progress', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    songId: currentSong.id,
    progressMs: currentPosition * 1000,
    durationMs: songDuration * 1000,
    volume: audioPlayer.volume,
    isForeground: document.hasFocus(),
  }),
});

const { streamRegistered, shouldRegisterStream } = await response.json();
```

## 📊 Ejemplo Completo

### Escenario: Usuario reproduce canción

1. **t=0s**: Usuario toca Play
   - Frontend envía `progressMs: 0`
   - Backend crea sesión, no registra stream

2. **t=15s**: Progreso intermedio
   - Frontend envía `progressMs: 15000`
   - Backend actualiza sesión, no registra (aún < 30s)

3. **t=35s**: Cumple condición
   - Frontend envía `progressMs: 35000`
   - Backend valida ≥ 30s
   - Verifica rate limit (OK)
   - **Registra stream** ✅
   - Incrementa contadores

4. **t=45s**: Intento duplicado
   - Frontend envía `progressMs: 45000`
   - Backend detecta sesión ya validada
   - No registra (evita duplicados)

5. **t=65s**: Usuario repite canción
   - Frontend envía `progressMs: 35000` (nueva sesión)
   - Backend verifica rate limit (pasaron 30s desde último stream)
   - **Registra nuevo stream** ✅

## 🔒 Seguridad

- Validación de progreso natural (no saltos sospechosos)
- Rate limiting con Redis
- Validación de volumen y estado de app
- Transacciones atómicas para contadores

## 📈 Optimizaciones

- Redis para rate limiting (alta concurrencia)
- Índices en tablas críticas
- Transacciones para atomicidad
- Cleanup periódico de sesiones antiguas

## 🧹 Mantenimiento

Ejecutar periódicamente para limpiar sesiones antiguas:

```typescript
await streamsService.cleanupOldSessions(7); // 7 días
```












