import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔐 SERVICIO DE AUTENTICACIÓN SOCIAL
/// Maneja login con Google y Facebook
class SocialAuthService {
  bool _isGoogleInitialized = false;

  /// Inicializa GoogleSignIn (requerido en SDK 7.2.0+)
  Future<void> _ensureGoogleInitialized() async {
    if (!_isGoogleInitialized) {
      await GoogleSignIn.instance.initialize();
      _isGoogleInitialized = true;
    }
  }

  /// 🔵 LOGIN CON GOOGLE
  Future<Map<String, String>?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      
      final googleSignIn = GoogleSignIn.instance;
      
      // Cerrar sesión previa
      await googleSignIn.signOut();
      
      // Iniciar sesión interactiva
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );
      
      // Obtener ID Token (autenticación)
      final googleAuth = googleUser.authentication;
      final String idToken = googleAuth.idToken ?? '';
      
      // Obtener Access Token (autorización)
      String accessToken = '';
      try {
        final authClient = googleUser.authorizationClient;
        final clientAuth = await authClient.authorizationForScopes(['email', 'profile'])
            ?? await authClient.authorizeScopes(['email', 'profile']);
        accessToken = clientAuth.accessToken;
      } catch (e) {
        // Fallback or ignore if scopes are not heavily required for just identity
        print('Warning getting access token: $e');
      }
      
      return {
        'provider': 'google',
        'accessToken': accessToken.isNotEmpty ? accessToken : idToken,
        'idToken': idToken,
        'email': googleUser.email,
        'displayName': googleUser.displayName ?? '',
        'photoUrl': googleUser.photoUrl ?? '',
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error en Google Sign-In: $e');
      // No relanzar si es cancelación del usuario para no romper el flujo
      return null;
    }
  }

  /// 🔴 LOGIN CON FACEBOOK
  Future<Map<String, String>?> signInWithFacebook() async {
    try {
      await FacebookAuth.instance.logOut();
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
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
        return null;
      } else {
        throw Exception('Facebook login failed: ${result.message}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error en Facebook Sign-In: $e');
      rethrow;
    }
  }

  /// 🔓 CERRAR SESIÓN
  Future<void> signOut() async {
    try {
      if (!_isGoogleInitialized) {
        // Do not force initialization just to sign out
        // but if we have the instance we can call signOut without initialize IF NOT STRICTLY enforced,
        // Actually, to be safe, we init first.
        await _ensureGoogleInitialized();
      }
      await Future.wait([
        GoogleSignIn.instance.signOut(),
        FacebookAuth.instance.logOut(),
      ]);
    } catch (e) {
      // ignore
      print('Sign out error: $e');
    }
  }
}

/// 📦 PROVIDER de Riverpod
final socialAuthServiceProvider = Provider((ref) => SocialAuthService());
