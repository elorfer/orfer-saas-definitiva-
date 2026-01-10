import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔐 SERVICIO DE AUTENTICACIÓN SOCIAL
/// Maneja login con Google y Facebook
class SocialAuthService {
  // 🔵 Google Sign-In (configuración simplificada para Android)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  /// 🔵 LOGIN CON GOOGLE
  Future<Map<String, String>?> signInWithGoogle() async {
    try {
      // Cerrar sesión previa para SIEMPRE mostrar selector de cuenta
      await _googleSignIn.signOut();
      
      // Iniciar sesión
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // Usuario canceló
        return null;
      }

      // Obtener detalles de autenticación
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      return {
        'provider': 'google',
        'accessToken': googleAuth.accessToken ?? googleAuth.idToken ?? '',
        'idToken': googleAuth.idToken ?? '',
        'email': googleUser.email,
        'displayName': googleUser.displayName ?? '',
        'photoUrl': googleUser.photoUrl ?? '',
      };
    } catch (e) {
      print('❌ Error en Google Sign-In: $e');
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
      print('❌ Error en Facebook Sign-In: $e');
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

/// 📦 PROVIDER de Riverpod
final socialAuthServiceProvider = Provider((ref) => SocialAuthService());
