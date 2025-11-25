# 📋 Funciones Faltantes y Recomendaciones de Implementación

## 📊 Resumen Ejecutivo

Este documento detalla todas las funciones identificadas como faltantes o incompletas en la aplicación, organizadas por prioridad y categoría. Incluye análisis de impacto, complejidad de implementación y recomendaciones técnicas.

---

## 🔴 PRIORIDAD ALTA - Funciones Críticas para UX

### 1. 🔍 **Búsqueda Funcional** ⚠️ ACTUALMENTE PLACEHOLDER
**Estado:** Pantalla existe pero no tiene funcionalidad real  
**Ubicación:** `apps/frontend/lib/features/search/screens/search_screen.dart`

**Funcionalidades requeridas:**
- ✅ Búsqueda de canciones por título, artista, álbum
- ✅ Búsqueda de artistas por nombre
- ✅ Búsqueda de playlists por nombre
- ✅ Filtros avanzados (género, año, duración)
- ✅ Historial de búsquedas recientes
- ✅ Sugerencias de búsqueda (autocomplete)
- ✅ Resultados en tiempo real mientras se escribe

**Backend necesario:**
- Endpoint: `GET /public/search?q={query}&type={song|artist|playlist}`
- Endpoint: `GET /public/search/suggestions?q={query}`
- Índices de búsqueda full-text en PostgreSQL (pg_trgm ya está habilitado)

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐⭐⭐ (Crítico para descubrimiento de música)  
**Tiempo estimado:** 3-5 días

**Recomendación:** **IMPLEMENTAR INMEDIATAMENTE** - Es una función core de cualquier app de música.

---

### 2. 📚 **Biblioteca del Usuario Funcional** ⚠️ ACTUALMENTE PLACEHOLDER
**Estado:** Pantalla existe pero todas las secciones muestran "0" y no tienen funcionalidad  
**Ubicación:** `apps/frontend/lib/features/library/screens/library_screen.dart`

**Funcionalidades requeridas:**

#### 2.1. Canciones Favoritas
- ✅ Ver lista de canciones marcadas como favoritas
- ✅ Agregar/quitar de favoritos desde cualquier pantalla
- ✅ Sincronización con backend
- ✅ Filtros y ordenamiento

#### 2.2. Mis Playlists
- ✅ Listar playlists creadas por el usuario
- ✅ Crear nueva playlist
- ✅ Editar/eliminar playlists propias
- ✅ Compartir playlists

#### 2.3. Descargadas (Modo Offline)
- ✅ Descargar canciones para reproducción offline
- ✅ Gestión de espacio de almacenamiento
- ✅ Indicador visual de estado de descarga
- ✅ Sincronización automática cuando hay conexión

#### 2.4. Recientemente Reproducidas
- ✅ Historial de reproducción con timestamps
- ✅ Limpiar historial
- ✅ Reproducir desde historial

#### 2.5. Álbumes Guardados
- ✅ Guardar álbumes completos
- ✅ Ver álbumes guardados
- ✅ Reproducir álbum completo

#### 2.6. Artistas Seguidos
- ✅ Listar artistas que el usuario sigue
- ✅ Notificaciones de nuevos lanzamientos (futuro)
- ✅ Acceso rápido a perfiles

**Backend necesario:**
- Endpoint: `GET /users/me/library/favorites`
- Endpoint: `POST /songs/:id/like` / `DELETE /songs/:id/like`
- Endpoint: `GET /users/me/library/playlists`
- Endpoint: `GET /users/me/library/downloads`
- Endpoint: `GET /users/me/play-history`
- Endpoint: `GET /users/me/following/artists`
- Endpoint: `POST /artists/:id/follow` / `DELETE /artists/:id/follow`

**Complejidad:** Alta (múltiples features)  
**Impacto:** ⭐⭐⭐⭐⭐ (Core de la experiencia de usuario)  
**Tiempo estimado:** 10-15 días

**Recomendación:** **IMPLEMENTAR EN FASE 1** - Dividir en sub-tareas y priorizar:
1. Favoritos y Playlists (5 días)
2. Historial y Artistas Seguidos (3 días)
3. Descargas Offline (7 días - más complejo)

---

### 3. 🔐 **Autenticación Social** ⚠️ TODOs EN CÓDIGO
**Estado:** Botones existen pero muestran "próximamente"  
**Ubicación:** 
- `apps/frontend/lib/features/auth/screens/login_screen.dart` (líneas 286, 301)
- `apps/frontend/lib/features/auth/screens/register_screen.dart`

**Funcionalidades requeridas:**
- ✅ Login con Google (`google_sign_in` ya está en `pubspec.yaml`)
- ✅ Login con Apple (`sign_in_with_apple` ya está en `pubspec.yaml`)
- ✅ Registro con Google/Apple
- ✅ Vinculación de cuentas sociales a cuenta existente
- ✅ Manejo de tokens OAuth

**Backend necesario:**
- Endpoint: `POST /auth/google` - Validar token de Google
- Endpoint: `POST /auth/apple` - Validar token de Apple
- Endpoint: `POST /auth/link-social` - Vincular cuenta social

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐⭐ (Mejora significativa en conversión de registro)  
**Tiempo estimado:** 4-6 días

**Recomendación:** **IMPLEMENTAR EN FASE 1** - Las dependencias ya están instaladas, solo falta la integración.

---

### 4. 🔑 **Recuperación de Contraseña** ⚠️ TODO EN CÓDIGO
**Estado:** Botón existe pero muestra "próximamente"  
**Ubicación:** `apps/frontend/lib/features/auth/screens/login_screen.dart` (línea 211)

**Funcionalidades requeridas:**
- ✅ Pantalla de "Olvidé mi contraseña"
- ✅ Envío de email con link de recuperación
- ✅ Pantalla de reset de contraseña con token
- ✅ Validación de token y expiración
- ✅ Confirmación visual de envío

**Backend necesario:**
- Endpoint: `POST /auth/forgot-password` - Enviar email
- Endpoint: `POST /auth/reset-password` - Resetear con token
- Servicio de email (SendGrid, AWS SES, etc.)

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐⭐ (Reducción de soporte y mejor UX)  
**Tiempo estimado:** 3-4 días

**Recomendación:** **IMPLEMENTAR EN FASE 1** - Función estándar esperada por usuarios.

---

## 🟡 PRIORIDAD MEDIA - Funciones Importantes

### 5. 🎤 **Seguir/Dejar de Seguir Artistas** ⚠️ BACKEND LISTO, FRONTEND FALTA
**Estado:** Backend tiene tabla `artist_followers` y relaciones, pero no hay UI en frontend

**Funcionalidades requeridas:**
- ✅ Botón "Seguir" en perfil de artista
- ✅ Contador de seguidores actualizado en tiempo real
- ✅ Lista de artistas seguidos en Biblioteca
- ✅ Notificación cuando artista sube nueva música (futuro)
- ✅ Estado persistente (saber si ya sigo al artista)

**Backend necesario:**
- ✅ Tabla `artist_followers` ya existe
- Endpoint: `POST /artists/:id/follow`
- Endpoint: `DELETE /artists/:id/follow`
- Endpoint: `GET /artists/:id/followers` (ya puede existir)
- Endpoint: `GET /users/me/following/artists`

**Complejidad:** Baja  
**Impacto:** ⭐⭐⭐⭐ (Engagement y retención)  
**Tiempo estimado:** 2-3 días

**Recomendación:** **IMPLEMENTAR EN FASE 2** - Backend ya está preparado, solo falta UI.

---

### 6. ❤️ **Like/Dislike de Canciones** ⚠️ BACKEND LISTO, FRONTEND FALTA
**Estado:** Backend tiene tabla `song_likes` pero no hay UI en frontend

**Funcionalidades requeridas:**
- ✅ Botón de "Me gusta" en cada canción
- ✅ Contador de likes visible
- ✅ Lista de canciones favoritas en Biblioteca
- ✅ Sincronización con backend
- ✅ Estado visual (corazón lleno/vacío)

**Backend necesario:**
- ✅ Tabla `song_likes` ya existe
- Endpoint: `POST /songs/:id/like`
- Endpoint: `DELETE /songs/:id/like`
- Endpoint: `GET /songs/:id/likes`
- Endpoint: `GET /users/me/liked-songs`

**Complejidad:** Baja  
**Impacto:** ⭐⭐⭐⭐ (Personalización y recomendaciones futuras)  
**Tiempo estimado:** 2-3 días

**Recomendación:** **IMPLEMENTAR EN FASE 2** - Base para sistema de recomendaciones.

---

### 7. 📋 **Seguir Playlists** ⚠️ BACKEND LISTO, FRONTEND FALTA
**Estado:** Backend tiene tabla `playlist_followers` pero no hay UI

**Funcionalidades requeridas:**
- ✅ Botón "Seguir" en playlists públicas
- ✅ Contador de seguidores
- ✅ Lista de playlists seguidas en Biblioteca
- ✅ Notificaciones cuando playlist se actualiza (futuro)

**Backend necesario:**
- ✅ Tabla `playlist_followers` ya existe
- Endpoint: `POST /playlists/:id/follow`
- Endpoint: `DELETE /playlists/:id/follow`
- Endpoint: `GET /users/me/following/playlists`

**Complejidad:** Baja  
**Impacto:** ⭐⭐⭐ (Mejora descubrimiento de contenido)  
**Tiempo estimado:** 2 días

**Recomendación:** **IMPLEMENTAR EN FASE 2** - Similar a seguir artistas.

---

### 8. 📤 **Compartir Contenido** ⚠️ DEPENDENCIA INSTALADA, NO IMPLEMENTADO
**Estado:** `share_plus` está en `pubspec.yaml` pero no se usa

**Funcionalidades requeridas:**
- ✅ Compartir canción (link + metadata)
- ✅ Compartir playlist (link + cover)
- ✅ Compartir perfil de artista (link + foto)
- ✅ Deep links para abrir contenido compartido
- ✅ Compartir en redes sociales nativas

**Backend necesario:**
- Endpoint: `GET /songs/:id/share-link` (generar link único)
- Endpoint: `GET /playlists/:id/share-link`
- Endpoint: `GET /artists/:id/share-link`
- Manejo de deep links en Flutter

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐⭐ (Crecimiento orgánico y viralidad)  
**Tiempo estimado:** 3-4 días

**Recomendación:** **IMPLEMENTAR EN FASE 2** - Importante para crecimiento.

---

### 9. 📊 **Historial de Reproducción** ⚠️ BACKEND LISTO, FRONTEND FALTA
**Estado:** Backend tiene tabla `play_history` pero no se usa en frontend

**Funcionalidades requeridas:**
- ✅ Guardar cada reproducción automáticamente
- ✅ Mostrar historial en Biblioteca
- ✅ Limpiar historial
- ✅ Reproducir desde historial
- ✅ Estadísticas de escucha (tiempo total, canciones más escuchadas)

**Backend necesario:**
- ✅ Tabla `play_history` ya existe
- Endpoint: `POST /play-history` (auto-llamado desde `AudioPlayerService`)
- Endpoint: `GET /users/me/play-history`
- Endpoint: `DELETE /users/me/play-history`

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐ (Mejora experiencia personal)  
**Tiempo estimado:** 3-4 días

**Recomendación:** **IMPLEMENTAR EN FASE 2** - Integrar con `AudioPlayerService`.

---

### 10. ⚙️ **Pantalla de Configuración** ⚠️ PLACEHOLDER
**Estado:** Botón en Quick Actions muestra "próximamente"  
**Ubicación:** `apps/frontend/lib/features/home/widgets/quick_actions.dart` (línea 94)

**Funcionalidades requeridas:**
- ✅ Configuración de calidad de audio (128/192/320 kbps)
- ✅ Configuración de descarga (solo WiFi, calidad)
- ✅ Notificaciones (push, email)
- ✅ Privacidad (perfil público/privado)
- ✅ Cuenta (cambiar email, contraseña, eliminar cuenta)
- ✅ Tema (claro/oscuro/auto)
- ✅ Idioma
- ✅ Caché (limpiar, tamaño máximo)

**Backend necesario:**
- Endpoint: `GET /users/me/settings`
- Endpoint: `PUT /users/me/settings`
- Almacenamiento local con `SharedPreferences`

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐ (Mejora control del usuario)  
**Tiempo estimado:** 4-5 días

**Recomendación:** **IMPLEMENTAR EN FASE 2** - Mejora experiencia pero no crítica.

---

## 🟢 PRIORIDAD BAJA - Funciones Opcionales/Futuras

### 11. 📥 **Modo Offline / Descargas** ⚠️ MENCIONADO EN README
**Estado:** Mencionado como "próximamente" en README, sección en Biblioteca existe pero vacía

**Funcionalidades requeridas:**
- ✅ Descargar canciones individuales
- ✅ Descargar playlists completas
- ✅ Gestión de espacio (ver cuánto ocupa, limpiar)
- ✅ Reproducción offline sin conexión
- ✅ Sincronización automática cuando hay WiFi
- ✅ Indicadores visuales de estado de descarga

**Backend necesario:**
- Endpoint: `GET /songs/:id/download` (retornar URL directa o stream)
- Endpoint: `GET /playlists/:id/download` (retornar lista de URLs)
- Almacenamiento local con `path_provider` y `flutter_cache_manager`

**Complejidad:** Alta  
**Impacto:** ⭐⭐⭐⭐ (Muy valorado por usuarios, especialmente en áreas con mala conexión)  
**Tiempo estimado:** 10-12 días

**Recomendación:** **IMPLEMENTAR EN FASE 3** - Funcionalidad compleja pero muy valorada.

---

### 12. 🎨 **Subida de Música para Artistas** ⚠️ PLACEHOLDER
**Estado:** Botón en Quick Actions muestra "próximamente"  
**Ubicación:** `apps/frontend/lib/features/home/widgets/quick_actions.dart` (línea 79)

**Funcionalidades requeridas:**
- ✅ Pantalla de subida de canción
- ✅ Selector de archivo de audio (MP3, WAV, FLAC)
- ✅ Formulario de metadata (título, artista, género, año, portada)
- ✅ Preview de audio antes de subir
- ✅ Barra de progreso de subida
- ✅ Gestión de canciones subidas (editar, eliminar, ver estadísticas)
- ✅ Estado de publicación (draft, published, archived)

**Backend necesario:**
- Endpoint: `POST /songs/upload` (multipart/form-data)
- Endpoint: `GET /artists/me/songs`
- Endpoint: `PUT /songs/:id`
- Endpoint: `DELETE /songs/:id`
- Endpoint: `POST /songs/:id/publish`
- Almacenamiento en S3 (ya configurado según README)

**Complejidad:** Alta  
**Impacto:** ⭐⭐⭐⭐⭐ (Core para artistas)  
**Tiempo estimado:** 12-15 días

**Recomendación:** **IMPLEMENTAR EN FASE 3** - Crítico para artistas pero complejo.

---

### 13. 📈 **Estadísticas para Artistas** ⚠️ BACKEND PARCIALMENTE LISTO
**Estado:** Backend tiene campos `total_streams`, `total_followers`, `monthly_listeners` en `artists` table

**Funcionalidades requeridas:**
- ✅ Dashboard de estadísticas para artistas
- ✅ Gráficos de reproducciones (diario, semanal, mensual)
- ✅ Top canciones más escuchadas
- ✅ Demografía de oyentes (países, edades - futuro)
- ✅ Ingresos (si hay monetización)
- ✅ Exportar reportes

**Backend necesario:**
- Endpoint: `GET /artists/me/stats`
- Endpoint: `GET /artists/me/stats/streams?period={day|week|month}`
- Endpoint: `GET /artists/me/stats/top-songs`
- Agregación de datos de `play_history`

**Complejidad:** Media-Alta  
**Impacto:** ⭐⭐⭐⭐ (Muy importante para artistas)  
**Tiempo estimado:** 6-8 días

**Recomendación:** **IMPLEMENTAR EN FASE 3** - Después de tener historial de reproducción funcionando.

---

### 14. 💰 **Monetización para Artistas** ⚠️ MENCIONADO EN README
**Estado:** Mencionado como "próximamente" en README

**Funcionalidades requeridas:**
- ✅ Sistema de suscripciones premium
- ✅ Pago de royalties a artistas
- ✅ Dashboard de ingresos
- ✅ Retiros de fondos
- ✅ Historial de transacciones

**Backend necesario:**
- Integración con Stripe/PayPal (mencionado en README)
- Endpoint: `GET /artists/me/earnings`
- Endpoint: `POST /artists/me/withdraw`
- Sistema de cálculo de royalties

**Complejidad:** Muy Alta  
**Impacto:** ⭐⭐⭐⭐⭐ (Crítico para modelo de negocio)  
**Tiempo estimado:** 20-30 días

**Recomendación:** **IMPLEMENTAR EN FASE 4** - Requiere planificación legal y financiera.

---

### 15. 🔔 **Notificaciones Push** ⚠️ DEPENDENCIA COMENTADA
**Estado:** `flutter_local_notifications` y `firebase_messaging` están comentados en `pubspec.yaml`

**Funcionalidades requeridas:**
- ✅ Notificaciones de nuevos lanzamientos de artistas seguidos
- ✅ Notificaciones de actualizaciones de playlists seguidas
- ✅ Notificaciones de mensajes/mentions (futuro)
- ✅ Configuración de preferencias de notificaciones
- ✅ Badge count en icono de app

**Backend necesario:**
- Endpoint: `POST /notifications/register-device` (FCM token)
- Endpoint: `GET /users/me/notifications`
- Endpoint: `PUT /users/me/notifications/settings`
- Servicio de envío de notificaciones (Firebase Cloud Messaging)

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐⭐ (Engagement y retención)  
**Tiempo estimado:** 5-7 días

**Recomendación:** **IMPLEMENTAR EN FASE 3** - Después de tener seguir artistas funcionando.

---

### 16. 🎵 **Reproductor Mejorado**
**Funcionalidades sugeridas:**
- ✅ Cola de reproducción visible y editable
- ✅ Modo aleatorio y repetición
- ✅ Letras de canciones (si hay API disponible)
- ✅ Visualizador de ondas de audio
- ✅ Controles de velocidad de reproducción (0.5x, 1x, 1.5x, 2x)
- ✅ Sleep timer
- ✅ Equalizador (futuro)

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐ (Mejora experiencia pero no crítica)  
**Tiempo estimado:** 6-8 días

**Recomendación:** **IMPLEMENTAR EN FASE 3** - Mejoras incrementales.

---

### 17. 🔍 **Búsqueda Avanzada y Filtros**
**Funcionalidades sugeridas:**
- ✅ Filtros por género, año, duración, popularidad
- ✅ Ordenamiento (relevancia, fecha, popularidad)
- ✅ Búsqueda por letras
- ✅ Búsqueda por tempo/BPM
- ✅ Búsqueda por mood (feliz, triste, energético, etc.)

**Complejidad:** Media  
**Impacto:** ⭐⭐⭐ (Mejora descubrimiento)  
**Tiempo estimado:** 4-5 días

**Recomendación:** **IMPLEMENTAR EN FASE 3** - Después de búsqueda básica.

---

### 18. 🎧 **Recomendaciones Personalizadas**
**Funcionalidades sugeridas:**
- ✅ "Para ti" basado en historial de reproducción
- ✅ "Artistas similares"
- ✅ "Canciones que te pueden gustar"
- ✅ "Nuevos lanzamientos para ti"
- ✅ Algoritmo de recomendación (colaborativo, basado en contenido)

**Complejidad:** Alta  
**Impacto:** ⭐⭐⭐⭐⭐ (Muy importante para engagement)  
**Tiempo estimado:** 15-20 días

**Recomendación:** **IMPLEMENTAR EN FASE 4** - Requiere datos suficientes y algoritmo ML.

---

## 📊 Tabla Resumen de Prioridades

| # | Función | Prioridad | Complejidad | Impacto | Tiempo | Fase |
|---|---------|-----------|-------------|---------|--------|------|
| 1 | Búsqueda Funcional | 🔴 Alta | Media | ⭐⭐⭐⭐⭐ | 3-5d | 1 |
| 2 | Biblioteca Funcional | 🔴 Alta | Alta | ⭐⭐⭐⭐⭐ | 10-15d | 1 |
| 3 | Autenticación Social | 🔴 Alta | Media | ⭐⭐⭐⭐ | 4-6d | 1 |
| 4 | Recuperación Contraseña | 🔴 Alta | Media | ⭐⭐⭐⭐ | 3-4d | 1 |
| 5 | Seguir Artistas | 🟡 Media | Baja | ⭐⭐⭐⭐ | 2-3d | 2 |
| 6 | Like/Dislike Canciones | 🟡 Media | Baja | ⭐⭐⭐⭐ | 2-3d | 2 |
| 7 | Seguir Playlists | 🟡 Media | Baja | ⭐⭐⭐ | 2d | 2 |
| 8 | Compartir Contenido | 🟡 Media | Media | ⭐⭐⭐⭐ | 3-4d | 2 |
| 9 | Historial Reproducción | 🟡 Media | Media | ⭐⭐⭐ | 3-4d | 2 |
| 10 | Configuración | 🟡 Media | Media | ⭐⭐⭐ | 4-5d | 2 |
| 11 | Modo Offline | 🟢 Baja | Alta | ⭐⭐⭐⭐ | 10-12d | 3 |
| 12 | Subida Música | 🟢 Baja | Alta | ⭐⭐⭐⭐⭐ | 12-15d | 3 |
| 13 | Estadísticas Artistas | 🟢 Baja | Media-Alta | ⭐⭐⭐⭐ | 6-8d | 3 |
| 14 | Monetización | 🟢 Baja | Muy Alta | ⭐⭐⭐⭐⭐ | 20-30d | 4 |
| 15 | Notificaciones Push | 🟢 Baja | Media | ⭐⭐⭐⭐ | 5-7d | 3 |
| 16 | Reproductor Mejorado | 🟢 Baja | Media | ⭐⭐⭐ | 6-8d | 3 |
| 17 | Búsqueda Avanzada | 🟢 Baja | Media | ⭐⭐⭐ | 4-5d | 3 |
| 18 | Recomendaciones | 🟢 Baja | Alta | ⭐⭐⭐⭐⭐ | 15-20d | 4 |

---

## 🎯 Plan de Implementación Recomendado

### **FASE 1 - MVP Completo (20-30 días)**
**Objetivo:** Completar funciones críticas para una experiencia de usuario completa

1. ✅ Búsqueda Funcional (3-5 días)
2. ✅ Biblioteca Funcional - Parte 1: Favoritos y Playlists (5 días)
3. ✅ Autenticación Social (4-6 días)
4. ✅ Recuperación de Contraseña (3-4 días)
5. ✅ Biblioteca Funcional - Parte 2: Historial y Artistas Seguidos (3 días)

**Total estimado:** 18-23 días

---

### **FASE 2 - Engagement y Social (15-20 días)**
**Objetivo:** Aumentar engagement y funcionalidades sociales

1. ✅ Seguir Artistas (2-3 días)
2. ✅ Like/Dislike Canciones (2-3 días)
3. ✅ Seguir Playlists (2 días)
4. ✅ Compartir Contenido (3-4 días)
5. ✅ Historial de Reproducción (3-4 días)
6. ✅ Pantalla de Configuración (4-5 días)

**Total estimado:** 16-21 días

---

### **FASE 3 - Funcionalidades Avanzadas (30-40 días)**
**Objetivo:** Funcionalidades premium y para artistas

1. ✅ Modo Offline / Descargas (10-12 días)
2. ✅ Subida de Música para Artistas (12-15 días)
3. ✅ Estadísticas para Artistas (6-8 días)
4. ✅ Notificaciones Push (5-7 días)
5. ✅ Reproductor Mejorado (6-8 días)
6. ✅ Búsqueda Avanzada (4-5 días)

**Total estimado:** 43-55 días

---

### **FASE 4 - Monetización y ML (35-50 días)**
**Objetivo:** Modelo de negocio y recomendaciones inteligentes

1. ✅ Monetización para Artistas (20-30 días)
2. ✅ Recomendaciones Personalizadas (15-20 días)

**Total estimado:** 35-50 días

---

## 💡 Recomendaciones Técnicas

### **Backend - Endpoints Prioritarios a Crear:**

```typescript
// Búsqueda
GET /public/search?q={query}&type={song|artist|playlist}&limit={limit}&offset={offset}
GET /public/search/suggestions?q={query}

// Biblioteca
GET /users/me/library/favorites
POST /songs/:id/like
DELETE /songs/:id/like
GET /users/me/library/playlists
GET /users/me/library/downloads
GET /users/me/play-history
DELETE /users/me/play-history

// Social
POST /artists/:id/follow
DELETE /artists/:id/follow
GET /users/me/following/artists
POST /playlists/:id/follow
DELETE /playlists/:id/follow
GET /users/me/following/playlists

// Compartir
GET /songs/:id/share-link
GET /playlists/:id/share-link
GET /artists/:id/share-link

// Autenticación
POST /auth/google
POST /auth/apple
POST /auth/forgot-password
POST /auth/reset-password

// Configuración
GET /users/me/settings
PUT /users/me/settings
```

### **Frontend - Estructura de Carpetas Sugerida:**

```
lib/features/
├── search/
│   ├── screens/
│   │   └── search_screen.dart (completar)
│   ├── widgets/
│   │   ├── search_bar.dart
│   │   ├── search_results.dart
│   │   └── search_suggestion_item.dart
│   └── providers/
│       └── search_provider.dart
├── library/
│   ├── screens/
│   │   └── library_screen.dart (completar)
│   ├── widgets/
│   │   ├── favorites_section.dart
│   │   ├── playlists_section.dart
│   │   ├── downloads_section.dart
│   │   └── history_section.dart
│   └── providers/
│       └── library_provider.dart
├── social/
│   ├── widgets/
│   │   ├── follow_button.dart
│   │   ├── like_button.dart
│   │   └── share_button.dart
│   └── providers/
│       └── social_provider.dart
└── settings/
    ├── screens/
    │   └── settings_screen.dart
    └── widgets/
        ├── audio_quality_selector.dart
        └── notification_settings.dart
```

---

## ✅ Checklist de Implementación

### **Antes de Empezar:**
- [ ] Revisar endpoints del backend disponibles
- [ ] Crear endpoints faltantes en backend
- [ ] Documentar APIs con Swagger/OpenAPI
- [ ] Configurar variables de entorno necesarias
- [ ] Planificar estructura de base de datos (si hay cambios)

### **Durante Desarrollo:**
- [ ] Implementar tests unitarios para lógica de negocio
- [ ] Implementar tests de integración para APIs
- [ ] Documentar código complejo
- [ ] Revisar y optimizar rendimiento
- [ ] Validar UX con usuarios beta

### **Antes de Deploy:**
- [ ] Revisar seguridad (validación de inputs, rate limiting)
- [ ] Optimizar queries de base de datos
- [ ] Configurar monitoreo y logging
- [ ] Preparar rollback plan
- [ ] Documentar cambios en CHANGELOG

---

## 📝 Notas Finales

1. **Priorizar UX:** Las funciones de FASE 1 son críticas para una experiencia completa. Sin búsqueda y biblioteca funcional, la app se siente incompleta.

2. **Backend First:** Muchas funciones ya tienen el backend preparado (tablas, relaciones). Priorizar estas para desarrollo más rápido.

3. **Incremental:** Implementar funciones de forma incremental, probando cada una antes de pasar a la siguiente.

4. **Feedback:** Recopilar feedback de usuarios después de cada fase para ajustar prioridades.

5. **Performance:** Considerar impacto en rendimiento al agregar nuevas funciones, especialmente descargas y notificaciones.

---

**Última actualización:** $(date)  
**Versión del documento:** 1.0




