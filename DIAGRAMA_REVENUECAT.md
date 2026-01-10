# 📊 DIAGRAMA: Flujo Completo de RevenueCat en Struky

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        INTEGRACIÓN REVENUECAT - STRUKY                       │
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │ Google Cloud │    │  RevenueCat  │    │ Google Play  │                  │
│  │   Console    │───▶│   Dashboard  │◀───│   Console    │                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│         │                    │                    │                          │
│         │ 1. Service         │ 2. API Keys        │ 3. Products             │
│         │    Account         │    & Webhooks      │    & Testers            │
│         ▼                    ▼                    ▼                          │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                            ARQUITECTURA DE CÓDIGO                            │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                          FLUTTER APP                                  │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  RevenueCatService (Singleton)                                 │  │   │
│  │  │  ────────────────────────────────────────────────────────────  │  │   │
│  │  │  • initialize(userId, email)                                   │  │   │
│  │  │  • isPremium: bool                                             │  │   │
│  │  │  • checkPremiumStatus(): Future<bool>                          │  │   │
│  │  │  • purchasePackage(package): Future<bool>                      │  │   │
│  │  │  • restorePurchases(): Future<bool>                            │  │   │
│  │  │  • premiumStatusStream: Stream<bool>                           │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │           │                          ▲                                │   │
│  │           │ Llamadas                 │ Respuestas                     │   │
│  │           ▼                          │                                │   │
│  │  ┌─────────────────────────┐   ┌─────────────────────────┐           │   │
│  │  │  purchases_flutter SDK  │───│  RevenueCat Cloud API   │           │   │
│  │  └─────────────────────────┘   └─────────────────────────┘           │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                     │                                        │
│                                     │ Webhooks (eventos)                     │
│                                     ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                          NESTJS BACKEND                               │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  RevenueCatWebhookController                                   │  │   │
│  │  │  ────────────────────────────────────────────────────────────  │  │   │
│  │  │  POST /api/webhooks/revenuecat                                 │  │   │
│  │  │  • Valida firma HMAC                                           │  │   │
│  │  │  • Procesa evento                                              │  │   │
│  │  │  • Delega a RevenueCatService                                  │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │           │                                                            │   │
│  │           ▼                                                            │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  RevenueCatService                                             │  │   │
│  │  │  ────────────────────────────────────────────────────────────  │  │   │
│  │  │  • processWebhookEvent()                                       │  │   │
│  │  │  • activatePremium()                                           │  │   │
│  │  │  • deactivatePremium()                                         │  │   │
│  │  │  • handleCancellation()                                        │  │   │
│  │  │  • syncUserPremiumStatus()                                     │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  │           │                                                            │   │
│  │           ▼                                                            │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │  PostgreSQL Database                                           │  │   │
│  │  │  ────────────────────────────────────────────────────────────  │  │   │
│  │  │  users {                                                       │  │   │
│  │  │    id: uuid                                                    │  │   │
│  │  │    email: string                                               │  │   │
│  │  │    revenuecat_user_id: string                                 │  │   │
│  │  │    revenuecat_customer_id: string                             │  │   │
│  │  │    is_premium: boolean                                        │  │   │
│  │  │    premium_expires_at: timestamp                              │  │   │
│  │  │    last_revenuecat_sync: timestamp                            │  │   │
│  │  │  }                                                             │  │   │
│  │  └────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                       FLUJO DE COMPRA (Caso Feliz)                           │
│                                                                              │
│  1. Usuario                  2. Flutter              3. RevenueCat          │
│  │                            │                       │                      │
│  │─────"Suscribirme"────────▶│                       │                      │
│  │                            │──getPackages()──────▶│                      │
│  │                            │◀─[packages]──────────│                      │
│  │                            │                       │                      │
│  │◀──Lista de planes─────────│                       │                      │
│  │                            │                       │                      │
│  │───Selecciona "Premium"───▶│                       │                      │
│  │                            │──purchasePackage()──▶│                      │
│  │                            │                       │                      │
│  │                            │                       │──Google Play───▶┐   │
│  │◀────Diálogo de pago──────────────────────────────────────────────────│   │
│  │                            │                       │                  │   │
│  │───Confirma (biometría)───────────────────────────────────────────────│   │
│  │                            │                       │                  │   │
│  │                            │                       │◀─Pago exitoso────┘   │
│  │                            │◀─CustomerInfo────────│                      │
│  │                            │  (isPremium=true)     │                      │
│  │                            │                       │                      │
│  │◀──"¡Bienvenido Premium!"──│                       │                      │
│  │   (UI actualizada)         │                       │                      │
│  │                            │                       │                      │
│  │                            │                       │──Webhook────────▶┐   │
│  │                            │                       │  INITIAL_PURCHASE│   │
│  │                            │                       │                  │   │
│  │                            │                       │                  ▼   │
│  │                            │                       │            NestJS    │
│  │                            │                       │            Backend   │
│  │                            │                       │                  │   │
│  │                            │                       │                  │   │
│  │                            │                       │       UPDATE users   │
│  │                            │                       │       is_premium=T   │
│  │                            │                       │                  │   │
│  │                            │                       │◀─200 OK──────────┘   │
│                                                                              │
│  ✅ RESULTADO: Usuario premium en App Y en Base de Datos                    │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                            EVENTOS DE WEBHOOK                                │
│                                                                              │
│  ┌──────────────────────┬──────────────────────────────────────────────┐   │
│  │ Evento               │ Acción en Backend                            │   │
│  ├──────────────────────┼──────────────────────────────────────────────┤   │
│  │ INITIAL_PURCHASE     │ is_premium = true                            │   │
│  │                      │ premium_expires_at = [fecha]                 │   │
│  ├──────────────────────┼──────────────────────────────────────────────┤   │
│  │ RENEWAL              │ is_premium = true                            │   │
│  │                      │ premium_expires_at = [nueva fecha]           │   │
│  ├──────────────────────┼──────────────────────────────────────────────┤   │
│  │ CANCELLATION         │ Mantener is_premium = true hasta expiración  │   │
│  │                      │ (usuario ya pagó este periodo)               │   │
│  ├──────────────────────┼──────────────────────────────────────────────┤   │
│  │ EXPIRATION           │ is_premium = false                           │   │
│  │                      │ Suscripción finalizada                       │   │
│  ├──────────────────────┼──────────────────────────────────────────────┤   │
│  │ BILLING_ISSUE        │ Log warning, mantener premium temporalmente  │   │
│  │                      │ (dar tiempo al usuario para resolver)        │   │
│  ├──────────────────────┼──────────────────────────────────────────────┤   │
│  │ PRODUCT_CHANGE       │ Actualizar premium_expires_at                │   │
│  │                      │ is_premium = true                            │   │
│  └──────────────────────┴──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                         ARCHIVOS CREADOS/MODIFICADOS                         │
│                                                                              │
│  BACKEND (NestJS)                                                            │
│  ─────────────────                                                           │
│  ✨ src/migrations/1736458800000-AddRevenueCatFieldsToUsers.ts              │
│  ✨ src/modules/payments/revenuecat.service.ts                              │
│  ✨ src/modules/payments/revenuecat-webhook.controller.ts                   │
│  ✏️ src/modules/payments/payments.module.ts                                 │
│  ✏️ src/common/entities/user.entity.ts                                      │
│                                                                              │
│  FRONTEND (Flutter)                                                          │
│  ────────────────────                                                        │
│  ✨ lib/core/services/revenuecat_service.dart                               │
│  ✏️ pubspec.yaml (purchases_flutter: ^8.2.1)                                │
│  📚 EJEMPLOS_USO_REVENUECAT.dart                                            │
│                                                                              │
│  DOCUMENTACIÓN                                                               │
│  ──────────────                                                              │
│  📖 GUIA_REVENUECAT_GOOGLE_CLOUD.md                                         │
│  📖 GUIA_PRUEBAS_SANDBOX_REVENUECAT.md                                      │
│  📖 INTEGRACION_REVENUECAT_COMPLETA.md                                      │
│  📖 RESUMEN_REVENUECAT.md                                                   │
│  📖 INICIO_RAPIDO_REVENUECAT.md                                             │
│  🔧 verificar-revenuecat.ps1                                                │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                          CHECKLIST DE IMPLEMENTACIÓN                         │
│                                                                              │
│  FASE 1: Configuración Inicial                                              │
│  ────────────────────────────                                               │
│  [ ] Crear Service Account en Google Cloud                                  │
│  [ ] Configurar permisos en Google Play Console                             │
│  [ ] Subir credenciales JSON a RevenueCat                                   │
│  [ ] Copiar API Keys de RevenueCat                                          │
│                                                                              │
│  FASE 2: Backend                                                             │
│  ─────────────────                                                           │
│  [ ] Ejecutar migración: npm run typeorm:run                                │
│  [ ] Configurar REVENUECAT_WEBHOOK_SECRET en .env                           │
│  [ ] Verificar que servicios carguen sin errores                            │
│                                                                              │
│  FASE 3: Frontend                                                            │
│  ──────────────────                                                          │
│  [ ] Instalar dependencias: flutter pub get                                 │
│  [ ] Configurar API Keys en revenuecat_service.dart                         │
│  [ ] Inicializar RevenueCat en login                                        │
│  [ ] Implementar pantalla de suscripción                                    │
│                                                                              │
│  FASE 4: Webhooks                                                            │
│  ───────────────────                                                         │
│  [ ] Exponer backend públicamente (ngrok/producción)                        │
│  [ ] Configurar URL webhook en RevenueCat                                   │
│  [ ] Probar con "Send Test" en RevenueCat                                   │
│                                                                              │
│  FASE 5: Testing                                                             │
│  ──────────────────                                                          │
│  [ ] Crear productos en Google Play Console                                 │
│  [ ] Agregar cuentas de tester                                              │
│  [ ] Generar APK y subir a Internal Testing                                 │
│  [ ] Realizar compra de prueba en Sandbox                                   │
│  [ ] Verificar webhook llega al backend                                     │
│  [ ] Verificar BD se actualiza correctamente                                │
│                                                                              │
│  ✅ TODO LISTO PARA PRODUCCIÓN                                              │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                            DATOS CLAVE A GUARDAR                             │
│                                                                              │
│  🔑 API Keys de RevenueCat:                                                 │
│      Android: goog_xxxxxxxxxxxxxxxxxxxxxxxx                                 │
│      iOS: appl_xxxxxxxxxxxxxxxxxxxxxxxx                                     │
│                                                                              │
│  🔐 Webhook Secret:                                                          │
│      sk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                                    │
│                                                                              │
│  📧 Service Account Email:                                                   │
│      revenuecat-struky@proyecto-id.iam.gserviceaccount.com                  │
│                                                                              │
│  📦 Package Name:                                                            │
│      com.struky.music                                                        │
│                                                                              │
│  🎯 Entitlement ID:                                                          │
│      premium                                                                 │
│                                                                              │
│  💎 Offering ID:                                                             │
│      premium_monthly                                                         │
│                                                                              │
│  🌐 Webhook Endpoint:                                                        │
│      https://tu-backend.com/api/webhooks/revenuecat                         │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                              PRÓXIMOS PASOS                                  │
│                                                                              │
│  1️⃣  Configurar API Keys de RevenueCat                                     │
│       └─ Editar: lib/core/services/revenuecat_service.dart                  │
│                                                                              │
│  2️⃣  Ejecutar migración de base de datos                                   │
│       └─ Comando: cd apps/backend; npm run typeorm:run                      │
│                                                                              │
│  3️⃣  Crear Service Account en Google Cloud                                 │
│       └─ Guía: GUIA_REVENUECAT_GOOGLE_CLOUD.md                              │
│                                                                              │
│  4️⃣  Configurar Webhook en RevenueCat                                      │
│       └─ URL: https://tu-backend.com/api/webhooks/revenuecat                │
│                                                                              │
│  5️⃣  Probar en Sandbox                                                     │
│       └─ Guía: GUIA_PRUEBAS_SANDBOX_REVENUECAT.md                           │
│                                                                              │
│  📚 Consultar: INTEGRACION_REVENUECAT_COMPLETA.md para detalles             │
└─────────────────────────────────────────────────────────────────────────────┘
```
