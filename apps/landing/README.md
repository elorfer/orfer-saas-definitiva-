# 🎵 Struky Music AI - Landing Page

Landing page profesional para producción musical asistida por IA.

## 🚀 Comenzar

### Instalación

```bash
npm install
```

### Desarrollo

```bash
npm run dev
```

Abre [http://localhost:3000](http://localhost:3000) en tu navegador.

### Construcción para Producción

```bash
npm run build
npm run start
```

## ✨ Características

- ✅ **Dark Mode Elegante** - Tema oscuro con acentos neón
- ✅ **100% Responsive** - Optimizado para móviles, tablets y desktop
- ✅ **SEO Optimizado** - Meta tags, structured data, sitemap
- ✅ **Integración Lemon Squeezy** - Sistema de pagos listo
- ✅ **Páginas Legales** - Privacy, Terms, Refund (requeridas por Stripe)
- ✅ **Animaciones Premium** - Micro-interacciones y efectos visuales
- ✅ **TypeScript** - Código tipado y seguro
- ✅ **Tailwind CSS** - Estilos modernos y mantenibles

## 📋 Secciones

1. **Hero Section** - Propuesta de valor principal con CTA
2. **Cómo Funciona** - Proceso en 4 pasos
3. **Formulario de Pedido** - Captura de datos y selección de género
4. **Footer Legal** - Links a políticas y contacto

## 🔧 Configuración de Lemon Squeezy

Para integrar Lemon Squeezy:

1. Crea una cuenta en [Lemon Squeezy](https://lemonsqueezy.com)
2. Crea un producto y obtén el checkout URL
3. En `app/page.tsx`, reemplaza el placeholder en `handleSubmit`:

```typescript
// Reemplaza esto:
alert('¡Genial! En la versión final, esto abrirá el checkout de Lemon Squeezy.');

// Por esto:
window.LemonSqueezy.Url.Open('TU_CHECKOUT_URL_AQUI');
```

## 📝 Personalización

### Cambiar Colores

Edita `tailwind.config.ts`:

```typescript
colors: {
  'neon-purple': '#a855f7',  // Cambia aquí
  'neon-blue': '#3b82f6',    // Cambia aquí
  // ...
}
```

### Cambiar Textos

Edita `app/page.tsx` para modificar títulos, subtítulos y contenido.

### Cambiar Contacto

Actualiza los enlaces de email y WhatsApp en:
- `app/page.tsx` (footer)
- `app/privacy/page.tsx`
- `app/terms/page.tsx`
- `app/refund/page.tsx`

## 🌐 Deployment

### Vercel (Recomendado)

1. Haz push de tu código a GitHub
2. Conecta tu repo en [Vercel](https://vercel.com)
3. Deploy automático ✨

### Otros Proveedores

Compatible con cualquier plataforma que soporte Next.js:
- Netlify
- AWS Amplify
- Railway
- Render

## 📞 Soporte

Para preguntas o soporte, contacta:
- 📧 Email: info@strukymusicai.com
- 💬 WhatsApp: [Tu número]

## 📄 Licencia

ISC License - Struky Music AI

---

Hecho con ❤️ y IA
