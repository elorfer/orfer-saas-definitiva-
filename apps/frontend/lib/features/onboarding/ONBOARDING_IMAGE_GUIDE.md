# 📐 Guía de Tamaños de Imágenes para Onboarding Narrativo

## 🎯 Recomendaciones de Tamaños

### Para Pantallas de Onboarding (Full Screen)

#### **Imágenes de Fondo/Ilustraciones Principales**
- **Ancho:** 1080px - 1440px
- **Alto:** 1920px - 2560px (proporción 9:16 o 2:3)
- **Formato:** PNG (con transparencia si es necesario) o WebP
- **Peso máximo:** 200-500 KB por imagen
- **Resolución:** 72-96 DPI (suficiente para móviles)

#### **Imágenes de Personajes/Elementos Decorativos**
- **Tamaño:** 600px - 800px (ancho o alto, según orientación)
- **Formato:** PNG con transparencia o WebP
- **Peso máximo:** 100-200 KB
- **Resolución:** 72 DPI

#### **Iconos/Elementos Pequeños**
- **Tamaño:** 200px - 400px
- **Formato:** PNG con transparencia o SVG (preferible)
- **Peso máximo:** 50-100 KB

### 📱 Consideraciones por Densidad de Pantalla

#### **Para Pantallas @1x (mdpi)**
- Base: 1080x1920px
- Usar directamente

#### **Para Pantallas @2x (xhdpi)**
- Base: 2160x3840px
- Flutter escalará automáticamente

#### **Para Pantallas @3x (xxhdpi)**
- Base: 3240x5760px
- Flutter escalará automáticamente

### 🚀 Optimización Recomendada

#### **Estrategia Recomendada:**
1. **Crear imágenes en 2x (2160x3840px)** - Flutter las escalará automáticamente
2. **Comprimir con herramientas como:**
   - TinyPNG (https://tinypng.com)
   - Squoosh (https://squoosh.app)
   - ImageOptim
3. **Usar WebP cuando sea posible** - Mejor compresión
4. **Evitar imágenes mayores a 1440x2560px** - No hay beneficio visible

### 📐 Tamaños Específicos por Tipo de Onboarding

#### **Onboarding Horizontal (3-4 pantallas)**
- **Ancho:** 1080px - 1440px
- **Alto:** 1920px - 2400px
- **Proporción:** 9:16 o 2:3

#### **Onboarding Vertical (Scroll)**
- **Ancho:** 1080px - 1440px
- **Alto:** Variable (cada sección 1920px - 2400px)
- **Proporción:** Mantener 9:16 por sección

### 💡 Mejores Prácticas

1. **Usar imágenes vectoriales (SVG) cuando sea posible**
   - Escalables sin pérdida de calidad
   - Tamaño de archivo más pequeño
   - Mejor rendimiento

2. **Para imágenes rasterizadas (PNG/JPG):**
   - Crear en 2x (2160x3840px)
   - Comprimir al 70-80% de calidad
   - Usar WebP si es posible

3. **Optimización de carga:**
   - Precargar imágenes antes de mostrar onboarding
   - Usar `precacheImage()` en Flutter
   - Considerar lazy loading para onboarding largo

4. **Tamaños de archivo objetivo:**
   - Imagen principal: 200-400 KB
   - Elementos decorativos: 50-150 KB
   - Iconos: 10-50 KB

### 🎨 Ejemplo de Estructura de Archivos

```
assets/images/onboarding/
├── screen1/
│   ├── background.png (1440x2560px, ~300KB)
│   ├── character.png (800x1200px, ~150KB)
│   └── icon.png (400x400px, ~50KB)
├── screen2/
│   ├── background.png (1440x2560px, ~300KB)
│   └── illustration.png (1000x1400px, ~200KB)
└── screen3/
    ├── background.png (1440x2560px, ~300KB)
    └── elements/
        ├── element1.png (600x600px, ~80KB)
        └── element2.png (600x600px, ~80KB)
```

### ⚡ Rendimiento en Flutter

- **Usar `Image.asset()` con `cacheWidth` y `cacheHeight`:**
  ```dart
  Image.asset(
    'assets/images/onboarding/background.png',
    cacheWidth: 1080,
    cacheHeight: 1920,
    fit: BoxFit.cover,
  )
  ```

- **Para mejor rendimiento, usar `CachedNetworkImage` si las imágenes están en servidor:**
  ```dart
  CachedNetworkImage(
    imageUrl: imageUrl,
    memCacheWidth: 1080,
    memCacheHeight: 1920,
    fit: BoxFit.cover,
  )
  ```

### 📊 Resumen de Tamaños Recomendados

| Tipo de Imagen | Ancho | Alto | Peso Máximo | Formato |
|---------------|-------|------|-------------|---------|
| Fondo Principal | 1080-1440px | 1920-2560px | 300-500 KB | PNG/WebP |
| Ilustración | 800-1200px | 1200-1800px | 150-300 KB | PNG/WebP |
| Personaje | 600-800px | 800-1200px | 100-200 KB | PNG/WebP |
| Elemento Decorativo | 400-600px | 400-600px | 50-150 KB | PNG/WebP |
| Icono | 200-400px | 200-400px | 10-50 KB | PNG/SVG |

### ✅ Checklist Final

- [ ] Imágenes creadas en resolución 2x (2160x3840px base)
- [ ] Comprimidas con TinyPNG o similar
- [ ] Peso total de todas las imágenes < 2MB
- [ ] Formato WebP cuando sea posible
- [ ] SVG para iconos y elementos simples
- [ ] Probadas en diferentes tamaños de pantalla
- [ ] Optimizadas para carga rápida



