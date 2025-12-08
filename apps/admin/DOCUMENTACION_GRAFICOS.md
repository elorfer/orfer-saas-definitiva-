# Recomendaciones de Gráficos para el Dashboard

## Gráficos Recomendados

### 1. **Reproducciones Totales** (Gráfico de Línea)
- **Tipo**: Área/Línea
- **Período**: Últimos 7-30 días
- **Datos**: Reproducciones diarias acumuladas
- **Utilidad**: Ver tendencia de crecimiento y picos de actividad
- **Colores**: Gradiente marrón/naranja acorde al tema

### 2. **Usuarios Activos** (Gráfico de Barras)
- **Tipo**: Barras o Área
- **Período**: Últimos 7-30 días  
- **Datos**: Usuarios únicos que reprodujeron música cada día
- **Utilidad**: Entender el engagement diario de usuarios
- **Colores**: Azul/marrón para diferenciación

### 3. **Top Géneros** (Gráfico de Dona/Pie) - Opcional
- **Tipo**: Dona o Barras horizontales
- **Datos**: Distribución de reproducciones por género
- **Utilidad**: Ver qué géneros son más populares

### 4. **Tendencia de Crecimiento** (Gráfico de Línea Dual) - Opcional
- **Tipo**: Línea con dos ejes Y
- **Datos**: Reproducciones vs Nuevos usuarios
- **Utilidad**: Correlacionar crecimiento de usuarios con reproducciones

## Librería: Recharts ✅

Ya está instalado `recharts` v2.10.4, que es perfecto para estos gráficos:
- ✅ Renderizado SVG nativo (rápido)
- ✅ Responsive por defecto
- ✅ Personalizable con Tailwind CSS
- ✅ Soporte para animaciones
- ✅ Compatible con React

## Implementación

Voy a implementar los 2 gráficos principales primero (Reproducciones y Usuarios Activos) usando datos del PlayHistory.





