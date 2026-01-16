# 🔧 Configuration Errors - Resolution Guide

## Errors Detected

### 1. ❌ Firebase Auth Error
```
Error creando usuario en Firebase Auth:
La implementación de credenciales proporcionada a initializeApp() 
a través de la propiedad "credential" no pudo obtener un token de 
acceso de Google OAuth2 válido con el siguiente error: 
"error:1E08010C:DECODER routines::unsupported".
```

### 2. ❌ R2 SSL Handshake Error
```
Error de carga de S3: Error: escritura EPROTO
error:0A000410:Rutinas SSL:ssl3_read_bytes:Fallo de protocolo 
de enlace de alerta sslv3
Número de alerta SSL 40
```

## Root Causes

### Firebase Error
- **Missing credentials** in `.env` file
- The code in `firebase.service.ts` expects these environment variables:
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_CLIENT_EMAIL`
  - `FIREBASE_PRIVATE_KEY`
  
### R2 Error
- **Missing R2 credentials** in `.env` file
- The code in `s3.service.ts` expects these environment variables:
  - `R2_ACCOUNT_ID`
  - `R2_ACCESS_KEY_ID`
  - `R2_SECRET_ACCESS_KEY`
  - `R2_BUCKET_NAME`
  - `R2_PUBLIC_DOMAIN`

## ✅ What I Fixed

1. **Removed malformed syntax** - Deleted stray `}` character at line 40
2. **Added R2 configuration section** with placeholder values
3. **Added Firebase configuration section** (commented out, as it's optional)
4. **Removed duplicate entries** that were corrupting the file

## 📝 Action Items (YOU MUST DO)

### For R2 (REQUIRED - To fix image uploads)

You need to get your actual Cloudflare R2 credentials and update these values in `apps/backend/.env`:

```bash
R2_ACCOUNT_ID=your_actual_account_id
R2_ACCESS_KEY_ID=your_actual_access_key
R2_SECRET_ACCESS_KEY=your_actual_secret_key
R2_BUCKET_NAME=struky-media  # or your actual bucket name
R2_PUBLIC_DOMAIN=your_actual_public_domain  # e.g., media.struky.com
```

**Where to get R2 credentials:**
1. Go to https://dash.cloudflare.com
2. Navigate to R2 → Overview
3. Your Account ID is shown in the sidebar
4. Click "Manage R2 API Tokens" to create access keys
5. Set up a public bucket domain under "Public Buckets" or custom domain

### For Firebase (OPTIONAL - Only if you use Firebase Auth)

If you're using Firebase for authentication, uncomment and fill these in `apps/backend/.env`:

```bash
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYourActualKeyHere\n-----END PRIVATE KEY-----\n"
```

**Where to get Firebase credentials:**
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. A JSON file will download with all the credentials

**Important**: The private key must keep the newline characters (`\n`) intact!

### If You Don't Use Firebase Auth
The Firebase error can be safely ignored if you're not using Firebase authentication.
The code in `firebase.service.ts` gracefully handles missing credentials (lines 17-20).

## 🔄 Next Steps

After updating the credentials:

1. **Restart the backend:**
   ```bash
   # Stop the current backend (Ctrl+C in the terminal)
   npm run dev:backend-admin
   ```

2. **Test R2 upload:**
   - Try uploading an artist image from the admin panel
   - Check the backend logs for success message instead of SSL error

3. **Verify the fixes:**
   - Firebase error should disappear (or you'll see "✅ Firebase Admin SDK initialized successfully")
   - R2 uploads should work without SSL errors
   - Artist images should be properly stored and displayed

## 🔍 Current State

- ✅ `.env` file is now properly formatted
- ✅ All required configuration sections are present
- ⏳ Waiting for you to fill in actual R2 credentials
- ⏳ Backend needs restart after credentials are added

## 📚 Related Files

- `apps/backend/.env` - Environment configuration (UPDATED)
- `apps/backend/src/common/services/firebase.service.ts` - Firebase initialization
- `apps/backend/src/modules/upload/s3.service.ts` - R2/S3 upload service

## 💡 Pro Tip

The R2 service already has the SSL workaround configured (lines 48-54 in `s3.service.ts`):
```typescript
requestHandler: new NodeHttpHandler({
  httpsAgent: new https.Agent({
    ciphers: 'DEFAULT@SECLEVEL=0',
    rejectUnauthorized: false
  }),
}),
```

This should resolve the SSL handshake issue **once you provide valid R2 credentials**.
