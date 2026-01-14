# 🔧 Guía de Implementación - Suscripciones Híbridas

## ✅ Paso 1: Ejecutar Migración

```bash
cd apps/backend
npm run typeorm migration:run
```

## ✅ Paso 2: Actualizar Backend `users.controller.ts`

### En `markAsPremium` (línea ~187):

```typescript
@Post(':id/premium')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
async markAsPremium(
  @Param('id') id: string,
  @Body() body: { expiresAt?: string; plan?: 'quincenal' | 'mensual' | 'anual' } = {},
) {
  console.log(`[UsersController] markAsPremium solicitado para ${id}`, body);
  
  // 🔒 VALIDACIÓN: No permitir activar manualmente si tiene RevenueCat activo
  const user = await this.usersService.findOne(id);
  if (user.revenuecatCustomerId && user.subscriptionSource === 'revenuecat') {
    throw new BadRequestException(
      'Este usuario tiene suscripción activa vía RevenueCat. ' +
      'No se puede modificar manualmente. ' +
      'Debe cancelarse desde Google Play o App Store.'
    );
  }
  
  let expiresAt: Date | undefined;

  // Lógica de planes predefinidos
  if (body?.plan) {
    const now = new Date();
    switch (body.plan) {
      case 'quincenal':
        expiresAt = new Date(now.setDate(now.getDate() + 15));
        break;
      case 'mensual':
        expiresAt = new Date(now.setMonth(now.getMonth() + 1));
        break;
      case 'anual':
        expiresAt = new Date(now.setFullYear(now.getFullYear() + 1));
        break;
      default:
        console.warn(`[UsersController] Plan no reconocido: ${body.plan}`);
    }
  } else if (body?.expiresAt) {
    expiresAt = new Date(body.expiresAt);
  }

  console.log(`[Users Controller] Fecha de expiración calculada:`, expiresAt);

  if (expiresAt && isNaN(expiresAt.getTime())) {
    throw new BadRequestException('Fecha de expiración inválida generada');
  }

  const updatedUser = await this.usersService.markAsPremium(id, expiresAt);
  return this.usersService.transformUserData(updatedUser);
}
```

### En `removePremium` (línea ~232):

```typescript
@Post(':id/remove-premium')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
async removePremium(@Param('id') id: string) {
  // 🔒 VALIDACIÓN: No permitir quitar suscripciones RevenueCat
  const user = await this.usersService.findOne(id);
  if (user.subscriptionSource === 'revenuecat') {
    throw new BadRequestException(
      'No se puede quitar suscripción de RevenueCat. ' +
      'Las suscripciones de Google Play/App Store deben cancelarse desde la tienda.'
    );
  }
  
  const updatedUser = await this.usersService.removePremium(id);
  return this.usersService.transformUserData(updatedUser);
}
```

## ✅ Paso 3: Actualizar `users.service.ts`

### En `markAsPremium`:

```typescript
async markAsPremium(id: string, expiresAt?: Date): Promise<User> {
  const user = await this.findOne(id);
  user.subscriptionStatus = SubscriptionStatus.ACTIVE;
  user.subscriptionExpiresAt = expiresAt || null;
  user.subscriptionSource = 'manual'; // ✅ Marcar como manual
  
  const savedUser = await this.userRepository.save(user);
  
  // Notificar WebSocket
  try {
    this.realtimeGateway.notifyPremiumStatusChange(user.id, 'active');
  } catch (error) {
    console.error('Error enviando notificación WebSocket:', error);
  }
  
  return savedUser;
}
```

## ✅ Paso 4: Actualizar Webhook RevenueCat

### En `revenuecat.service.ts` (método `markPremiumFromRevenueCat`):

Buscar donde se guarda el usuario después de activación y agregar:

```typescript
user.subscriptionSource = 'revenuecat'; // ✅ Marcar como RevenueCat
```

## ✅ Paso 5: Actualizar Admin TypeScript

### En `apps/admin/src/types/user.ts`:

Ya agregaste `revenuecatCustomerId`, ahora agrega `subscriptionSource`:

```typescript
export interface UserModel {
  id: string;
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  avatarUrl?: string | null;
  role: UserRole;
  subscriptionStatus: SubscriptionStatus;
  subscriptionExpiresAt?: string | null;
  revenuecatCustomerId?: string | null;
  subscriptionSource?: 'revenuecat' | 'manual'; // ✅ NUEVO
  isVerified: boolean;
  isActive: boolean;
  lastLoginAt?: string | null;
  createdAt: string;
  updatedAt: string;
  artist?: ArtistSummary | null;
}
```

## ✅ Paso 6: El Frontend (página Premium) ya está listo

La página `premium/page.tsx` ya tiene:
- ✅ Columna "Origen de Suscripción"
- ✅ Badge diferenciado (RevenueCat vs Manual)

Solo falta **deshabilitar el botón "Quitar" cuando es RevenueCat**.

---

## 🎯 Resultado Final:

| Usuario | Origen | Expira | Acciones |
|---------|--------|--------|----------|
| user@gmail.com | 🛒 RevenueCat | 2026-02-15 | Renovar / ~~Quitar~~ (deshabilitado) |
| user2@gmail.com | 👤 Manual | 2026-01-20 | Renovar / Quitar ✅ |

**Con tooltip:** "No se puede quitar una suscripción de RevenueCat"
