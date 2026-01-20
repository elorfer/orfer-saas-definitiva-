# 🔄 Función de Reinicio de Estadísticas del Dashboard

## 📋 Descripción

Esta funcionalidad permite a los administradores reiniciar completamente todas las estadísticas del dashboard del panel de administración. Es útil para limpiar datos de prueba o comenzar de cero con las métricas de la plataforma.

## 🎯 ¿Qué se Reinicia?

Al utilizar esta función, se eliminan o reinician los siguientes datos:

### 1. **Historial de Reproducciones** (`play_history`)
   - Se eliminan TODOS los registros del historial de reproducciones
   - Esto afecta a los gráficos de reproducciones diarias
   - Afecta a los datos de usuarios activos por día

### 2. **Estadísticas de Streaming** (`streaming_stats`)
   - Se eliminan todas las estadísticas de streaming acumuladas
   - Afecta a los reportes históricos de rendimiento

### 3. **Contadores de Canciones**
   - `totalStreams`: Se reinicia a 0
   - `totalLikes`: Se reinicia a 0
   - Afecta al ranking de canciones más populares

### 4. **Contadores de Artistas**
   - `totalStreams`: Se reinicia a 0
   - Afecta al ranking de artistas más populares

## 🚨 Advertencias

⚠️ **ESTA ACCIÓN ES IRREVERSIBLE**

- No hay forma de recuperar los datos una vez eliminados
- Afecta a TODAS las estadísticas de la plataforma
- Se muestra un diálogo de confirmación antes de ejecutar

## 🔧 Implementación Técnica

### Backend

**Archivo**: `apps/backend/src/modules/analytics/analytics.service.ts`

**Método**: `resetStats()`

```typescript
async resetStats(): Promise<{ message: string; details: any }> {
  // 1. Contar registros antes de eliminar
  // 2. Eliminar todo el historial de reproducciones
  // 3. Eliminar estadísticas de streaming
  // 4. Reiniciar contadores en todas las canciones
  // 5. Reiniciar contadores en todos los artistas
}
```

**Endpoint**: `POST /api/v1/analytics/reset-stats`
- **Autenticación**: Requerida (Bearer Token)
- **Rol**: Solo ADMIN
- **Respuesta**:
```json
{
  "message": "Estadísticas reiniciadas exitosamente",
  "details": {
    "playHistoryDeleted": 123,
    "streamingStatsDeleted": 45,
    "songsReset": 30,
    "artistsReset": 15
  }
}
```

### Frontend

**Archivo**: `apps/admin/src/app/dashboard/page.tsx`

**Características**:
- Botón visible en la parte superior del dashboard
- Diálogo de confirmación con advertencia detallada
- Loading state durante el proceso
- Notificaciones toast con el resultado
- Auto-refetch de todos los datos tras completar

**Ubicación del Botón**: 
- Esquina superior derecha del dashboard
- Color rojo para indicar acción destructiva
- Icono de recarga que se anima durante el proceso

## 📝 Uso

1. **Acceder al Dashboard**: 
   - Ir a `/dashboard` en el panel de admin

2. **Ubicar el Botón**: 
   - En la esquina superior derecha verás "Reiniciar Estadísticas"

3. **Hacer Click**: 
   - Se mostrará un diálogo de confirmación detallando qué se eliminará

4. **Confirmar**: 
   - Si estás seguro, confirma la acción

5. **Esperar**: 
   - El proceso puede tardar unos segundos
   - Verás un indicador de carga

6. **Resultado**: 
   - Se mostrará un mensaje con los detalles de lo que se eliminó
   - El dashboard se actualizará automáticamente mostrando las estadísticas en cero

## 🎨 Interfaz de Usuario

### Estado Normal
```
[🔄 Reiniciar Estadísticas]
```

### Estado Cargando
```
[⟲ Reiniciando...]
```

### Diálogo de Confirmación
```
⚠️ ADVERTENCIA: Esta acción eliminará TODAS las estadísticas del dashboard incluyendo:

• Historial de reproducciones
• Contadores de streams de canciones
• Contadores de streams de artistas
• Estadísticas de géneros
• Datos de actividad de usuarios

¿Estás seguro de que deseas continuar?

[Cancelar] [Aceptar]
```

## 🔒 Seguridad

- **Solo Administradores**: El endpoint está protegido por el guard `@Roles(UserRole.ADMIN)`
- **Autenticación JWT**: Requiere token de autenticación válido
- **Confirmación del Usuario**: Requiere confirmación explícita antes de ejecutar
- **Logs**: La operación se registra en los logs del servidor

## 🧪 Casos de Uso

### Desarrollo y Testing
- Limpiar datos de prueba antes de hacer demos
- Resetear el entorno de desarrollo

### Producción
- Corregir datos corruptos o inconsistentes
- Comenzar una nueva temporada/período de medición
- Limpiar el sistema antes de un lanzamiento oficial

## ⚙️ Configuración

No requiere configuración adicional. La funcionalidad está lista para usar una vez que el código esté desplegado.

## 📊 Impacto en Dashboards y Reportes

Después de reiniciar las estadísticas:

- **Dashboard Principal**: Todos los contadores mostrarán 0
- **Gráficos de Reproducciones**: Estarán vacíos
- **Top Canciones**: La lista estará vacía
- **Usuarios Activos**: Los gráficos mostrarán 0
- **Distribución de Géneros**: No habrá datos
- **Horas Pico**: El gráfico estará vacío

## 🔍 Verificación

Después de reiniciar, puedes verificar que todo se reseteo correctamente:

1. Verifica que el contador de "Reproducciones" muestra 0
2. Revisa que la lista de "Top Canciones" está vacía
3. Confirma que los gráficos de actividad no muestran datos
4. Chequea los logs del backend para confirmar la operación

## 📞 Soporte

Si encuentras algún problema con esta funcionalidad:
1. Revisa los logs del backend
2. Verifica que tienes permisos de administrador
3. Confirma que el endpoint está accesible
4. Revisa la consola del navegador para errores

---

**Fecha de Implementación**: Enero 2026
**Versión**: 1.0.0
