# 🎯 GUÍA RÁPIDA - NGROK SETUP

## ✅ CHECKLIST

### 1. DESCARGAR NGROK
- [ ] Ve a: https://ngrok.com/download
- [ ] Descarga para Windows
- [ ] Mueve `ngrok.exe` a `C:\ngrok\`

### 2. CREAR CUENTA
- [ ] Ve a: https://dashboard.ngrok.com/signup
- [ ] Crea cuenta (con Google es más rápido)
- [ ] Copia tu **Authtoken** (lo necesitarás en el paso 3)

### 3. CONFIGURAR AUTHTOKEN
```powershell
C:\ngrok\ngrok.exe config add-authtoken TU_TOKEN_AQUI
```

### 4. INICIAR TUNNEL
```powershell
cd c:\appdefinitiva
.\start-ngrok.ps1
```

O directamente:
```powershell
C:\ngrok\ngrok.exe http 3000
```

### 5. COPIAR URL
Verás algo como:
```
Forwarding    https://abc123.ngrok.io -> http://localhost:3000
```

**COPIA:** `https://abc123.ngrok.io`

### 6. CONFIGURAR WEBHOOK
1. Ve a: https://app.revenuecat.com
2. Project Settings → Integrations → Webhooks
3. + Add Webhook
4. URL: `https://abc123.ngrok.io/api/webhooks/revenuecat`
5. Events: Selecciona TODOS
6. Save
7. **COPIA EL WEBHOOK SECRET** que te da

### 7. AGREGAR SECRET AL .ENV
```bash
# En: c:\appdefinitiva\apps\backend\.env
REVENUECAT_WEBHOOK_SECRET=sk_abc123...
```

### 8. REINICIAR BACKEND
```powershell
# Ctrl+C en la terminal del backend
npm run dev:backend-admin
```

### 9. PROBAR
1. En RevenueCat Dashboard → Webhooks
2. Click en tu webhook → Send Test
3. Verifica logs del backend

### 10. COMPRA REAL
1. Abre la app
2. Compra suscripción (sandbox)
3. Debería activar premium instantáneamente

---

## 🎊 ¡LISTO!

Ahora tienes un sistema de webhooks nivel FAANG ⭐⭐⭐⭐⭐

---

## 💡 TIPS

- **ngrok debe estar corriendo** mientras desarrollas
- **La URL cambia** cada vez que reinicias ngrok (gratis)
- **Para URL fija:** ngrok paid ($8/mes)
- **En producción:** Railway ya tiene URL pública (no necesitas ngrok)

---

## 🆘 TROUBLESHOOTING

**Error: "command not found"**
→ Verifica que ngrok.exe está en C:\ngrok\

**Error: "authtoken required"**
→ Ejecuta paso 3 (configurar authtoken)

**Webhook no llega:**
→ Verifica que la URL en RevenueCat sea correcta
→ Verifica que ngrok esté corriendo
→ Verifica logs del backend

---

**¿Dudas?** Consulta: `CONFIGURACION_PERFECTA_WEBHOOK.md`
