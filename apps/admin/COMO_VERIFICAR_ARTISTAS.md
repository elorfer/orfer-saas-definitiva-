# ✅ Cómo Verificar Artistas en el Admin Panel

## 📍 Ubicación de la Verificación

La verificación de artistas se realiza desde la **página de edición** de cada artista.

---

## 🚀 Pasos para Verificar un Artista

### 1️⃣ **Acceder a la Lista de Artistas**

1. Inicia sesión en el admin panel
2. Ve al menú lateral y haz clic en **"Administrar artistas"**
3. O navega directamente a: `/dashboard/artists`

**Ruta:** Dashboard → Administrar artistas

---

### 2️⃣ **Abrir la Página de Edición**

En la lista de artistas, encontrarás cada artista con sus acciones:

- Haz clic en el botón **"Editar"** del artista que quieres verificar
- O navega directamente a: `/dashboard/artists/[ID_DEL_ARTISTA]/edit`

**Ejemplo:** Si el ID del artista es `abc123`, la URL sería:
```
/dashboard/artists/abc123/edit
```

---

### 3️⃣ **Verificar el Artista**

En la página de edición, verás una sección especial con fondo gris claro:

```
┌─────────────────────────────────────────┐
│ Estado de Verificación                  │
│                                         │
│ [✅ Verificado]  o  [No verificado]     │
│                                         │
│ [Botón: Verificar Artista] o            │
│ [Botón: Quitar verificación]            │
└─────────────────────────────────────────┘
```

**Si el artista NO está verificado:**
- Verás: "No verificado" en texto gris
- Botón azul: **"Verificar Artista"**
- Haz clic en el botón → El artista quedará verificado ✅

**Si el artista YA está verificado:**
- Verás: "Verificado" con un ícono de check azul ✅
- Botón rojo: **"Quitar verificación"**
- Haz clic para remover la verificación

---

## 🎯 Ubicación Visual en la Página

La sección de verificación está ubicada **después del campo "Destacado"** y **antes del campo "Biografía"**.

**Orden de campos en la página:**
1. Nombre
2. Nacionalidad y Destacado
3. **👉 ESTADO DE VERIFICACIÓN** ← **AQUÍ**
4. Biografía
5. Foto de perfil y Portada
6. Guardar cambios

---

## ⚙️ Funcionalidad

- ✅ **Solo administradores** pueden verificar/desverificar
- ✅ **Feedback inmediato** con notificaciones toast
- ✅ **Estado visible** antes y después de la acción
- ✅ **Actualización automática** - no necesitas refrescar

---

## 📸 Vista Previa

Cuando un artista está **verificado**:
- ✅ Aparece un badge azul con check en la app Flutter
- ✅ Se muestra en todos los lugares donde aparece el nombre del artista
- ✅ El badge es tipo Spotify (azul con check blanco)

---

## 🔍 Verificar desde la Lista

**Próxima mejora sugerida:** Agregar columna "Verificado" en la lista principal para ver el estado sin entrar a editar.

Por ahora, necesitas entrar a editar cada artista para verificar/desverificar.

---

## ❓ Preguntas Frecuentes

**P: ¿Puedo verificar múltiples artistas a la vez?**
R: Por ahora, solo uno por uno desde la página de edición.

**P: ¿Qué pasa si verifico un artista por error?**
R: Solo haz clic en "Quitar verificación" y se removerá.

**P: ¿Los cambios son inmediatos?**
R: Sí, se guardan automáticamente y se reflejan inmediatamente en la app.

---

## ✅ Resumen Rápido

1. **Ir a:** Dashboard → Administrar artistas
2. **Clic en:** "Editar" del artista
3. **Buscar:** Sección "Estado de Verificación"
4. **Clic en:** "Verificar Artista" (botón azul)

¡Listo! El artista quedará verificado y aparecerá el badge azul en la app Flutter 🎉

















