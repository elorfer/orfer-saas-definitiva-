# 🔐 IMPLEMENTACIÓN COMPLETA: Login con Facebook y Google

## ✅ **PASO 1: Paquetes Instalados** 

```
✅ google_sign_in
✅ flutter_facebook_auth
```

---

## 📋 **PASO 2: Configuración de Consolas de Desarrolladores**

### **🔵 Google OAuth (30 min)**

#### **2.1 - Crear Proyecto en Firebase/Google Cloud**

1. Ve a: https://console.firebase.google.com/
2. Click "Agregar proyecto" → Nombre: "Vintage Music"
3. Desactiva Google Analytics (opcional)
4. Click "Crear proyecto"

#### **2.2 - Habilitar Google Sign-In**

1. En Firebase Console → "Authentication" → "Get Started"
2. Click "Sign-in method"
3. Habilitar "Google" → Guardar

#### **2.3 - Configurar Android**

```bash
# Descargar google-services.json
# Firebase Console → Project Settings → General → Your apps
# Click "Add app" → Android icon
# Package name: com.yourapp.vintagemusic  # Ajusta según tu package
# Download google-services.json
# Mover a: apps/frontend/android/app/google-services.json
```

**Agregar al `android/build.gradle`:**
```gradle
buildscript {
    dependencies {
        // Agregar esta línea
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**Agregar al `android/app/build.gradle`:**
```gradle
// Al final del archivo
apply plugin: 'com.google.gms.google-services'
```

#### **2.4 - Obtener SHA-1**

```bash
cd apps/frontend/android
./gradlew signingReport

# Copia el SHA-1 que aparece en "debug"
# Ejemplo: SHA1: A1:B2:C3:D4...
```

Agrégalo en Firebase Console → Project Settings → Your apps → SHA certificate fingerprints

#### **2.5 - Obtener Client ID**

En Firebase Console → Project Settings → General:
- Copia el "Web client ID" (algo como: `123456789-abc.apps.googleusercontent.com`)

---

### **🔴 Facebook OAuth (30 min)**

#### **2.6 - Crear App en Facebook Developers**

1. Ve a: https://developers.facebook.com/apps/create/
2. Tipo de app: **Consumer** 
3. Nombre: "Vintage Music"
4. Email de contacto: tu@email.com
5. Click "Crear app"

#### **2.7 - Configurar Facebook Login**

1. En Dashboard → "Configurar" Facebook Login
2. Plataforma: **Android**
3. Package name: `com.yourapp.vintagemusic`
4. Clase principal: `com.yourapp.vintagemusic.MainActivity`

#### **2.8 - Obtener App ID**

En Dashboard → Settings → Basic:
- Copia el **App ID** (ej: 1234567890123456)
- Copia el **App Secret** (guarda seguro)

#### **2.9 - Configurar Hash Key para Android**

```bash
# Windows PowerShell
keytool -exportcert -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" | openssl sha1 -binary | openssl base64

# Si pide password: android
```

Copia el hash y agrégalo en Facebook Developers → Settings → Basic → Key Hashes

---

## 📱 **PASO 3: Configuración del Código**

### **3.1 - Crear Servicio de Auth Social**

Crea: `apps/frontend/lib/core/services/social_auth_service.dart`

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class SocialAuthService {
  // Google Sign-In
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // 🔑 TODO: Reemplaza con tu Web Client ID de Firebase
    clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
  );

  /// 🔵 LOGIN CON GOOGLE
  Future<Map<String, String>?> signInWithGoogle() async {
    try {
      // Cerrar sesión previa para forzar selector de cuenta
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        // Usuario canceló
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      
      return {
        'provider': 'google',
        'accessToken': auth.accessToken ?? '',
        'idToken': auth.idToken ?? '',
        'email': account.email,
        'displayName': account.displayName ?? '',
        'photoUrl': account.photoUrl ?? '',
      };
    } catch (e) {
      print('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  /// 🔴 LOGIN CON FACEBOOK
  Future<Map<String, String>?> signInWithFacebook() async {
    try {
      // Logout previo para forzar nuevo login
      await FacebookAuth.instance.logOut();
      
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        // Obtener datos del usuario
        final userData = await FacebookAuth.instance.getUserData(
          fields: 'email,name,picture.width(200)',
        );

        return {
          'provider': 'facebook',
          'accessToken': result.accessToken!.tokenString,
          'email': userData['email'] ?? '',
          'displayName': userData['name'] ?? '',
          'photoUrl': userData['picture']?['data']?['url'] ?? '',
        };
      } else if (result.status == LoginStatus.cancelled) {
        // Usuario canceló
        return null;
      } else {
        throw Exception('Facebook login failed: ${result.message}');
      }
    } catch (e) {
      print('Error en Facebook Sign-In: $e');
      rethrow;
    }
  }

  /// 🔓 CERRAR SESIÓN (ambas plataformas)
  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);
  }
}

// Provider de Riverpod
final socialAuthServiceProvider = Provider((ref) => SocialAuthService());
```

### **3.2 - Agregar Métodos al AuthProvider**

En `apps/frontend/lib/core/providers/auth_provider.dart`, agrega:

```dart
// Dentro de AuthNotifier class:

/// 🔵 LOGIN CON GOOGLE
Future<void> signInWithGoogle () async {
  state = state.copyWith(isLoading: true, error: null);
  
  try {
    final socialAuth = ref.read(socialAuthServiceProvider);
    final authData = await socialAuth.signInWithGoogle();
    
    if (authData == null) {
      // Usuario canceló
      state = state.copyWith(isLoading: false);
      return;
    }

    // Enviar al backend
    final response = await _authService.socialLogin(
      provider: authData['provider']!,
      accessToken: authData['accessToken']!,
      email: authData['email']!,
      displayName: authData['displayName']!,
      photoUrl: authData['photoUrl']!,
    );

    await _saveUserData(response);
    state = state.copyWith(
      user: response.user,
      isAuthenticated: true,
      isLoading: false,
    );
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: 'Error al iniciar sesión con Google: ${e.toString()}',
    );
  }
}

/// 🔴 LOGIN CON FACEBOOK
Future<void> signInWithFacebook() async {
  state = state.copyWith(isLoading: true, error: null);
  
  try {
    final socialAuth = ref.read(socialAuthServiceProvider);
    final authData = await socialAuth.signInWithFacebook();
    
    if (authData == null) {
      // Usuario canceló
      state = state.copyWith(isLoading: false);
      return;
    }

    // Enviar al backend
    final response = await _authService.socialLogin(
      provider: authData['provider']!,
      accessToken: authData['accessToken']!,
      email: authData['email']!,
      displayName: authData['displayName']!,
      photoUrl: authData['photoUrl']!,
    );

    await _saveUserData(response);
    state = state.copyWith(
      user: response.user,
      isAuthenticated: true,
      isLoading: false,
    );
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: 'Error al iniciar sesión con Facebook: ${e.toString()}',
    );
  }
}
```

### **3.3 - Agregar Endpoint al AuthService**

En `apps/frontend/lib/core/services/auth_service.dart`, agrega:

```dart
/// 🌐 LOGIN SOCIAL (Google/Facebook)
Future<AuthResponse> socialLogin({
  required String provider,
  required String accessToken,
  required String email,
  required String displayName,
  String? photoUrl,
}) async {
  try {
    final response = await _client.post(
      '/auth/social/login',
      data: {
        'provider': provider,
        'accessToken': accessToken,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      },
    );

    return AuthResponse.fromJson(response.data);
  } catch (e) {
    throw _handleError(e);
  }
}
```

### **3.4 - Actualizar Botones Sociales**

En `register_screen.dart` (líneas 572-600), reemplaza:

```dart
// Botones de autenticación social
Row(
  children: [
    Flexible(
      flex: 1,
      child: SocialAuthButton(
        icon: Icons.g_mobiledata,
        text: 'Google',
        onPressed: isLoading
            ? null
            : () async {
                await authNotifier.signInWithGoogle();
              },
      ),
    ),
    const SizedBox(width: 12),
    Flexible(
      flex: 1,
      child: SocialAuthButton(
        icon: Icons.facebook,  // Cambiar de Icons.apple
        text: 'Facebook',
        onPressed: isLoading
            ? null
            : () async {
                await authNotifier.signInWithFacebook();
              },
        backgroundColor: const Color(0xFF1877F2),  // Azul de Facebook
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
    ),
  ],
),
```

---

## 🔧 **PASO 4: Backend - Endpoint de Social Login**

### **4.1 - Crear DTO para Social Login**

Crea: `apps/backend/src/modules/auth/dto/social-login.dto.ts`

```typescript
import { IsString, IsEmail, IsOptional, IsIn } from 'class-validator';

export class SocialLoginDto {
  @IsString()
  @IsIn(['google', 'facebook'])
  provider: 'google' | 'facebook';

  @IsString()
  accessToken: string;

  @IsEmail()
  email: string;

  @IsString()
  displayName: string;

  @IsOptional()
  @IsString()
  photoUrl?: string;
}
```

### **4.2 - Agregar Método al AuthService**

En `apps/backend/src/modules/auth/auth.service.ts`, agrega:

```typescript
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { SocialLoginDto } from './dto/social-login.dto';
import { google } from 'googleapis';
import axios from 'axios';

@Injectable()
export class AuthService {
  // ... código existente ...

  /**
   * 🌐 LOGIN SOCIAL (Google/Facebook)
   */
  async socialLogin(socialLoginDto: SocialLoginDto) {
    const { provider, accessToken, email, displayName, photoUrl } = socialLoginDto;

    // Verificar token según provider
    let verifiedEmail: string;
    let verifiedName: string;

    if (provider === 'google') {
      // Verificar Google token
      const googleUser = await this.verifyGoogleToken(accessToken);
      verifiedEmail = googleUser.email;
      verifiedName = googleUser.name;
    } else if (provider === 'facebook') {
      // Verificar Facebook token
      const fbUser = await this.verifyFacebookToken(accessToken);
      verifiedEmail = fbUser.email;
      verifiedName = fbUser.name;
    } else {
      throw new UnauthorizedException('Provider no soportado');
    }

    // Buscar o crear usuario
    let user = await this.usersService.findByEmail(verifiedEmail);

    if (!user) {
      // Crear nuevo usuario
      user = await this.usersService.create({
        email: verifiedEmail,
        username: this.generateUsername(verifiedEmail),
        password: this.generateRandomPassword(), // Password random (no se usará)
        firstName: verifiedName.split(' ')[0] || 'Usuario',
        lastName: verifiedName.split(' ').slice(1).join(' ') || '',
        role: UserRole.USER,
        photoUrl,
        emailVerified: true, // Email ya verificado por Google/Facebook
      });
    }

    // Generar token JWT
    const tokens = await this.generateTokens(user);

    return {
      user,
      ...tokens,
    };
  }

  /**
   * ✅ Verificar Google Token
   */
  private async verifyGoogleToken(token: string) {
    try {
      const oauth2Client = new google.auth.OAuth2();
      const ticket = await oauth2Client.verifyIdToken({
        idToken: token,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
      
      const payload = ticket.getPayload();
      
      return {
        email: payload.email,
        name: payload.name,
        picture: payload.picture,
      };
    } catch (error) {
      throw new UnauthorizedException('Google token inválido');
    }
  }

  /**
   * ✅ Verificar Facebook Token
   */
  private async verifyFacebookToken(token: string) {
    try {
      const response = await axios.get(
        `https://graph.facebook.com/me?fields=id,email,name&access_token=${token}`
      );
      
      return {
        email: response.data.email,
        name: response.data.name,
        id: response.data.id,
      };
    } catch (error) {
      throw new UnauthorizedException('Facebook token inválido');
    }
  }

  /**
   * 🔧 Generar username aleatorio desde email
   */
  private generateUsername(email: string): string {
    const baseUsername = email.split('@')[0].toLowerCase();
    const randomSuffix = Math.floor(Math.random() * 10000);
    return `${baseUsername}${randomSuffix}`;
  }

  /**
   * 🔐 Generar password random (no se usará)
   */
  private generateRandomPassword(): string {
    return Math.random().toString(36).slice(-12);
  }
}
```

### **4.3 - Agregar Endpoint al Controller**

En `apps/backend/src/modules/auth/auth.controller.ts`, agrega:

```typescript
@Post('social/login')
@HttpCode(HttpStatus.OK)
async socialLogin(@Body() socialLoginDto: SocialLoginDto) {
  return this.authService.socialLogin(socialLoginDto);
}
```

### **4.4 - Instalar Dependencias del Backend**

```bash
cd apps/backend
npm install googleapis axios
```

### **4.5 - Agregar Variables de Entorno**

En `.env`:
```env
# Google OAuth
GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com

# Facebook OAuth (opcional - para validación extra)
FACEBOOK_APP_ID=1234567890123456
FACEBOOK_APP_SECRET=your_app_secret_here
```

---

## 📱 **PASO 5: Configuración Android**

### **5.1 - AndroidManifest.xml**

En `apps/frontend/android/app/src/main/AndroidManifest.xml`, agrega:

```xml
<manifest>
    <application>
        <!-- Código existente -->
        
        <!-- Facebook -->
        <meta-data
            android:name="com.facebook.sdk.ApplicationId"
            android:value="@string/facebook_app_id"/>
        
        <meta-data
            android:name="com.facebook.sdk.ClientToken"
            android:value="@string/facebook_client_token"/>

        <activity
            android:name="com.facebook.FacebookActivity"
            android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
            android:label="@string/app_name" />
        
        <activity
            android:name="com.facebook.CustomTabActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="@string/fb_login_protocol_scheme" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### **5.2 - strings.xml**

Crea/edita: `apps/frontend/android/app/src/main/res/values/strings.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Vintage Music</string>
    <!-- TODO: Reemplaza con tu Facebook App ID -->
    <string name="facebook_app_id">1234567890123456</string>
    <string name="fb_login_protocol_scheme">fb1234567890123456</string>
    <string name="facebook_client_token">YOUR_CLIENT_TOKEN_HERE</string>
</resources>
```

---

## ✅ **CHECKLIST FINAL**

### ☐ Configuración Externa:
- [ ] Crear proyecto en Firebase
- [ ] Habilitar Google Sign-In
- [ ] Descargar `google-services.json`
- [ ] Obtener SHA-1 y agregarlo a Firebase
- [ ] Crear app en Facebook Developers
- [ ] Obtener App ID de Facebook
- [ ] Generar Key Hash para Facebook

### ☐ Código Frontend:
- [ ] Crear `social_auth_service.dart`
- [ ] Agregar métodos a `auth_provider.dart`
- [ ] Agregar método a `auth_service.dart`
- [ ] Actualizar botones en `register_screen.dart`
- [ ] Configurar `AndroidManifest.xml`
- [ ] Crear `strings.xml`
- [ ] Reemplazar Client IDs/App IDs reales

### ☐ Código Backend:
- [ ] Crear `social-login.dto.ts`
- [ ] Agregar métodos a `auth.service.ts`
- [ ] Agregar endpoint a `auth.controller.ts`
- [ ] Instalar: `npm install googleapis axios`
- [ ] Agregar variables de entorno

---

## 🚀 **TESTING**

1. **Compilar app:**
   ```bash
   flutter run --release
   ```

2. **Probar Google:**
   - Click en "Google"
   - Seleccionar cuenta
   - Verificar que loguea correctamente

3. **Probar Facebook:**
   - Click en "Facebook"
   - Ingresar credenciales
   - Verificar que loguea correctamente

---

## ❓ **TROUBLESHOOTING**

### Google no funciona:
- ✅ Verificar SHA-1 en Firebase
- ✅ Verificar `google-services.json` en lugar correcto
- ✅ Verificar Client ID en `social_auth_service.dart`

### Facebook no funciona:
- ✅ Verificar App ID en `strings.xml`
- ✅ Verificar Key Hash en Facebook Developers
- ✅ Verificar Package Name correcto

---

**¿Quieres que implemente algún paso en específico o prefieres hacerlo por tu cuenta siguiendo esta guía?** 🚀
