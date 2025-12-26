# 📢 FUNCIONALIDADES DEL SISTEMA DE ANUNCIOS DE AUDIO

## ✅ ESTADO GENERAL: **FUNCIONAL** (Backend y Frontend completos, Admin parcial)

---

## 🎯 FUNCIONES IMPLEMENTADAS Y ESTADO

### 🔧 BACKEND API (✅ COMPLETO)

#### **1. Gestión de Anuncios (CRUD)**
- ✅ **Crear anuncio** (`POST /api/v1/ads`)
  - Crea anuncio con todos los campos (título, descripción, anunciante, etc.)
  - Estado inicial: `draft` (borrador)
  - Validaciones completas
  
- ✅ **Listar anuncios** (`GET /api/v1/ads`)
  - Paginación (page, limit)
  - Filtro por estado (draft, active, paused, expired)
  - Ordenamiento por fecha de creación
  
- ✅ **Obtener anuncio por ID** (`GET /api/v1/ads/:id`)
  - Incluye relaciones (playLogs)
  - Manejo de errores 404
  
- ✅ **Actualizar anuncio** (`PATCH /api/v1/ads/:id`)
  - Actualización parcial de campos
  - Validaciones
  
- ✅ **Eliminar anuncio** (`DELETE /api/v1/ads/:id`)
  - Eliminación permanente
  - Manejo de errores

#### **2. Control de Estado**
- ✅ **Activar anuncio** (`POST /api/v1/ads/:id/activate`)
  - Cambia estado a `active`
  - Listo para reproducirse
  
- ✅ **Pausar anuncio** (`POST /api/v1/ads/:id/pause`)
  - Cambia estado a `paused`
  - No se reproducirá hasta reactivarlo

#### **3. Subida de Archivos**
- ⚠️ **Subir audio** (`POST /api/v1/ads/:id/upload-audio`)
  - **Estado**: Endpoint funcional, pero retorna URL placeholder
  - Validaciones: Tipo (MP3, AAC, OGG), tamaño (máx 5MB)
  - **TODO**: Integrar con servicio de almacenamiento real (S3/Local)
  
- ⚠️ **Subir carátula** (`POST /api/v1/ads/:id/upload-cover`)
  - **Estado**: Endpoint funcional, pero retorna URL placeholder
  - Validaciones: Tipo (JPG, PNG, WebP), tamaño (máx 2MB)
  - **TODO**: Integrar con servicio de almacenamiento real (S3/Local)

#### **4. Estadísticas**
- ✅ **Obtener estadísticas** (`GET /api/v1/ads/:id/stats`)
  - Total de reproducciones
  - Total de clicks
  - Tasa de finalización
  - Tasa de skip
  - Tasa de click-through
  - Duración promedio
  - Reproducciones recientes

#### **5. API Pública (Frontend App)**
- ✅ **Obtener siguiente anuncio** (`GET /api/v1/public-ads/next`)
  - **Algoritmo inteligente de selección**:
    - Filtra por estado activo
    - Verifica fechas de campaña (startDate, endDate)
    - Aplica targeting (género, artista, playlist)
    - Respeta frecuencia por hora (frequencyPerHour)
    - Respeta límite diario (maxPlaysPerDay)
    - Ordena por prioridad
    - Selección aleatoria entre top 3
  - Requiere autenticación (JWT)
  - Parámetros opcionales: `genre`, `artist`, `playlistId`
  
- ✅ **Registrar reproducción** (`POST /api/v1/public-ads/:id/log-play`)
  - Registra duración reproducida
  - Marca si fue completado o saltado
  - Guarda contexto (género, artista, playlist)
  - Incrementa contador de reproducciones
  - Requiere autenticación
  
- ✅ **Registrar click** (`POST /api/v1/public-ads/:id/log-click`)
  - Registra click en anuncio
  - Incrementa contador de clicks
  - Requiere autenticación

---

### 🎨 ADMIN PANEL (✅ PARCIALMENTE COMPLETO)

#### **1. Lista de Anuncios** (`/dashboard/ads`)
- ✅ **Visualización**
  - Tabla con todos los anuncios
  - Muestra: título, anunciante, duración, estado, estadísticas
  - Paginación funcional
  - Búsqueda por título o anunciante
  - Filtro por estado (draft, active, paused, expired)
  
- ✅ **Acciones rápidas**
  - Activar/Pausar desde la lista
  - Eliminar con confirmación
  - Navegar a edición
  - Ver estadísticas (botón presente, página pendiente)

#### **2. Crear Anuncio** (`/dashboard/ads/create`)
- ✅ **Formulario completo**
  - Información básica (título, descripción, anunciante, URL click-through)
  - Configuración de duración (5-60 segundos)
  - Upload de archivos (audio y carátula)
  - Validaciones de tipo y tamaño
  
- ✅ **Targeting avanzado**
  - Opciones: Todos / Por género / Por artista / Por playlist
  - Selector múltiple de géneros
  - Selector múltiple de artistas
  - (Playlist pendiente de implementar en UI)
  
- ✅ **Configuración de reproducción**
  - Frecuencia por hora (1-10)
  - Máximo de reproducciones por día (opcional)
  - Prioridad (0-100)
  - Skip configurable (saltable/no saltable)
  - Segundos antes de permitir skip (0-30)
  
- ✅ **Programación**
  - Fecha de inicio (opcional)
  - Fecha de fin (opcional)

#### **3. Funcionalidades Pendientes**
- ❌ **Editar anuncio** (`/dashboard/ads/:id`)
  - Backend listo, falta crear página de edición
  
- ❌ **Ver estadísticas** (`/dashboard/ads/:id/stats`)
  - Backend listo, falta crear página de visualización
  
- ⚠️ **Upload de archivos**
  - Frontend funcional, pero backend retorna URLs placeholder
  - Necesita integración con servicio de almacenamiento real

---

### 📱 FRONTEND APP (✅ COMPLETO)

#### **1. Servicios y Providers**
- ✅ **AdsService** (`apps/frontend/lib/features/ads/services/ads_service.dart`)
  - `getNextAd()`: Obtiene siguiente anuncio del backend
  - `logPlay()`: Registra reproducción
  - `logClick()`: Registra click
  - Manejo de errores completo
  
- ✅ **AdsProvider** (`apps/frontend/lib/features/ads/providers/ads_provider.dart`)
  - Provider Riverpod para estado de anuncios
  - Verificación de usuario premium (no muestra anuncios)
  - Métodos para obtener y registrar anuncios

#### **2. Integración con Reproducción**
- ✅ **PlaybackNotifier modificado**
  - `_checkAndInsertAd()`: Verifica y decide si insertar anuncio
    - Verifica usuario premium
    - Verifica cooldown (5 minutos entre anuncios)
    - Obtiene anuncio del backend con contexto
    - Inserta anuncio en cola
  
  - `_insertAdInQueue()`: Inserción optimizada
    - Usa `insertSongAtIndex()` para baja latencia
    - Identifica anuncios con `tag: AudioAd`
    - Actualiza estado de reproducción
    - Registra inicio de reproducción
  
  - `_handleAdCompletion()`: Manejo de finalización
    - Calcula duración reproducida
    - Registra en backend (completado o saltado)
    - Remueve anuncio de cola
    - Actualiza tracking (cooldown)
  
  - `skipAd()`: Método público para saltar anuncio
    - Registra skip en backend
    - Avanza a siguiente canción

#### **3. UI de Anuncios**
- ✅ **AdsMiniPlayer** (`apps/frontend/lib/features/ads/widgets/ads_mini_player.dart`)
  - Mini player específico para anuncios
  - Muestra carátula, título del anunciante
  - Badge "ANUNCIO"
  - Barra de progreso
  - Se muestra solo cuando `isPlayingAd = true`
  
- ✅ **AdsSkipButton** (`apps/frontend/lib/features/ads/widgets/ads_skip_button.dart`)
  - Botón de skip con countdown
  - Solo visible si `isSkippable = true`
  - Muestra "Saltar en X" durante countdown
  - Habilita botón después de `skipAfterSeconds`
  
- ✅ **AdDurationCounter** (`apps/frontend/lib/features/ads/widgets/ad_duration_counter.dart`)
  - Contador de duración restante
  - Solo visible si `isSkippable = false`
  - Formato MM:SS
  - Actualización en tiempo real

#### **4. Integración en Navegación**
- ✅ **MainNavigation** modificado
  - Prioriza `AdsMiniPlayer` sobre `FinalMiniPlayer`
  - Muestra anuncio cuando `isPlayingAd = true`
  - Oculta mini player normal durante anuncios

#### **5. Bloqueo de Controles**
- ✅ **ProfessionalAudioPlayer** modificado
  - Deshabilita controles durante anuncios:
    - Botón anterior/siguiente
    - Botón play/pause
    - Slider de progreso (no interactivo)
    - Botón shuffle
    - Botón repeat
  - Indicadores visuales de controles bloqueados

---

## 🔄 FLUJO COMPLETO DE FUNCIONAMIENTO

### **1. Creación de Anuncio (Admin)**
```
Admin → /dashboard/ads/create
  ↓
Completa formulario
  ↓
Sube archivo de audio (validación: tipo, tamaño)
  ↓
Sube carátula (opcional, validación: tipo, tamaño)
  ↓
Configura targeting, frecuencia, prioridad
  ↓
Crea anuncio (estado: draft)
  ↓
Activa anuncio (estado: active)
```

### **2. Reproducción de Anuncio (App)**
```
Usuario no premium reproduce canción
  ↓
Canción termina
  ↓
PlaybackNotifier._checkAndInsertAd()
  ↓
Verifica: ¿Premium? → No continúa
  ↓
Verifica: ¿Cooldown activo? → Si, espera
  ↓
Obtiene anuncio del backend (con contexto: género, artista)
  ↓
Backend aplica algoritmo de selección:
  - Filtra activos
  - Aplica targeting
  - Verifica frecuencia
  - Ordena por prioridad
  ↓
Retorna mejor anuncio
  ↓
PlaybackNotifier._insertAdInQueue()
  ↓
Inserta anuncio en cola (insertSongAtIndex)
  ↓
Reproduce anuncio automáticamente
  ↓
UI muestra AdsMiniPlayer
  ↓
Controles principales bloqueados
```

### **3. Finalización de Anuncio**
```
Anuncio termina o usuario lo salta
  ↓
PlaybackNotifier._handleAdCompletion()
  ↓
Calcula duración reproducida
  ↓
Registra en backend (logPlay)
  ↓
Backend incrementa contadores
  ↓
Remueve anuncio de cola
  ↓
Actualiza estado (isPlayingAd = false)
  ↓
Continúa con siguiente canción
```

---

## 📊 CARACTERÍSTICAS AVANZADAS IMPLEMENTADAS

### **1. Targeting Inteligente**
- ✅ Por género: Anuncio solo se muestra a usuarios escuchando ese género
- ✅ Por artista: Anuncio solo se muestra a usuarios escuchando ese artista
- ✅ Por playlist: Anuncio solo se muestra en playlists específicas
- ✅ Todos: Anuncio se muestra a todos los usuarios

### **2. Control de Frecuencia**
- ✅ Frecuencia por hora: Máximo X anuncios por hora por usuario
- ✅ Límite diario: Máximo X reproducciones por día por usuario
- ✅ Cooldown global: 5 minutos entre anuncios en la app

### **3. Priorización**
- ✅ Campo `priority` (0-100)
- ✅ Anuncios con mayor prioridad se seleccionan primero
- ✅ Selección aleatoria entre top 3 para variedad

### **4. Programación**
- ✅ Fecha de inicio: Anuncio no se muestra antes de esta fecha
- ✅ Fecha de fin: Anuncio no se muestra después de esta fecha
- ✅ Validación automática en backend

### **5. Anuncios No Saltables**
- ✅ Campo `isSkippable` en modelo
- ✅ UI adaptativa: Muestra skip button o contador según configuración
- ✅ Controles bloqueados durante anuncios no saltables
- ✅ Preparado para futuros anuncios de video saltables

### **6. Analytics y Logging**
- ✅ Registro de cada reproducción (duración, completado, saltado)
- ✅ Registro de clicks
- ✅ Contexto guardado (género, artista, playlist)
- ✅ Contadores automáticos (totalPlays, totalClicks)
- ✅ Estadísticas calculadas (completion rate, skip rate, CTR)

---

## ⚠️ FUNCIONALIDADES PENDIENTES O INCOMPLETAS

### **1. Upload de Archivos Real**
- ⚠️ **Estado**: Endpoints funcionan pero retornan URLs placeholder
- **Necesita**: Integrar con servicio de almacenamiento (S3, Local Storage, etc.)
- **Archivos afectados**:
  - `apps/backend/src/modules/ads/ads.controller.ts` (líneas 156-163, 203-210)

### **2. Página de Edición de Anuncio**
- ❌ **Estado**: No implementada
- **Backend**: ✅ Listo (`PATCH /api/v1/ads/:id`)
- **Frontend**: ❌ Falta crear `/dashboard/ads/:id/page.tsx`
- **Funcionalidad**: Similar a crear, pero pre-llenado con datos existentes

### **3. Página de Estadísticas**
- ❌ **Estado**: No implementada
- **Backend**: ✅ Listo (`GET /api/v1/ads/:id/stats`)
- **Frontend**: ❌ Falta crear `/dashboard/ads/:id/stats/page.tsx`
- **Funcionalidad**: Gráficos y métricas visuales

### **4. Targeting por Playlist en UI**
- ⚠️ **Estado**: Backend listo, UI no implementada
- **Falta**: Selector de playlists en formulario de creación

### **5. Preview de Audio**
- ❌ **Estado**: No implementado
- **Funcionalidad**: Reproducir audio antes de guardar en admin

---

## 🎯 RESUMEN DE ESTADO

| Componente | Estado | Funcionalidad |
|------------|--------|---------------|
| **Backend API** | ✅ 95% | CRUD completo, selección inteligente, logging |
| **Upload Archivos** | ⚠️ 50% | Validaciones OK, falta almacenamiento real |
| **Admin - Lista** | ✅ 100% | Visualización, filtros, acciones |
| **Admin - Crear** | ✅ 100% | Formulario completo con validaciones |
| **Admin - Editar** | ❌ 0% | Backend listo, falta UI |
| **Admin - Estadísticas** | ❌ 0% | Backend listo, falta UI |
| **Frontend - Servicios** | ✅ 100% | Comunicación con backend completa |
| **Frontend - Integración** | ✅ 100% | Reproducción automática funcional |
| **Frontend - UI** | ✅ 100% | Mini player, skip button, contadores |
| **Frontend - Controles** | ✅ 100% | Bloqueo durante anuncios |

---

## 🚀 PRÓXIMOS PASOS RECOMENDADOS

1. **Integrar almacenamiento real** para archivos de audio e imágenes
2. **Crear página de edición** de anuncios
3. **Crear página de estadísticas** con gráficos
4. **Agregar selector de playlists** en formulario de creación
5. **Implementar preview de audio** antes de guardar

---

## 📝 NOTAS TÉCNICAS

- **Cooldown**: 5 minutos entre anuncios en la app (configurable en código)
- **Latencia**: Inserción optimizada usando `insertSongAtIndex` para evitar delays perceptibles
- **Premium**: Usuarios premium nunca ven anuncios (verificación en múltiples capas)
- **Targeting**: Se aplica en backend, no en frontend (seguridad)
- **Logging**: Todos los eventos se registran con contexto para analytics

---

**Última actualización**: Diciembre 2025
**Versión**: 1.0.0















