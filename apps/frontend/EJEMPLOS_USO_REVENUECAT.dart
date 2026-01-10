// 📌 EJEMPLOS DE USO: RevenueCat Service en Struky
//
// Este archivo contiene ejemplos prácticos de cómo integrar el
// RevenueCatService en diferentes partes de tu app Flutter.

// ============================================================================
// EJEMPLO 1: Inicializar RevenueCat después del Login
// ============================================================================

// En tu auth_service.dart o donde manejes el login exitoso:

import 'package:vintage_music_app/core/services/revenuecat_service.dart';

class AuthService {
  final _revenueCat = RevenueCatService();

  Future<void> loginWithEmail(String email, String password) async {
    try {
      // Tu lógica de login existente...
      final response = await httpClient.post('/auth/login', {
        'email': email,
        'password': password,
      });

      final userId = response.data['user']['id'];
      final userEmail = response.data['user']['email'];

      // 🎯 IMPORTANTE: Inicializar RevenueCat inmediatamente después del login
      await _revenueCat.initialize(
        userId: userId,
        email: userEmail,
      );

      // Verificar estado premium inicial
      if (_revenueCat.isPremium) {
        print('🎉 Usuario es PREMIUM');
      } else {
        print('ℹ️ Usuario es FREE');
      }

    } catch (e) {
      print('Error en login: $e');
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    // Login con Google...
    final googleUser = await signInWithGoogle();
    
    final userId = googleUser.id;
    final email = googleUser.email;

    // Inicializar RevenueCat
    await _revenueCat.initialize(userId: userId, email: email);
  }

  Future<void> logout() async {
    // Tu lógica de logout...
    
    // Cerrar sesión de RevenueCat
    await _revenueCat.logout();
  }
}

// ============================================================================
// EJEMPLO 2: Pantalla de Perfil con Estado Premium
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vintage_music_app/core/services/revenuecat_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _revenueCat = RevenueCatService();
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _listenToPremiumChanges();
  }

  // Verificar estado inicial
  void _checkPremiumStatus() {
    setState(() {
      _isPremium = _revenueCat.isPremium;
    });
  }

  // Escuchar cambios en tiempo real
  void _listenToPremiumChanges() {
    _revenueCat.premiumStatusStream.listen((isPremium) {
      setState(() {
        _isPremium = isPremium;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Column(
        children: [
          // Badge de Premium
          if (_isPremium)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.amber,
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Miembro Premium',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_revenueCat.premiumExpirationDate != null)
                    Text(
                      'Hasta: ${_formatDate(_revenueCat.premiumExpirationDate!)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),

          // Botón para gestionar suscripción
          ListTile(
            leading: const Icon(Icons.star_border),
            title: Text(_isPremium ? 'Gestionar Suscripción' : 'Hazte Premium'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, '/subscription');
            },
          ),

          // Botón de restaurar compras
          if (!_isPremium)
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restaurar Compras'),
              onTap: _restorePurchases,
            ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _revenueCat.restorePurchases();

    Navigator.pop(context); // Cerrar loading

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ Compras restauradas exitosamente'
              : 'No se encontraron compras activas',
        ),
        backgroundColor: success ? Colors.green : Colors.orange,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ============================================================================
// EJEMPLO 3: Paywall (Pantalla de Suscripción)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vintage_music_app/core/services/revenuecat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionPaywallScreen extends StatefulWidget {
  const SubscriptionPaywallScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionPaywallScreen> createState() =>
      _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  final _revenueCat = RevenueCatService();
  List<Package> _packages = [];
  bool _isLoading = true;
  String? _selectedPackageId;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);

    final packages = await _revenueCat.getAvailablePackages();

    setState(() {
      _packages = packages;
      _isLoading = false;

      // Seleccionar el primer paquete por defecto
      if (packages.isNotEmpty) {
        _selectedPackageId = packages.first.identifier;
      }
    });
  }

  Future<void> _purchase() async {
    if (_selectedPackageId == null) return;

    final package = _packages.firstWhere(
      (p) => p.identifier == _selectedPackageId,
    );

    setState(() => _isLoading = true);

    try {
      final success = await _revenueCat.purchasePackage(package);

      if (success && mounted) {
        // Mostrar éxito
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 ¡Bienvenido a Premium!'),
        content: const Text(
          'Ahora puedes disfrutar de Struky sin anuncios y con todas las funciones premium.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver a pantalla anterior
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hazte Premium'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _restorePurchases,
            child: const Text('Restaurar'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _packages.isEmpty
              ? const Center(child: Text('No hay planes disponibles'))
              : Column(
                  children: [
                    // Header con beneficios
                    _buildBenefitsSection(),

                    // Lista de paquetes
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _packages.length,
                        itemBuilder: (context, index) {
                          final package = _packages[index];
                          return _buildPackageCard(package);
                        },
                      ),
                    ),

                    // Botón de compra
                    _buildPurchaseButton(),
                  ],
                ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade400],
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Struky Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Desbloquea todas las funciones',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          _buildBenefit('🎵', 'Sin anuncios'),
          _buildBenefit('⬇️', 'Descargas ilimitadas'),
          _buildBenefit('🎧', 'Audio de alta calidad'),
          _buildBenefit('🌙', 'Modo sin conexión'),
        ],
      ),
    );
  }

  Widget _buildBenefit(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package package) {
    final isSelected = package.identifier == _selectedPackageId;
    final product = package.storeProduct;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackageId = package.identifier;
        });
      },
      child: Card(
        elevation: isSelected ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? Colors.purple : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Radio button
              Radio<String>(
                value: package.identifier,
                groupValue: _selectedPackageId,
                onChanged: (value) {
                  setState(() {
                    _selectedPackageId = value;
                  });
                },
              ),

              // Info del paquete
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Precio
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    product.priceString,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  Text(
                    '/${product.subscriptionPeriod}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _selectedPackageId == null || _isLoading ? null : _purchase,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Suscribirme',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    final success = await _revenueCat.restorePurchases();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ Compras restauradas'
              : 'No se encontraron compras activas',
        ),
        backgroundColor: success ? Colors.green : Colors.orange,
      ),
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}

// ============================================================================
// EJEMPLO 4: Condicionar funcionalidades según estado Premium
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vintage_music_app/core/services/revenuecat_service.dart';

class SongScreen extends StatelessWidget {
  final _revenueCat = RevenueCatService();

  void downloadSong(BuildContext context) {
    // Verificar si es premium
    if (!_revenueCat.isPremium) {
      // Mostrar paywall
      _showPremiumRequired(context);
      return;
    }

    // Proceder con la descarga
    _startDownload();
  }

  void _showPremiumRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⭐ Premium Requerido'),
        content: const Text(
          'La descarga de canciones es una función exclusiva para miembros Premium.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription');
            },
            child: const Text('Hazte Premium'),
          ),
        ],
      ),
    );
  }

  void _startDownload() {
    // Tu lógica de descarga
    print('Iniciando descarga...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tu UI
    );
  }
}

// ============================================================================
// EJEMPLO 5: Guard de Navegación para rutas Premium
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vintage_music_app/core/services/revenuecat_service.dart';

class PremiumGuard {
  static Future<bool> canActivate(BuildContext context) async {
    final revenueCat = RevenueCatService();

    if (!revenueCat.isPremium) {
      // Redirigir al paywall
      await Navigator.pushNamed(context, '/subscription');
      
      // Verificar de nuevo si ahora es premium
      return revenueCat.isPremium;
    }

    return true;
  }
}

// Uso en GoRouter:
/*
GoRoute(
  path: '/premium-playlist',
  builder: (context, state) => PremiumPlaylistScreen(),
  redirect: (context, state) async {
    final canAccess = await PremiumGuard.canActivate(context);
    return canAccess ? null : '/';
  },
)
*/

// ============================================================================
// EJEMPLO 6: Widget Premium Badge
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vintage_music_app/core/services/revenuecat_service.dart';

class PremiumBadge extends StatelessWidget {
  final _revenueCat = RevenueCatService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _revenueCat.premiumStatusStream,
      initialData: _revenueCat.isPremium,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.amber, Colors.orange],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.star, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Premium',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// EJEMPLO 7: Sincronización manual del estado premium
// ============================================================================

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _revenueCat = RevenueCatService();
  bool _isSyncing = false;

  Future<void> _syncPremiumStatus() async {
    setState(() => _isSyncing = true);

    try {
      final isPremium = await _revenueCat.checkPremiumStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPremium
                ? '✅ Estado Premium sincronizado'
                : 'ℹ️ No tienes suscripción activa',
          ),
          backgroundColor: isPremium ? Colors.green : Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sincronizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sincronizar estado premium'),
            subtitle: const Text('Actualizar desde RevenueCat'),
            trailing: _isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios),
            onTap: _isSyncing ? null : _syncPremiumStatus,
          ),
        ],
      ),
    );
  }
}
