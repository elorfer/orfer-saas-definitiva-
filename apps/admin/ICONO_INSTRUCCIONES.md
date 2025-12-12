# Instrucciones para el Icono

El icono del admin debe colocarse en la siguiente ubicación:

**Ruta:** `apps/admin/public/logo-icon.png`

El icono se mostrará en:
- La parte superior izquierda del sidebar (versión desktop)
- La parte superior izquierda del sidebar móvil
- La página de login

## Formato recomendado
- Formato: PNG (con fondo transparente preferiblemente)
- Tamaño recomendado: 64x64 píxeles o superior (se escalará automáticamente)
- El icono debe tener fondo transparente para que se vea bien sobre cualquier fondo

## Nota
Si el icono tiene un nombre diferente, puedes actualizar las referencias en:
- `apps/admin/src/app/dashboard/layout.tsx`
- `apps/admin/src/components/layout/DashboardLayout.tsx`
- `apps/admin/src/app/login/page.tsx`

Busca las referencias a `/logo-icon.png` y cámbialas por el nombre de tu archivo.













