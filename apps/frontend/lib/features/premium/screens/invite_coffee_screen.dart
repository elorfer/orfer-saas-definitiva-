import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/revenuecat_service.dart';
import '../widgets/coffee_product_card.dart';

class InviteCoffeeScreen extends ConsumerStatefulWidget {
  const InviteCoffeeScreen({super.key});

  @override
  ConsumerState<InviteCoffeeScreen> createState() => _InviteCoffeeScreenState();
}

class _InviteCoffeeScreenState extends ConsumerState<InviteCoffeeScreen> {
  final RevenueCatService _revenueCatService = RevenueCatService();
  List<Package> _packages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precargar la imagen para que aparezca instantáneamente
    precacheImage(const AssetImage('assets/images/coffes/hero_coffee.webp'), context);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtenemos exclusivamente el offering de 'coffees'
      final packages = await _revenueCatService.getOfferingPackages('coffees');
      
      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudieron cargar los productos. Intenta de nuevo.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePurchase(Package package) async {
    try {
      final success = await _revenueCatService.purchasePackage(package);
      if (success && mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted && e.toString() != 'Exception: Compra cancelada') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeumorphismTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¡Gracias! ☕', textAlign: TextAlign.center),
        content: const Text(
          'Tu apoyo significa mucho para los compositores de Struky. ¡Sigue disfrutando de la música!',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('De nada'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: NeumorphismTheme.backgroundGradient,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: NeumorphismTheme.textPrimary),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Invitar un Café',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: NeumorphismTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balancing back button
                    ],
                  ),
                ),
                
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                      ? _buildErrorView()
                      : _packages.isEmpty
                        ? _buildEmptyView()
                        : _buildProductsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Custom Hero Image - Ahora scrolleable
        SizedBox(
          height: 220, // Ajustado para la nueva imagen
          width: double.infinity,
          child: Image.asset(
            'assets/images/coffes/hero_coffee.webp',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¡Dales energía para crear!',
          style: AppTextStyles.titleMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Invita un café a nuestros compositores y motívalos a seguir escribiendo las canciones que tanto amas.',
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadProducts,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.coffee_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          Text(
            'No hay cafés disponibles\nen este momento.',
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: 100, // Espacio extra para que el mini-reproductor no tape el contenido
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(), // <-- Imagen de portada y textos añadidos al scroll
          
          const SizedBox(height: 32),
          
          // Lista de productos
          ..._packages.map((package) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CoffeeProductCard(
              package: package,
              onPurchase: () => _handlePurchase(package),
            ),
          )),
          
          const SizedBox(height: 40),
          
          Text(
            'Las compras son procesadas de forma segura por Google Play.',
            style: AppTextStyles.caption.copyWith(
              color: NeumorphismTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

