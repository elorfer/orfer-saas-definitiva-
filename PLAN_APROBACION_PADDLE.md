# 📋 PLAN DE ACCIÓN PARA APROBACIÓN DE PADDLE - STRUKY.COM

## 🎯 Objetivo
Cumplir con todos los requisitos de Paddle para aprobar el dominio struky.com y poder recibir pagos.

---

## ❌ PROBLEMAS IDENTIFICADOS POR PADDLE

### 1. **Inconsistencia en el nombre comercial**
   - **Problema:** Los Términos y Condiciones dicen "Struky Music AI" pero enviaste "Struky"
   - **Ubicación:** Archivo `apps/landing/app/terms/page.tsx`
   - **Líneas afectadas:** 19, 27, 54, 98, 125 (y otras menciones)

### 2. **Política de reembolsos incompatible**
   - **Problema:** Política de "NO REEMBOLSOS" con excepciones no compatibles con Paddle
   - **Ubicación:** Archivo `apps/landing/app/refund/page.tsx`
   - **Lo que Paddle NO acepta:** Políticas rígidas de "no reembolso" o excepciones muy limitadas

### 3. **Período de reembolso no especificado**
   - **Problema:** No se indica el número exacto de días (14 días, 30 días, etc.)
   - **Ubicación:** Archivo `apps/landing/app/refund/page.tsx`
   - **Requerimiento de Paddle:** Debe especificar claramente cuántos días tiene el cliente

### 4. **Servicios impulsados por humanos no confirmado**
   - **Problema:** No queda claro en el sitio si hay supervisión humana real
   - **Ubicación:** Todo el sitio, especialmente `page.tsx`
   - **Necesario:** Dejar MUY claro que hay productores humanos supervisando

---

## ✅ SOLUCIONES A IMPLEMENTAR

### 📝 CAMBIO 1: Unificar el nombre comercial a "Struky"

**Acción:** Cambiar todas las menciones de "Struky Music AI" a "Struky" en los Términos y Condiciones.

**Archivos a modificar:**
- `apps/landing/app/terms/page.tsx`

**Cambios específicos:**
- Línea 19: "...servicios de **Struky**..." (en lugar de "Struky Music AI")
- Línea 27: "**Struky** ofrece..."
- Línea 54: "**Struky** se reserva..."
- Línea 98: "**Struky** no será responsable..."
- Línea 115: "...donde opera **Struky**..."

**ALTERNATIVA:** Si prefieres mantener "Struky Music AI", actualiza tu registro con Paddle para que coincida.

---

### 📝 CAMBIO 2: Reescribir la política de reembolsos compatible con Paddle

**Guía de Paddle:** https://www.paddle.com/help/sell/merchant-account-and-legal/domain-review

**Política recomendada por Paddle:**
```
✅ Período de reembolso: 14 días o 30 días desde la compra
✅ Proceso simple y transparente
✅ Sin condiciones restrictivas excesivas
✅ Claridad en cómo solicitar el reembolso
```

**Nueva Política de Reembolso a implementar:**

```markdown
## Política de Reembolso de 14 Días

En Struky, ofrecemos un período de reembolso de **14 días naturales** desde la fecha de compra.

### ¿Cuándo puedo solicitar un reembolso?

Puedes solicitar un reembolso completo dentro de los 14 días posteriores a tu compra si:
- No estás satisfecho con la calidad de la producción musical entregada
- La canción no cumple con las especificaciones acordadas
- Experimentamos retrasos significativos (más de 72 horas del plazo acordado)
- Cancelas antes de que comencemos la producción

### ¿Cómo solicito un reembolso?

1. Envía un correo a: refunds@struky.com (o strukyapp@gmail.com)
2. Indica tu nombre, número de pedido y motivo
3. Procesaremos tu solicitud en un plazo de 3-5 días hábiles
4. El reembolso se realizará al método de pago original

### Casos en los que NO aplica el reembolso

- Después de transcurridos los 14 días desde la compra
- Si ya has distribuido comercialmente la canción en plataformas
- Si solicitaste y recibiste más de una revisión (según nuestros términos)

### Garantías adicionales

Aunque ofrezcamos reembolsos, nos comprometemos a:
- ✓ Calidad profesional supervisada por productores humanos
- ✓ Entrega en 24-48 horas
- ✓ Una revisión incluida para ajustes razonables
- ✓ Soporte directo vía email y WhatsApp
```

**Archivo a modificar:**
- `apps/landing/app/refund/page.tsx`

---

### 📝 CAMBIO 3: Clarificar servicios con supervisión humana

**Problema:** Paddle necesita saber si hay humanos involucrados en el servicio.

**Solución:** Dejar MUY claro en TODO el sitio que:
- ✅ La IA genera el contenido base
- ✅ Productores musicales HUMANOS supervisan y refinan TODO
- ✅ Hay control de calidad humano antes de la entrega

**Archivos a modificar:**
- `apps/landing/app/page.tsx` (landing principal)
- `apps/landing/app/terms/page.tsx` (términos)

**Mensajes clave a reforzar:**
1. "Producción con IA **supervisada por productores profesionales humanos**"
2. "Cada canción es **revisada y refinada por expertos musicales**"
3. "Control de calidad **100% humano** antes de la entrega"

---

### 📝 CAMBIO 4: Actualizar sección de contacto

**Problema:** Los emails de contacto deben ser profesionales y del dominio verificado.

**Emails actuales (inconsistentes):**
- strukyapp@gmail.com
- legal@strukymusicai.com (no existe)
- refunds@strukymusicai.com (no existe)

**Solución recomendada:**
1. **Opción A (ideal):** Configurar emails profesionales:
   - legal@struky.com
   - refunds@struky.com
   - support@struky.com

2. **Opción B (temporal):** Mantener strukyapp@gmail.com PERO ser consistente en TODO el sitio.

**Recomendación:** Usar Opción A con Google Workspace o servicio similar (costo: ~$6/mes).

---

## 🚀 IMPLEMENTACIÓN PASO A PASO

### **PASO 1: Decidir el nombre comercial oficial**
- [ ] **Decidir:** ¿"Struky" o "Struky Music AI"?
- [ ] Actualizar TODOS los archivos con el nombre elegido
- [ ] Asegurarse de que coincida con el registro de Paddle

**Recomendación:** Usar "Struky" (más corto, más profesional, más limpio)

---

### **PASO 2: Configurar emails profesionales** 
- [ ] Contratar Google Workspace o servicio similar para el dominio struky.com
- [ ] Crear emails:
  - support@struky.com
  - legal@struky.com
  - refunds@struky.com
- [ ] Actualizar TODOS los archivos del landing con los nuevos emails

**Alternativa temporal:** Usar solo strukyapp@gmail.com de forma consistente

---

### **PASO 3: Reescribir la política de reembolsos**
- [ ] Implementar política de 14 días según el estándar de Paddle
- [ ] Especificar claramente el período (14 días)
- [ ] Incluir proceso simple de solicitud
- [ ] Eliminar lenguaje excesivamente restrictivo
- [ ] Incluir condiciones razonables

---

### **PASO 4: Clarificar supervisión humana**
- [ ] Actualizar página principal (page.tsx)
- [ ] Actualizar Términos de Servicio
- [ ] Agregar sección "Nuestro Equipo" o "Cómo Trabajamos"
- [ ] Dejar MUY claro que hay productores humanos supervisando

**Mensajes clave:**
```
✅ "IA avanzada + criterio artístico profesional"
✅ "Supervisión de productores musicales expertos"
✅ "Control de calidad 100% humano"
✅ "Cada canción es revisada por un productor profesional"
```

---

### **PASO 5: Actualizar Términos de Servicio**
- [ ] Cambiar nombre a "Struky" (si es el elegido)
- [ ] Clarificar que hay supervisión humana en la producción
- [ ] Asegurar consistencia con la política de reembolsos
- [ ] Incluir información de contacto correcta

---

### **PASO 6: Revisar y desplegar**
- [ ] Hacer un git commit con todos los cambios
- [ ] Desplegar a Vercel
- [ ] Verificar que struky.com muestre todos los cambios
- [ ] Hacer screenshot de las páginas actualizadas para enviar a Paddle

---

### **PASO 7: Responder a Paddle**
- [ ] Redactar email de respuesta profesional
- [ ] Confirmar cada uno de los 4 puntos que solicitaron
- [ ] Incluir enlaces directos a las páginas actualizadas
- [ ] Especificar claramente: "Sí, nuestro servicio incluye supervisión humana por productores musicales profesionales"

---

## 📧 PLANTILLA DE RESPUESTA PARA PADDLE

```
Asunto: Re: Verificación de Dominio - struky.com - Cambios Completados

Estimado equipo de Paddle,

Gracias por revisar nuestro dominio struky.com. Hemos completado todos los cambios solicitados:

1. ✅ **Nombre comercial unificado:**
   - Hemos actualizado todos nuestros Términos y Condiciones para usar consistentemente "Struky"
   - Enlace: https://struky.com/terms

2. ✅ **Política de reembolsos actualizada:**
   - Hemos implementado una política de reembolso de 14 días clara y compatible con Paddle
   - Enlace: https://struky.com/refund
   - Período especificado: 14 días naturales desde la fecha de compra
   - Proceso simple y transparente incluido

3. ✅ **Supervisión humana confirmada:**
   - SÍ, nuestro servicio incluye supervisión humana por productores musicales profesionales
   - Cada canción es revisada, refinada y supervisada por productores expertos
   - La IA genera el contenido base, pero profesionales humanos supervisan y garantizan la calidad
   - Hemos clarificado esto en nuestra página principal: https://struky.com

4. ✅ **Información de contacto actualizada:**
   - Email de soporte: support@struky.com
   - Email legal: legal@struky.com
   - Email de reembolsos: refunds@struky.com

Quedamos a su disposición para cualquier ajuste adicional necesario.

Atentamente,
[Tu nombre]
Fundador - Struky
strukyapp@gmail.com
```

---

## 🎯 RESUMEN DE ARCHIVOS A MODIFICAR

| Archivo | Cambios Necesarios |
|---------|-------------------|
| `apps/landing/app/page.tsx` | Reforzar mensaje de supervisión humana |
| `apps/landing/app/terms/page.tsx` | Unificar nombre a "Struky", actualizar emails |
| `apps/landing/app/refund/page.tsx` | **REESCRIBIR COMPLETAMENTE** con política de 14 días |
| `apps/landing/app/layout.tsx` | Verificar metadatos (nombre, descripción) |

---

## ⏱️ TIEMPO ESTIMADO

- Configurar emails profesionales: **30-60 minutos**
- Modificar archivos del landing: **1-2 horas**
- Desplegar y verificar: **30 minutos**
- Responder a Paddle: **15 minutos**

**TOTAL: 2-4 horas de trabajo**

---

## 🔥 PRIORIDAD ALTA

Este proceso debe completarse **lo antes posible** para no retrasar la monetización de tu aplicación.

### Orden de ejecución recomendado:

1. **PRIMERO:** Decidir nombre oficial (Struky vs Struky Music AI)
2. **SEGUNDO:** Configurar emails profesionales (o decidir usar strukyapp@gmail.com temporalmente)
3. **TERCERO:** Modificar archivos del landing
4. **CUARTO:** Desplegar a Vercel
5. **QUINTO:** Responder a Paddle

---

## 📞 PRÓXIMOS PASOS

¿Quieres que proceda con la implementación? Necesito que me confirmes:

1. **¿Qué nombre prefieres usar oficialmente?**
   - [ ] "Struky" (recomendado)
   - [ ] "Struky Music AI"

2. **¿Quieres configurar emails profesionales ahora?**
   - [ ] Sí, configurar con Google Workspace (@struky.com)
   - [ ] No, usar strukyapp@gmail.com temporalmente

3. **¿Procedo a modificar los archivos del landing?**
   - [ ] Sí, hazlo ahora
   - [ ] Déjame revisar el plan primero

Una vez tengas estas decisiones, implementaré todo el plan en minutos. 🚀
