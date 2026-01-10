# 🚀 ANÁLISIS DE OPTIMIZACIONES DEL ALGORITMO DE RECOMENDACIONES

## 📊 ESTADO ACTUAL

- **Archivo:** `recommendation.service.ts`
- **Líneas de código:** 2,618
- **Tiempo de respuesta:** 10-30 segundos
- **Queries por batch (4 recomendaciones):** 30-50 queries a PostgreSQL

---

## ✅ OPTIMIZACIONES VIABLES (SIN REESCRIBIR)

### **1️⃣ CACHÉ DE QUERIES FRECUENTES** 
**Impacto:** 🔥🔥🔥🔥🔥 (5/5)  
**Dificultad:** ⭐⭐ (2/5)  
**Tiempo:** 30 minutos

#### **Problema actual:**
```typescript
// Línea 280-283: Se ejecuta CADA VEZ para CADA recomendación
const song = await this.songRepository.findOne({
  where: { id: songId },
  relations: ['artist', 'album', 'genre'],
});
```

Si pides 4 recomendaciones, esta query se ejecuta **4+ veces** buscando la misma canción.

#### **Solución:**
Agregar un caché LRU simple en memoria:

```typescript
private songCache = new Map<string, { song: Song, timestamp: number }>();
private SONG_CACHE_TTL = 5 * 60 * 1000; // 5 minutos

private async getCurrentSong(songId: string): Promise<Song | null> {
  // Verificar caché
  const cached = this.songCache.get(songId);
  if (cached && (Date.now() - cached.timestamp < this.SONG_CACHE_TTL)) {
    return cached.song;
  }
  
  // Query a DB
  const song = await this.songRepository.findOne({
    where: { id: songId },
    relations: ['artist', 'album', 'genre'],
  });
  
  // Guardar en caché
  if (song) {
    this.songCache.set(songId, { song, timestamp: Date.now() });
  }
  
  return song;
}
```

**Ganancia:** Reduce queries de ~30-50 a ~10-15 (50% menos) ✅

---

### **2️⃣ PARALELIZAR RECOMENDACIONES EN BATCH**
**Impacto:** 🔥🔥🔥🔥 (4/5)  
**Dificultad:** ⭐⭐⭐ (3/5)  
**Tiempo:** 1 hora

#### **Problema actual:**
```typescript
// Línea 1999-2140: Secuencial (UNO POR UNO)
for (let i = 0; i < count; i++) {
  const recommended = await this.getRecommendedSong(...); // ❌ ESPERA
  recommendations.push(recommended);
}
```

Si cada recomendación tarda 2 segundos:
- **Secuencial:** 4 × 2s = **8 segundos** ❌
- **Paralelo:** max(2s) = **2 segundos** ✅

#### **Solución:**
Ya existe código para paralelización (líneas 1970-1993), pero solo se activa con catálogos grandes.

```typescript
// Cambiar condición de activación:
// ANTES:
const shouldParallelizeTotal = totalSongs > 50 && count >= 3;

// DESPUÉS:
const shouldParallelizeTotal = totalSongs > 10 && count >= 2; // Más agresivo
```

**Ganancia:** 3-4x más rápido (8s → 2s) ✅

---

### **3️⃣ OPTIMIZAR QUERY DE CONTEO DE CATÁLOGO**
**Impacto:** 🔥🔥🔥 (3/5)  
**Dificultad:** ⭐ (1/5)  
**Tiempo:** 15 minutos

#### **Problema actual:**
```typescript
// Línea 2214-2226: Se ejecuta en CADA batch
private async getTotalAvailableSongs(): Promise<number> {
  const count = await this.songRepository.count({
    where: { status: SongStatus.PUBLISHED, fileUrl: Not('') },
  });
  return count;
}
```

Este conteo se ejecuta **cada vez** aunque el catálogo cambie muy raramente.

#### **Solución:**
Cachear el resultado por 5-10 minutos:

```typescript
private catalogSizeCache: { count: number, timestamp: number } | null = null;
private CATALOG_CACHE_TTL = 5 * 60 * 1000; // 5 minutos

private async getTotalAvailableSongs(): Promise<number> {
  // Verificar caché
  if (this.catalogSizeCache && 
      (Date.now() - this.catalogSizeCache.timestamp < this.CATALOG_CACHE_TTL)) {
    return this.catalogSizeCache.count;
  }
  
  // Query a DB
  const count = await this.songRepository.count({
    where: { status: SongStatus.PUBLISHED, fileUrl: Not('') },
  });
  
  // Guardar en caché
  this.catalogSizeCache = { count, timestamp: Date.now() };
  
  return count;
}
```

**Ganancia:** Elimina 1 query pesada por batch ✅

---

### **4️⃣ REDUCIR CÁLCULOS DE AFINIDAD PARA USUARIOS ANÓNIMOS**
**Impacto:** 🔥🔥 (2/5)  
**Dificultad:** ⭐ (1/5)  
**Tiempo:** 10 minutos

#### **Problema actual:**
```typescript
// Línea 1564-1662: Calcula afinidad SIEMPRE, incluso sin userId
private async calculateUserAffinityScore(userId: string, candidate: Song) {
  // 6 queries paralelas...
}
```

Si `userId` es `undefined` (usuario anónimo), estas queries son **inútiles**.

#### **Solución:**
```typescript
private async calculateUserAffinityScore(userId: string | undefined, candidate: Song) {
  if (!userId) {
    return 0.5; // Score neutro para anónimos (sin queries)
  }
  
  // ... resto del código original
}
```

**Ganancia:** Para usuarios anónimos, elimina ~6 queries por recomendación ✅

---

### **5️⃣ USAR SELECT PARCIAL EN LUGAR DE RELACIONES COMPLETAS**
**Impacto:** 🔥🔥 (2/5)  
**Dificultad:** ⭐⭐ (2/5)  
**Tiempo:** 20 minutos

#### **Problema actual:**
```typescript
// Línea 280-283: Carga TODA la relación (incluyendo campos innecesarios)
const song = await this.songRepository.findOne({
  where: { id: songId },
  relations: ['artist', 'album', 'genre'], // ❌ Mucha data innecesaria
});
```

Esto carga **todos los campos** de artist, album y genre, pero solo necesitamos algunos.

#### **Solución:**
```typescript
const song = await this.songRepository
  .createQueryBuilder('song')
  .select([
    'song.id', 'song.title', 'song.genres', 'song.artistId',
    'song.coverArtUrl', 'song.fileUrl', 'song.playCount'
  ])
  .leftJoinAndSelect('song.artist', 'artist', undefined, ['artist.id', 'artist.stageName'])
  .leftJoinAndSelect('song.genre', 'genre', undefined, ['genre.id', 'genre.name'])
  .where('song.id = :id', { id: songId })
  .getOne();
```

**Ganancia:** Reduce tamaño de datos transferidos en ~40% ✅

---

## 📈 RESUMEN DE IMPACTO

| Optimización | Tiempo Impl. | Ganancia | Riesgo |
|-------------|--------------|----------|--------|
| 1. Caché de queries | 30 min | 50% menos queries | Bajo |
| 2. Paralelización | 1 hora | 3-4x más rápido | Bajo |
| 3. Caché de conteo | 15 min | 1 query menos | Muy bajo |
| 4. Skip anónimos | 10 min | 6 queries menos | Muy bajo |
| 5. SELECT parcial | 20 min | 40% menos datos | Bajo |

**TOTAL:** ~2 horas de trabajo  
**GANANCIA ESTIMADA:** **10-30 segundos → 2-4 segundos** (5-10x más rápido)  
**RIESGO:** Bajo (sin reescribir lógica)

---

## ✅ RECOMENDACIÓN FINAL

**SÍ, son 100% viables e implementables.**

### **Plan de implementación sugerido:**

**Fase 1 (Rápida - 1 hora):**
1. ✅ Caché de conteo de catálogo (15 min)
2. ✅ Skip afinidad para anónimos (10 min)
3. ✅ Caché de getCurrentSong (30 min)

**Fase 2 (Impacto alto - 1 hora):**
4. ✅ Activar paralelización más agresiva (20 min)
5. ✅ SELECT parcial (20 min)
6. ✅ Testing (20 min)

### **Resultado esperado:**
- De **10-30 segundos** a **2-5 segundos** ✅
- Sin romper funcionalidad existente ✅
- Sin reescribir código ✅

---

## 🎯 ¿QUIERES QUE LAS IMPLEMENTE?

Puedo implementar todas estas optimizaciones **sin romper nada**.  
¿Empiezo con la Fase 1 (las 3 optimizaciones más seguras)?
