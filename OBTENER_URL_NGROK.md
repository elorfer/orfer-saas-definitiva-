# 🌐 OBTENER URL DE NGROK

## 📍 MÉTODO 1: Web Interface (RECOMENDADO)

1. **Abre tu navegador**
2. **Ve a:** http://127.0.0.1:4040
3. **Copia la URL** que aparece en "Forwarding"
   - Ejemplo: `https://abc123-45-67-89-10.ngrok-free.app`

---

## 📍 MÉTODO 2: Terminal

En la terminal donde corriste ngrok, busca la línea:
```
Forwarding    https://XXXX.ngrok-free.app -> http://localhost:3001
```

**COPIA:** `https://XXXX.ngrok-free.app`

---

## 🎯 SIGUIENTE PASO

Una vez que tengas la URL, agrégala a RevenueCat:

1. **Ve a:** https://app.revenuecat.com
2. **Project Settings** → **Integrations** → **Webhooks**
3. **+ Add Webhook**
4. **URL:** `TU_URL_NGROK/api/webhooks/revenuecat`
   - Ejemplo: `https://abc123.ngrok-free.app/api/webhooks/revenuecat`
5. **Events:** Selecciona TODOS
6. **Save**
7. **COPIA el Webhook Secret** que te da

---

## 📝 TU URL SERÁ ALGO ASÍ:

```
https://1234-56-78-90-12.ngrok-free.app

O

https://abcd1234.ngrok-free.app
```

**¿Ya la tienes?** Dímela y continuamos con RevenueCat.
