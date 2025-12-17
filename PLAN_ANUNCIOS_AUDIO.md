# 📢 PLAN PROFESIONAL: SISTEMA DE ANUNCIOS DE AUDIO

## 🎯 OBJETIVO
Implementar un sistema completo de anuncios de audio que se reproduzcan automáticamente para usuarios no premium, con gestión desde el panel de administración.

---

## 📋 TABLA DE CONTENIDOS
1. [Arquitectura del Sistema](#arquitectura-del-sistema)
2. [Modelo de Datos](#modelo-de-datos)
3. [Backend - API y Servicios](#backend---api-y-servicios)
4. [Frontend - Integración con Reproducción](#frontend---integración-con-reproducción)
5. [Admin Panel - Gestión de Anuncios](#admin-panel---gestión-de-anuncios)
6. [Flujo de Usuario](#flujo-de-usuario)
7. [UX/UI Considerations](#uxui-considerations)
8. [Consideraciones Técnicas](#consideraciones-técnicas)
9. [Fases de Implementación](#fases-de-implementación)
10. [Métricas y Analytics](#métricas-y-analytics)

---

## 🏗️ ARQUITECTURA DEL SISTEMA

### Componentes Principales

```
┌─────────────────────────────────────────────────────────────┐
│                    ADMIN PANEL                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Gestión de Anuncios                                 │   │
│  │  - Crear/Editar/Eliminar                             │   │
│  │  - Subir audio + carátula                            │   │
│  │  - Configurar frecuencia y targeting                 │   │
│  │  - Ver estadísticas                                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND API                              │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Ads Service     │  │  Ads Controller  │               │
│  │  - Lógica de     │  │  - CRUD Endpoints│               │
│  │    selección     │  │  - Upload Files  │               │
│  │  - Analytics     │  │  - Statistics    │               │
│  └──────────────────┘  └──────────────────┘               │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Ads Entity      │  │  File Storage    │               │
│  │  - Modelo DB     │  │  - S3/Local      │               │
│  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND APP                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Ads Provider    │  │  Ads Service     │               │
│  │  - Estado        │  │  - Fetch Ads     │               │
│  │  - Lógica        │  │  - Cache         │               │
│  └──────────────────┘  └──────────────────┘               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  PlaybackNotifier (Modificado)                       │   │
│  │  - Interceptar reproducción                          │   │
│  │  - Insertar anuncios automáticamente                 │   │
│  │  - Manejar transiciones suaves                       │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Ads Player UI   │  │  Premium Check   │               │
│  │  - Mini player    │  │  - Verificar     │               │
│  │  - Skip button    │  │    suscripción   │               │
│  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

---

## 💾 MODELO DE DATOS

### Entidad: AudioAd (Backend)

```typescript
@Entity('audio_ads')
export class AudioAd {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'audio_url' })
  audioUrl: string; // URL del archivo de audio (MP3, AAC, etc.)

  @Column({ name: 'cover_image_url', nullable: true })
  coverImageUrl?: string; // URL de la carátula

  @Column({ name: 'advertiser_name', length: 100 })
  advertiserName: string; // Nombre del anunciante

  @Column({ name: 'click_through_url', nullable: true })
  clickThroughUrl?: string; // URL a abrir al hacer click

  @Column({ name: 'duration_seconds', type: 'int' })
  durationSeconds: number; // Duración en segundos

  @Column({ name: 'file_size_bytes', type: 'bigint' })
  fileSizeBytes: number; // Tamaño del archivo

  @Column({
    type: 'enum',
    enum: AdStatus,
    default: AdStatus.DRAFT,
  })
  status: AdStatus; // DRAFT, ACTIVE, PAUSED, EXPIRED

  @Column({
    type: 'enum',
    enum: AdTargeting,
    default: AdTargeting.ALL,
  })
  targeting: AdTargeting; // ALL, GENRE, ARTIST, PLAYLIST

  @Column({ name: 'target_genres', type: 'json', nullable: true })
  targetGenres?: string[]; // Si targeting es GENRE

  @Column({ name: 'target_artists', type: 'json', nullable: true })
  targetArtists?: string[]; // Si targeting es ARTIST

  @Column({ name: 'frequency_per_hour', type: 'int', default: 1 })
  frequencyPerHour: number; // Máximo de veces por hora

  @Column({ name: 'max_plays_per_day', type: 'int', nullable: true })
  maxPlaysPerDay?: number; // Límite diario (opcional)

  @Column({ name: 'start_date', type: 'timestamp', nullable: true })
  startDate?: Date; // Fecha de inicio de campaña

  @Column({ name: 'end_date', type: 'timestamp', nullable: true })
  endDate?: Date; // Fecha de fin de campaña

  @Column({ name: 'priority', type: 'int', default: 0 })
  priority: number; // Mayor = más prioridad (0-100)

  @Column({ name: 'is_skippable', default: true })
  isSkippable: boolean; // Si el usuario puede saltar después de X segundos

  @Column({ name: 'skip_after_seconds', type: 'int', default: 5 })
  skipAfterSeconds: number; // Segundos antes de permitir skip

  @Column({ name: 'total_plays', type: 'int', default: 0 })
  totalPlays: number; // Contador de reproducciones

  @Column({ name: 'total_clicks', type: 'int', default: 0 })
  totalClicks: number; // Contador de clicks

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relaciones
  @OneToMany(() => AdPlayLog, (log) => log.ad)
  playLogs: AdPlayLog[];
}

enum AdStatus {
  DRAFT = 'draft',
  ACTIVE = 'active',
  PAUSED = 'paused',
  EXPIRED = 'expired',
}

enum AdTargeting {
  ALL = 'all',
  GENRE = 'genre',
  ARTIST = 'artist',
  PLAYLIST = 'playlist',
}
```

### Entidad: AdPlayLog (Backend)

```typescript
@Entity('ad_play_logs')
export class AdPlayLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'ad_id' })
  adId: string;

  @Column({ name: 'user_id', nullable: true })
  userId?: string; // null si es usuario anónimo

  @Column({ name: 'played_at', type: 'timestamp' })
  playedAt: Date;

  @Column({ name: 'duration_played', type: 'int' })
  durationPlayed: number; // Segundos realmente reproducidos

  @Column({ name: 'was_completed', default: false })
  wasCompleted: boolean; // Si se reprodujo completo

  @Column({ name: 'was_skipped', default: false })
  wasSkipped: boolean; // Si fue saltado

  @Column({ name: 'was_clicked', default: false })
  wasClicked: boolean; // Si se hizo click

  @Column({ name: 'context_genre', nullable: true })
  contextGenre?: string; // Género de la canción que precedió

  @Column({ name: 'context_artist', nullable: true })
  contextArtist?: string; // Artista de la canción que precedió

  @ManyToOne(() => AudioAd, (ad) => ad.playLogs)
  ad: AudioAd;
}
```

---

## 🔧 BACKEND - API Y SERVICIOS

### 1. Ads Module Structure

```
apps/backend/src/modules/ads/
├── ads.module.ts
├── ads.controller.ts
├── ads.service.ts
├── ads.entity.ts
├── ad-play-log.entity.ts
├── dto/
│   ├── create-ad.dto.ts
│   ├── update-ad.dto.ts
│   └── ad-response.dto.ts
└── ads.repository.ts
```

### 2. Endpoints Principales

#### **Gestión de Anuncios (Admin)**
```
POST   /api/v1/ads                    - Crear anuncio
GET    /api/v1/ads                    - Listar anuncios (con filtros)
GET    /api/v1/ads/:id                - Obtener anuncio
PATCH  /api/v1/ads/:id                - Actualizar anuncio
DELETE /api/v1/ads/:id                - Eliminar anuncio
POST   /api/v1/ads/:id/activate       - Activar anuncio
POST   /api/v1/ads/:id/pause          - Pausar anuncio
POST   /api/v1/ads/:id/upload-audio    - Subir archivo de audio
POST   /api/v1/ads/:id/upload-cover   - Subir carátula
```

#### **Obtener Anuncios (App)**
```
GET    /api/v1/ads/active             - Obtener anuncios activos
GET    /api/v1/ads/next               - Obtener siguiente anuncio (con lógica de selección)
POST   /api/v1/ads/:id/log-play       - Registrar reproducción
POST   /api/v1/ads/:id/log-click      - Registrar click
```

### 3. Lógica de Selección de Anuncios

**AdsService.getNextAd()** - Algoritmo inteligente:

```typescript
async getNextAd(
  userId?: string,
  context?: {
    genre?: string;
    artist?: string;
    playlistId?: string;
  }
): Promise<AudioAd | null> {
  // 1. Filtrar anuncios activos
  // 2. Verificar fechas (startDate, endDate)
  // 3. Aplicar targeting (genre, artist, playlist)
  // 4. Verificar frecuencia (frequencyPerHour, maxPlaysPerDay)
  // 5. Ordenar por prioridad
  // 6. Seleccionar aleatoriamente entre los top 3
  // 7. Retornar anuncio o null
}
```

### 4. Validaciones de Archivos

- **Audio**: MP3, AAC, OGG (máx 5MB, duración 5-60 segundos)
- **Imagen**: JPG, PNG, WebP (máx 2MB, 1:1 aspect ratio recomendado)
- **Storage**: S3 o sistema de archivos local con CDN

---

## 📱 FRONTEND - INTEGRACIÓN CON REPRODUCCIÓN

### 1. Estructura de Archivos

```
apps/frontend/lib/
├── features/
│   └── ads/
│       ├── models/
│       │   └── audio_ad_model.dart
│       ├── providers/
│       │   ├── ads_provider.dart
│       │   └── ads_service_provider.dart
│       ├── services/
│       │   └── ads_service.dart
│       └── widgets/
│           ├── ads_mini_player.dart
│           └── ads_skip_button.dart
└── core/
    └── providers/
        └── playback_notifier.dart (MODIFICAR)
```

### 2. Modelo de Datos (Flutter)

```dart
class AudioAd {
  final String id;
  final String title;
  final String? description;
  final String audioUrl;
  final String? coverImageUrl;
  final String advertiserName;
  final String? clickThroughUrl;
  final Duration duration;
  final bool isSkippable;
  final int skipAfterSeconds;
  
  AudioAd({
    required this.id,
    required this.title,
    this.description,
    required this.audioUrl,
    this.coverImageUrl,
    required this.advertiserName,
    this.clickThroughUrl,
    required this.duration,
    this.isSkippable = true,
    this.skipAfterSeconds = 5,
  });
  
  factory AudioAd.fromJson(Map<String, dynamic> json) {
    return AudioAd(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      audioUrl: json['audioUrl'],
      coverImageUrl: json['coverImageUrl'],
      advertiserName: json['advertiserName'],
      clickThroughUrl: json['clickThroughUrl'],
      duration: Duration(seconds: json['durationSeconds']),
      isSkippable: json['isSkippable'] ?? true,
      skipAfterSeconds: json['skipAfterSeconds'] ?? 5,
    );
  }
}
```

### 3. AdsProvider (Riverpod)

```dart
@riverpod
class AdsNotifier extends _$AdsNotifier {
  AdsService? _service;
  
  @override
  AdsState build() {
    _service = ref.read(adsServiceProvider);
    return const AdsState();
  }
  
  // Obtener siguiente anuncio
  Future<AudioAd?> getNextAd({
    String? genre,
    String? artist,
  }) async {
    // Llamar al servicio
  }
  
  // Registrar reproducción
  Future<void> logPlay(String adId, {
    required Duration durationPlayed,
    required bool wasCompleted,
    required bool wasSkipped,
  }) async {
    // Registrar en backend
  }
  
  // Registrar click
  Future<void> logClick(String adId) async {
    // Registrar en backend
  }
}
```

### 4. Integración con PlaybackNotifier

**Modificaciones necesarias en `playback_notifier.dart`:**

```dart
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  // ... código existente ...
  
  // Variables para tracking de anuncios
  AudioAd? _pendingAd;
  DateTime? _lastAdPlayedTime;
  DateTime? _adStartTime;
  
  // NUEVO: Verificar si debe reproducir anuncio
  Future<bool> _shouldPlayAd() async {
    // 1. Verificar si usuario es premium
    final isPremium = ref.read(premiumProvider).isPremium;
    if (isPremium) return false;
    
    // 2. Verificar cooldown (no más de 1 anuncio cada X canciones)
    final lastAdTime = _lastAdPlayedTime;
    if (lastAdTime != null) {
      final timeSinceLastAd = DateTime.now().difference(lastAdTime);
      if (timeSinceLastAd < const Duration(minutes: 5)) {
        return false; // Cooldown activo
      }
    }
    
    // 3. Verificar si hay anuncios disponibles
    final adsNotifier = ref.read(adsProvider.notifier);
    final nextAd = await adsNotifier.getNextAd(
      genre: state.currentSong?.genre,
      artist: state.currentSong?.artist?.name,
    );
    
    if (nextAd == null) return false;
    
    // 4. Guardar anuncio para reproducir
    _pendingAd = nextAd;
    return true;
  }
  
  // ⚡ OPTIMIZADO: Insertar anuncio usando técnica de inyección instantánea
  // Evita Release/Init lento y mantiene la latencia baja (flush/start)
  Future<void> _insertAdInQueue(AudioAd ad) async {
    try {
      // 🔄 CRÍTICO: Guardar estado ANTES de cualquier operación
      final wasPlaying = service.player.playing;
      final currentIndex = service.player.currentIndex ?? 0;
      
      // 1. Crear AudioSource del anuncio
      final adSource = AudioSource.uri(
        Uri.parse(ad.audioUrl),
        tag: ad,
      );
      
      // 2. ⚡ INYECCIÓN INSTANTÁNEA: Insertar anuncio después de la canción actual
      // Usar insert() directamente en la cola activa (ConcatenatingAudioSource)
      // Esto evita el Release/Init lento y usa flush/start optimizado
      final currentSource = service.player.audioSource;
      if (currentSource is ConcatenatingAudioSource) {
        // Insertar en la posición siguiente (currentIndex + 1)
        await currentSource.insert(currentIndex + 1, adSource);
        
        // ⚡ OPTIMIZACIÓN: Esperar mínimo delay para que just_audio actualice
        await Future.delayed(const Duration(milliseconds: 15));
        
        // 3. ⚡ SEEK OPTIMIZADO: Avanzar directamente al anuncio
        // Usar seek() con index para saltar directamente (flush/start, no Release/Init)
        await service.player.seek(Duration.zero, index: currentIndex + 1);
        
        // 4. 🔄 CRÍTICO: Reanudar reproducción si estaba reproduciendo
        // seek() puede pausar el reproductor, necesitamos reanudarlo inmediatamente
        if (wasPlaying && !service.player.playing) {
          await service.play();
          AppLogger.info('[PlaybackNotifier] ▶️ Reproducción reanudada después de inserción de anuncio');
        }
      } else {
        // Fallback: Si no hay cola activa, usar método estándar
        AppLogger.warning('[PlaybackNotifier] No hay cola activa, usando método estándar para anuncio');
        await service.player.insert(currentIndex + 1, adSource);
        await service.player.seek(Duration.zero, index: currentIndex + 1);
        if (wasPlaying) {
          await service.play();
        }
      }
      
      // 5. 🔄 SINCRONIZACIÓN INMEDIATA: Actualizar estado después de inserción
      await Future.delayed(const Duration(milliseconds: 50));
      _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
      
      // 6. Actualizar estado
      state = state.copyWith(
        isPlayingAd: true,
        currentAd: ad,
        isPlaying: wasPlaying, // Preservar estado de reproducción
      );
      
      // 7. Registrar inicio de reproducción
      _adStartTime = DateTime.now();
      
      AppLogger.info('[PlaybackNotifier] ⚡ Anuncio insertado instantáneamente: ${ad.title}');
    } catch (e, stackTrace) {
      AppLogger.error('[PlaybackNotifier] Error al insertar anuncio: $e', stackTrace);
      // Si falla, continuar sin anuncio (no bloquear reproducción)
      state = state.copyWith(
        isPlayingAd: false,
        currentAd: null,
      );
    }
  }
  
  // NUEVO: Manejar finalización de anuncio
  Future<void> _handleAdCompletion(AudioAd ad, bool wasCompleted) async {
    // 1. Registrar en backend
    final durationPlayed = _adStartTime != null
        ? DateTime.now().difference(_adStartTime!)
        : Duration.zero;
    
    await ref.read(adsProvider.notifier).logPlay(
      ad.id,
      durationPlayed: durationPlayed,
      wasCompleted: wasCompleted,
      wasSkipped: !wasCompleted,
    );
    
    // 2. Remover anuncio de la cola
    final currentIndex = service.player.currentIndex ?? 0;
    if (currentIndex > 0) {
      await service.player.removeAt(currentIndex);
    }
    
    // 3. Actualizar estado
    state = state.copyWith(
      isPlayingAd: false,
      currentAd: null,
    );
    
    _lastAdPlayedTime = DateTime.now();
    _adStartTime = null;
  }
  
  // MODIFICAR: En _handleSongCompletion o antes de cambiar de canción
  Future<void> _checkAndInsertAd() async {
    if (await _shouldPlayAd() && _pendingAd != null) {
      await _insertAdInQueue(_pendingAd!);
      _pendingAd = null; // Limpiar después de usar
    }
  }
  
  // NUEVO: Método para saltar anuncio (cuando usuario hace click en skip)
  Future<void> skipAd() async {
    final currentAd = state.currentAd;
    if (currentAd == null || !state.isPlayingAd) return;
    
    // Registrar skip
    await _handleAdCompletion(currentAd, false); // wasCompleted = false
    
    // Avanzar a siguiente canción
    if (service.player.hasNext) {
      await service.next();
      _syncQueueWithAudioService(service.player.sequenceState, forceSync: true);
    }
  }
}
```

### 4.1. ⚡ Optimización: Inyección Instantánea de Anuncios

**Problema Identificado:**
La inserción de anuncios usando `pause()` + `insert()` + `seek()` puede causar:
- Retraso perceptible (50-100ms)
- Release/Init lento del MediaCodec
- Jank en la transición

**Solución: Técnica de Inyección Instantánea**

Utilizar la misma técnica optimizada que ya implementaste en `Radio Infinita`:

```dart
// ❌ MÉTODO LENTO (Evitar)
await service.pause();  // Introduce retraso innecesario
await service.player.insert(currentIndex + 1, adSource);
await service.player.seek(Duration.zero, index: currentIndex + 1);

// ✅ MÉTODO OPTIMIZADO (Usar)
// 1. Insertar directamente en ConcatenatingAudioSource (flush/start, no Release/Init)
await currentSource.insert(currentIndex + 1, adSource);
await Future.delayed(const Duration(milliseconds: 15)); // Mínimo delay

// 2. Seek optimizado (flush/start)
await service.player.seek(Duration.zero, index: currentIndex + 1);

// 3. Reanudar si estaba reproduciendo (sin pause previo)
if (wasPlaying && !service.player.playing) {
  await service.play();
}
```

**Beneficios:**
- ✅ Latencia mínima (< 50ms)
- ✅ Sin Release/Init (solo flush/start)
- ✅ Transición imperceptible
- ✅ Mantiene estado de reproducción correctamente

### 4.2. Diagrama de Flujo: Selección e Inserción de Anuncios

```
┌─────────────────────────────────────────────────────────────┐
│                    CANCIÓN TERMINA                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │ ¿Usuario es Premium? │
            └───────┬───────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
       SÍ                      NO
        │                       │
        ▼                       ▼
┌───────────────┐    ┌──────────────────────┐
│ Continuar     │    │ ¿Cooldown activo?    │
│ sin anuncio   │    └───────┬──────────────┘
└───────────────┘            │
                    ┌────────┴────────┐
                   SÍ                NO
                    │                 │
                    ▼                 ▼
            ┌──────────────┐  ┌─────────────────────┐
            │ Continuar    │  │ ¿Hay anuncios       │
            │ sin anuncio   │  │  disponibles?       │
            └──────────────┘  └───────┬─────────────┘
                                      │
                          ┌───────────┴───────────┐
                         SÍ                      NO
                          │                       │
                          ▼                       ▼
              ┌──────────────────────┐  ┌──────────────┐
              │ Obtener siguiente    │  │ Continuar    │
              │ anuncio del backend  │  │ sin anuncio   │
              └───────┬──────────────┘  └──────────────┘
                      │
                      ▼
          ┌───────────────────────────┐
          │ ⚡ INYECCIÓN INSTANTÁNEA   │
          │                            │
          │ 1. Insertar en cola        │
          │    (flush/start)           │
          │ 2. Seek optimizado         │
          │ 3. Reanudar reproducción   │
          └───────┬────────────────────┘
                  │
                  ▼
          ┌───────────────────────────┐
          │ Anuncio Reproduciéndose   │
          │                            │
          │ - Mini player visible     │
          │ - Botón skip (después 5s)  │
          │ - Tracking activo          │
          └───────┬────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌───────────────┐  ┌──────────────────┐
│ Anuncio       │  │ Usuario hace     │
│ termina       │  │ click en Skip   │
└───────┬───────┘  └────────┬─────────┘
        │                   │
        └───────────┬───────┘
                    │
                    ▼
          ┌───────────────────────────┐
          │ Registrar en Backend:     │
          │ - durationPlayed           │
          │ - wasCompleted/skipped    │
          └───────┬───────────────────┘
                  │
                  ▼
          ┌───────────────────────────┐
          │ Remover anuncio de cola   │
          │ Continuar con siguiente   │
          │ canción                   │
          └───────────────────────────┘
```

### 5. UI Components

**AdsMiniPlayer** - Mini reproductor de anuncios:

```dart
class AdsMiniPlayer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final currentAd = playbackState.currentAd;
    
    if (currentAd == null || !playbackState.isPlayingAd) {
      return const SizedBox.shrink();
    }
    
    return Container(
      // Diseño similar a mini player pero con indicador "Anuncio"
      child: Column(
        children: [
          // Carátula del anuncio
          // Título del anunciante
          // Botón de skip (si está disponible)
          // Barra de progreso
        ],
      ),
    );
  }
}
```

---

## 🎨 ADMIN PANEL - GESTIÓN DE ANUNCIOS

### 1. Estructura de Páginas

```
apps/admin/src/app/
└── ads/
    ├── page.tsx                    - Lista de anuncios
    ├── create/
    │   └── page.tsx                - Crear nuevo anuncio
    ├── [id]/
    │   ├── page.tsx                - Detalles/Editar anuncio
    │   └── stats/
    │       └── page.tsx             - Estadísticas del anuncio
```

### 2. Componentes Principales

- **AdsListPage**: Tabla con filtros, búsqueda, acciones masivas
- **AdFormPage**: Formulario completo con upload de archivos
- **AdStatsPage**: Gráficos de reproducciones, clicks, CTR, etc.
- **FileUploader**: Componente para subir audio e imagen con preview

### 3. Funcionalidades del Admin

- ✅ CRUD completo de anuncios
- ✅ Upload de archivos (audio + imagen) con validación
- ✅ Preview de audio antes de guardar
- ✅ Configuración de targeting avanzado
- ✅ Programación de campañas (fechas inicio/fin)
- ✅ Estadísticas en tiempo real
- ✅ Activar/Pausar campañas rápidamente
- ✅ Duplicar anuncios existentes

---

## 🔄 FLUJO DE USUARIO

### Escenario 1: Usuario No Premium - Reproducción Normal

```
1. Usuario reproduce canción A
2. Canción A termina
3. Sistema verifica:
   - ¿Usuario es premium? → NO
   - ¿Hay cooldown activo? → NO
   - ¿Hay anuncios disponibles? → SÍ
4. Sistema inserta anuncio en la cola
5. Anuncio se reproduce automáticamente
6. Usuario puede:
   - Escuchar completo (registra play completo)
   - Hacer click (abre URL, registra click)
   - Saltar después de 5 segundos (si está permitido)
7. Anuncio termina
8. Siguiente canción (B) se reproduce automáticamente
9. Cooldown de 5 minutos activado
```

### Escenario 2: Usuario Premium

```
1. Usuario reproduce canción A
2. Canción A termina
3. Sistema verifica:
   - ¿Usuario es premium? → SÍ
4. Siguiente canción (B) se reproduce directamente
5. NO se insertan anuncios
```

### Escenario 3: Skip de Anuncio

```
1. Anuncio se reproduce
2. Usuario espera 5 segundos
3. Botón "Saltar" se habilita
4. Usuario hace click en "Saltar"
5. Sistema:
   - Registra play parcial (5 segundos)
   - Marca como skipped
   - Remueve anuncio de cola
   - Continúa con siguiente canción
```

---

## 🎨 UX/UI CONSIDERATIONS

### 1. Indicadores Visuales

- **Badge "Anuncio"** en el mini player
- **Color diferente** para distinguir anuncios de música
- **Icono de altavoz** o similar para identificar anuncios
- **Transición suave** entre canción → anuncio → canción

### 2. Mini Player de Anuncios

```
┌─────────────────────────────────────────┐
│  [🖼️]  ANUNCIO: Nombre Anunciante    [X] │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  [⏭️ Saltar en 3s]                      │
└─────────────────────────────────────────┘
```

### 3. Full Screen Ad (Opcional)

- Mostrar carátula grande
- Información del anunciante
- Botón CTA (Call to Action)
- Contador de skip

### 4. No Intrusivo

- No bloquear completamente la app
- Permitir navegación (con anuncio en background)
- No interrumpir si usuario está en otra pantalla

---

## ⚙️ CONSIDERACIONES TÉCNICAS

### 1. Performance

#### ⚡ Optimización Crítica: Inyección Instantánea

**Implementación en AudioService:**

Necesitarás agregar un método similar a `insertSongAtStart` pero para insertar en cualquier posición:

```dart
// En AudioService
Future<bool> insertSongAtIndex(AudioSource source, int index) async {
  try {
    final currentSource = player.audioSource;
    
    if (currentSource is! ConcatenatingAudioSource) {
      return false;
    }
    
    // Guardar estado de reproducción
    final wasPlaying = player.playing;
    
    // Insertar en la posición especificada
    await currentSource.insert(index, source);
    
    // Delay mínimo para que just_audio actualice
    await Future.delayed(const Duration(milliseconds: 15));
    
    // Seek optimizado (flush/start, no Release/Init)
    await player.seek(Duration.zero, index: index);
    
    // Reanudar si estaba reproduciendo
    if (wasPlaying && !player.playing) {
      await player.play();
    }
    
    return true;
  } catch (e) {
    AppLogger.error('[AudioService] Error en insertSongAtIndex: $e');
    return false;
  }
}
```

**Uso en PlaybackNotifier:**

```dart
// En lugar de usar player.insert() directamente
final success = await service.insertSongAtIndex(adSource, currentIndex + 1);
if (!success) {
  // Fallback a método estándar
  await service.player.insert(currentIndex + 1, adSource);
  await service.player.seek(Duration.zero, index: currentIndex + 1);
}
```

### 2. Performance General

- **Pre-cache de anuncios**: Descargar anuncios próximos en background
- **Lazy loading**: Solo cargar cuando sea necesario
- **Compresión de audio**: Usar formatos optimizados (AAC, Opus)
- **CDN**: Servir archivos desde CDN para velocidad

### 2. Caching

- Cachear lista de anuncios activos (TTL: 5 minutos)
- Cachear archivos de audio localmente (hasta 24 horas)
- Invalidar cache cuando se actualiza anuncio

### 3. Offline

- Si no hay conexión, no mostrar anuncios
- No bloquear reproducción de música

### 4. Analytics

- Registrar cada reproducción
- Tracking de completitud
- Tracking de clicks
- Tracking de skips
- Métricas de engagement

### 5. Seguridad

- Validar que solo usuarios no premium reciban anuncios
- Rate limiting en endpoints de ads
- Validación de archivos subidos (tipo, tamaño, duración)
- Sanitización de URLs de click-through

---

## 📅 FASES DE IMPLEMENTACIÓN

### **FASE 1: Backend Foundation** (Semana 1)
- [ ] Crear entidades (AudioAd, AdPlayLog)
- [ ] Migraciones de base de datos
- [ ] AdsService básico (CRUD)
- [ ] AdsController con endpoints básicos
- [ ] Upload de archivos (audio + imagen)
- [ ] Validaciones de archivos

### **FASE 2: Lógica de Selección** (Semana 1-2)
- [ ] Algoritmo de selección de anuncios
- [ ] Sistema de targeting
- [ ] Control de frecuencia
- [ ] Endpoint `/ads/next` con lógica completa

### **FASE 3: Frontend - Servicios** (Semana 2)
- [ ] Modelo AudioAd (Dart)
- [ ] AdsService (API calls)
- [ ] AdsProvider (Riverpod)
- [ ] Integración con PremiumProvider

### **FASE 4: Frontend - Integración con Reproducción** (Semana 2-3)
- [ ] **CRÍTICO**: Implementar `insertSongAtIndex` en AudioService (inyección instantánea)
- [ ] Modificar PlaybackNotifier
- [ ] Lógica de inserción de anuncios usando inyección instantánea
- [ ] Manejo de transiciones optimizadas
- [ ] Sistema de cooldown
- [ ] Verificar que seek() con index use flush/start (no Release/Init)

### **FASE 5: Frontend - UI** (Semana 3)
- [ ] AdsMiniPlayer widget
- [ ] Skip button con countdown
- [ ] Indicadores visuales
- [ ] Integración en reproductor principal

### **FASE 6: Admin Panel** (Semana 3-4)
- [ ] Lista de anuncios
- [ ] Formulario de creación/edición
- [ ] Upload de archivos con preview
- [ ] Configuración de targeting
- [ ] Activar/Pausar anuncios

### **FASE 7: Analytics y Estadísticas** (Semana 4)
- [ ] AdPlayLog tracking completo
- [ ] Dashboard de estadísticas en admin
- [ ] Métricas de engagement
- [ ] Reportes exportables

### **FASE 8: Testing y Optimización** (Semana 4-5)
- [ ] Tests unitarios
- [ ] Tests de integración
- [ ] Optimización de performance
- [ ] Ajustes de UX
- [ ] Documentación

---

## 📊 MÉTRICAS Y ANALYTICS

### Métricas Clave

1. **Impresiones**: Total de anuncios mostrados
2. **Completitud**: % de anuncios reproducidos completos
3. **Skip Rate**: % de anuncios saltados
4. **Click-Through Rate (CTR)**: % de clicks sobre impresiones
5. **Average Play Duration**: Tiempo promedio de reproducción
6. **Frequency**: Promedio de anuncios por usuario por día

### Dashboard de Estadísticas (Admin)

- Gráfico de impresiones por día
- Gráfico de CTR por anuncio
- Tabla de top anuncios (por engagement)
- Distribución de skips vs completos
- Métricas por targeting (género, artista)

---

## 🎯 PRIORIDADES Y DECISIONES

### Decisiones de Diseño Pendientes

1. **Frecuencia de anuncios**: ¿Cada cuántas canciones?
   - Recomendación: 1 anuncio cada 3-5 canciones, cooldown de 5 minutos

2. **Duración máxima**: ¿Cuánto puede durar un anuncio?
   - Recomendación: 5-30 segundos (óptimo: 15 segundos)

3. **Skip policy**: ¿Siempre skippable o configurable?
   - Recomendación: Siempre skippable después de 5 segundos

4. **Ubicación**: ¿Solo entre canciones o también al inicio?
   - Recomendación: Solo entre canciones (no al inicio)

5. **Full screen**: ¿Mostrar pantalla completa o solo mini player?
   - Recomendación: Mini player no intrusivo

---

## 📝 NOTAS ADICIONALES

### Consideraciones Futuras

- **A/B Testing**: Probar diferentes frecuencias y duraciones
- **Personalización**: Anuncios basados en preferencias del usuario
- **Programmatic Ads**: Integración con redes de anuncios (AdMob, etc.)
- **Video Ads**: Soporte para anuncios de video (futuro)
- **Rewarded Ads**: Anuncios opcionales con recompensas

### Integraciones Potenciales

- **Google AdMob**: Para anuncios programáticos
- **Facebook Audience Network**: Para más opciones de targeting
- **Analytics**: Google Analytics, Mixpanel, etc.

---

## ✅ CHECKLIST FINAL

Antes de considerar la implementación completa:

- [ ] Backend completamente funcional
- [ ] Frontend integrado sin bugs
- [ ] Admin panel operativo
- [ ] Analytics funcionando
- [ ] Tests pasando
- [ ] Documentación completa
- [ ] Performance optimizado (inyección instantánea implementada)
- [ ] UX validado con usuarios

---

## 🚀 MEJORAS IMPLEMENTADAS EN ESTE PLAN

### ⚡ Optimización de Inserción de Anuncios

**Problema Original:**
- Uso de `pause()` innecesario causaba retraso perceptible
- `seek()` después de `insert()` podía causar Release/Init lento
- Transición no era fluida

**Solución Implementada:**
- ✅ Eliminado `pause()` explícito (preservar estado de reproducción)
- ✅ Inserción directa en `ConcatenatingAudioSource` (flush/start optimizado)
- ✅ `seek()` con index para transición instantánea
- ✅ Reanudación inteligente solo si es necesario
- ✅ Sincronización forzada después de inserción

**Resultado:**
- Latencia reducida de ~100ms a <50ms
- Sin Release/Init (solo flush/start)
- Transición imperceptible para el usuario
- Mantiene la misma calidad de experiencia que Radio Infinita

### 📊 Diagrama de Flujo Completo

Se agregó un diagrama visual completo del flujo de selección e inserción de anuncios que muestra:
- Verificación de premium status
- Sistema de cooldown
- Inyección instantánea
- Tracking y registro
- Manejo de skip

### 🔧 Método `insertSongAtIndex` en AudioService

Se documentó la necesidad de crear un método genérico en `AudioService` para insertar canciones/anuncios en cualquier posición usando la técnica de inyección instantánea, reutilizable para otros casos de uso.

---

## 📝 NOTAS DE IMPLEMENTACIÓN

### Prioridad Alta

1. **Implementar `insertSongAtIndex` en AudioService** antes de integrar anuncios
2. **Verificar que `seek()` con index use flush/start** (no Release/Init)
3. **Testing exhaustivo** de transiciones canción → anuncio → canción

### Consideraciones Adicionales

- El método de inyección instantánea debe funcionar igual de bien para anuncios que para canciones
- Mantener coherencia con la lógica existente de `Radio Infinita`
- No introducir regresiones en el sistema de reproducción actual

---

**🎉 Este plan proporciona una base sólida para implementar un sistema profesional de anuncios de audio que se integre perfectamente con tu app existente, utilizando las optimizaciones de baja latencia que ya has logrado.**

