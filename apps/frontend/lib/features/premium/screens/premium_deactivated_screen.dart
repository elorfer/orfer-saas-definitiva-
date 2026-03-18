import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../core/utils/logger.dart';

/// Pantalla de suscripción Premium que presenta los beneficios
/// y motiva al usuario a convertirse en premium.
///
/// Esta pantalla se muestra cuando el usuario no tiene una suscripción activa.
class PremiumDeactivatedScreen extends ConsumerStatefulWidget {
  const PremiumDeactivatedScreen({super.key});

  @override
  ConsumerState<PremiumDeactivatedScreen> createState() => _PremiumDeactivatedScreenState();
}

class _PremiumDeactivatedScreenState extends ConsumerState<PremiumDeactivatedScreen>
    with AutomaticKeepAliveClientMixin {
  // Constantes de diseño
  static const double _horizontalPadding = 24.0;
  static const double _verticalPadding = 20.0;
  static const double _sectionSpacing = 32.0;
  static const double _largeSpacing = 40.0;
  static const double _imageSize = 300.0;
  static const double _iconSize = 64.0;
  static const double _borderRadius = 24.0;
  static const double _buttonHeight = 56.0;
  static const double _buttonBorderRadius = 16.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 🚀 Abrir automáticamente el selector si venimos con el parámetro showPackages
    // Esto responde al bug reportado donde el usuario quiere ir "directamente" al pago
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final state = GoRouterState.of(context);
          if (state.uri.queryParameters['showPackages'] == 'true') {
            _handleSubscribeTap();
          }
        } catch (e) {
          // Silencioso si falla el acceso al router state
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🚀 Optimización: Pre-cargar imágenes para apertura instantánea
    precacheImage(const AssetImage('assets/images/anciano_premiun.webp'), context);
    precacheImage(const AssetImage('assets/images/IMAJEN DE LAS SUSCRIPCIONES.webp'), context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 🚀 Refresh on Theme Change
    ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 400,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                  vertical: _verticalPadding,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: _largeSpacing),
                    _buildHeroSection(),
                    const SizedBox(height: _sectionSpacing),
                    _buildSubscribeButton(isHighlighted: true),
                    const SizedBox(height: _sectionSpacing),
                    _buildMessageSection(
                      title: 'Durante décadas, las canciones que amaste tuvieron un autor invisible.',
                      content: [
                        'Las historias que cantaste, las melodías que te salvaron, salieron de alguien que casi nunca recibió el reconocimiento.',
                        'El artista se llevó los aplausos.',
                        'El compositor, el silencio.',
                        'Pero hoy todo cambia.',
                        'Hoy, tu suscripción cambia el juego.',
                      ],
                    ),
                    const SizedBox(height: _sectionSpacing),
                    _buildEmotionalBenefitSection(),
                    const SizedBox(height: _sectionSpacing),
                    _buildBenefitsList(),
                    const SizedBox(height: _largeSpacing),
                    _buildImpactMessages(),
                    const SizedBox(height: _largeSpacing),
                    _buildFinalMessage(),
                    const SizedBox(height: _largeSpacing),
                    _buildSubscribeButton(isHighlighted: true),
                    const SizedBox(height: 250),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return RepaintBoundary(
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.diamond_rounded,
              size: _iconSize,
              color: NeumorphismTheme.coffeeMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Hazte Premium y Libera la Música que Nunca Escuchaste',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.textPrimary,
                letterSpacing: -0.5,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF2EFEC), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // boxShadow removido
        ),
        child: Column(
          children: [
            Text(
              'Cada suscripción impulsa a un compositor real. No a una marca. No a una multinacional.',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.6,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _borderRadius),
            SizedBox(
              height: _imageSize,
              width: _imageSize,
              child: Image.asset(
                'assets/images/IMAJEN DE LAS SUSCRIPCIONES.webp',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: _borderRadius),
            Text(
              'A un creador que por fin quiere ser escuchado.',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.6,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionalBenefitSection() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF5F2EF), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // Border removido para evitar costo de renderizado
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: NeumorphismTheme.coffeeMedium,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cuando te vuelves Premium, no compras "más funciones":',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Apoyas a un compositor a crear, a crecer y a ser libre.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: NeumorphismTheme.coffeeMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pagas por talento.\nPor arte.\nPor verdad.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsList() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF7F5F3), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // boxShadow removido
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '✨ Beneficios Premium',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _buildBenefitItem(
              icon: Icons.download_rounded,
              text: 'Música sin conexión a internet',
            ),
            _buildBenefitItem(
              icon: Icons.explore_rounded,
              text: 'Descubre canciones exclusivas antes que nadie',
            ),
            _buildBenefitItem(
              icon: Icons.people_rounded,
              text: 'Conecta directamente con compositores independientes',
            ),
            _buildBenefitItem(
              icon: Icons.history_rounded,
              text: 'Accede a historias detrás de cada canción',
            ),
            _buildBenefitItem(
              icon: Icons.attach_money_rounded,
              text: 'Apoya económicamente a los creadores',
            ),
            _buildBenefitItem(
              icon: Icons.trending_up_rounded,
              text: 'Sé parte del nuevo movimiento musical',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactMessages() {
    return Column(
      children: [
        _buildImpactMessage('La industria ocultó sus nombres.'),
        _buildImpactMessage('La historia ignoró sus voces.'),
        _buildImpactMessage('El crédito nunca llegó.'),
        _buildImpactMessage('Hasta hoy.', isHighlight: true),
        const SizedBox(height: 16),
        _buildImpactMessage('La música necesita héroes silenciosos.'),
        _buildImpactMessage('Tú puedes ser uno.', isHighlight: true),
      ],
    );
  }

  Widget _buildSubscribeButton({bool isHighlighted = false}) {
    if (isHighlighted) {
      return Container(
        width: double.infinity,
        height: _buttonHeight + 4,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NeumorphismTheme.coffeeMedium,
              NeumorphismTheme.coffeeDark,
            ],
          ),
          borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
        ),
        // 🚀 OPTIMIZACIÓN: Sin sombras pesadas
        child: Material(
          color: Colors.transparent, 
          borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
          child: InkWell(
            onTap: _handleSubscribeTap,
            borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(
                    Icons.diamond_rounded,
                    color: NeumorphismTheme.isDark ? const Color(0xFF2D2420) : Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Suscribirse a Premium',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.isDark ? const Color(0xFF2D2420) : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      height: _buttonHeight,
      decoration: BoxDecoration(
        color: NeumorphismTheme.isDark ? NeumorphismTheme.surface : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
        border: Border.all(
          color: NeumorphismTheme.isDark ? NeumorphismTheme.accent.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSubscribeTap,
          borderRadius: const BorderRadius.all(Radius.circular(_buttonBorderRadius)),
          child: Center(
            child: Text(
              'Suscribirse a Premium',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.isDark ? NeumorphismTheme.accent : NeumorphismTheme.coffeeDark,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinalMessage() {
    return RepaintBoundary(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(_borderRadius),
          decoration: BoxDecoration(
            color: NeumorphismTheme.isDark 
                ? NeumorphismTheme.surface 
                : const Color(0xFFF0EBE6), // 🚀 OPTIMIZACIÓN: Dinámico
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            children: [
              Text(
                'Porque por primera vez,',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: NeumorphismTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'la música le pertenece a quien la crea,',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'y a quien la apoya.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NeumorphismTheme.coffeeMedium,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscribeTap() async {
    // Verificar que RevenueCat esté inicializado
    final revenueCat = RevenueCatService();
    if (!revenueCat.isInitialized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, inicia sesión primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Obtener paquetes disponibles directamente (sin loading dialog)
      final packages = await revenueCat.getAvailablePackages();

      if (!mounted) return;

      if (packages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay planes disponibles en este momento'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Mostrar bottom sheet con los paquetes
      final selectedPackage = await showModalBottomSheet<Package>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildPackageSelector(packages),
      );

      if (selectedPackage == null || !mounted) return;

      // Realizar compra directamente (sin loading dialog)
      final success = await revenueCat.purchasePackage(selectedPackage);

      if (!mounted) return;

      if (success) {
        // 🔄 Sincronizar estado premium inmediatamente
        try {
          await revenueCat.syncPremiumStatus();
          // Refrescar el usuario en el AuthProvider
          await ref.read(authStateProvider.notifier).refreshProfile();
        } catch (e) {
          AppLogger.error('[PremiumScreen] Error sincronizando estado premium', e);
        }
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 ¡Bienvenido a Premium!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar la compra'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Error al procesar la compra';
      if (e.toString().contains('cancelled') || e.toString().contains('cancelada')) {
        return; // No mostrar error si el usuario canceló
      } else if (e.toString().contains('already purchased')) {
        errorMessage = 'Ya tienes una suscripción activa';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildPackageSelector(List<Package> packages) {
    return Container(
      decoration: BoxDecoration(
        color: NeumorphismTheme.isDark 
            ? NeumorphismTheme.background 
            : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12), // Espacio superior para evitar notch
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32), // Aumentado de 24 a 32

            // Título con botón de cerrar a la izquierda
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12), // Ajustado padding
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded, // Cambiado a cruz
                        color: Colors.grey,
                        size: 28, // Tamaño ligeramente más contenido para alineación
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ),
                ),
                // Subtítulo llamativo (Contenedor con altura fija para evitar saltos)
                SizedBox(
                  height: 60,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Text(
                        '¡Estás a punto de apoyar a un compositor!',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: NeumorphismTheme.accent,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Imagen del anciano en el selector
            SizedBox(
              height: 320,
              width: 320,
              child: Image.asset(
                'assets/images/anciano_premiun.webp',
                fit: BoxFit.contain,
                cacheWidth: 800,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            
            // Título equilibrado
            Text(
              'Elige tu plan',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.isDark 
                    ? Colors.white 
                    : NeumorphismTheme.coffeeDark,
              ),
            ),
            const SizedBox(height: 20),
            
            // Lista de paquetes estable
            Column(
              mainAxisSize: MainAxisSize.min,
              children: packages.map((package) => _buildPackageCard(package)).toList(),
            ),
            
            const SizedBox(height: 16),

            // Botón alternativo: Invitar un café
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/invite-coffee');
                },
                icon: const Icon(Icons.coffee_rounded, size: 20),
                label: const Text(
                  'o invita a un café',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: NeumorphismTheme.accent,
                  side: BorderSide(color: NeumorphismTheme.accent.withValues(alpha: 0.5), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Botón cancelar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  color: Colors.grey,
                ),
              ),
            ),
            
            // Se agrega espacio adicional (180) para que no choque con el mini reproductor
            // (Aumentado de 90 a 180 porque el mini reproductor ahora está más alto)
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 180),
          ],
        ),
      ),
    );
  }

  String _getCleanTitle(Package package) {
    // Si el identificador de RevenueCat es estándar, usamos nombres bonitos
    switch (package.packageType) {
      case PackageType.monthly:
        return 'Suscripción Mensual';
      case PackageType.annual:
        return 'Suscripción Anual';
      case PackageType.lifetime:
        return 'Acceso de por Vida';
      case PackageType.weekly:
        return 'Suscripción Semanal';
      default:
        // Si no es estándar, limpiamos el título original de Google Play
        return package.storeProduct.title
            .replaceAll('(Struky)', '')
            .replaceAll('Struky Premium', 'Premium')
            .trim();
    }
  }

  String _getCleanPeriod(StoreProduct? product) {
    if (product == null || product.subscriptionPeriod == null) return '';
    
    final period = product.subscriptionPeriod!;
    if (period.contains('P1M')) return '/Mes';
    if (period.contains('P1Y')) return '/Año';
    if (period.contains('P1W')) return '/Semana';
    if (period.contains('P2W')) return '/Quincena';
    
    return '/${period.replaceAll('P', '').replaceAll('1', '')}';
  }

  String _getCleanDescription(Package package) {
    final desc = package.storeProduct.description;
    
    // Si la descripción contiene el texto genérico que queremos quitar
    if (desc.contains('Mensual o Anual') || desc.isEmpty) {
      switch (package.packageType) {
        case PackageType.monthly:
          return 'Disfruta de música sin límites todos los meses.';
        case PackageType.annual:
          return 'Acceso total durante un año al mejor precio.';
        case PackageType.lifetime:
          return 'Un solo pago para música de por vida.';
        default:
          return 'Todos los beneficios premium incluidos.';
      }
    }
    
    return desc.trim();
  }

  Widget _buildPackageCard(Package package) {
    final product = package.storeProduct;
    final cleanTitle = _getCleanTitle(package);
    final cleanPeriod = _getCleanPeriod(product);
    final cleanDescription = _getCleanDescription(package);
    
    return GestureDetector(
      onTap: () => Navigator.pop(context, package),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NeumorphismTheme.accent.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icono
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    NeumorphismTheme.coffeeMedium,
                    NeumorphismTheme.coffeeDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.diamond_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanTitle,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: NeumorphismTheme.isDark 
                          ? Colors.white 
                          : NeumorphismTheme.coffeeDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cleanDescription,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: NeumorphismTheme.accent,
                  ),
                ),
                if (cleanPeriod.isNotEmpty)
                  Text(
                    cleanPeriod,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSection({
    required String title,
    required List<String> content,
  }) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_borderRadius),
        decoration: BoxDecoration(
          color: NeumorphismTheme.isDark 
              ? NeumorphismTheme.surface 
              : const Color(0xFFF7F5F3), // 🚀 OPTIMIZACIÓN: Dinámico
          borderRadius: const BorderRadius.all(Radius.circular(_borderRadius)),
          // boxShadow removido
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: NeumorphismTheme.textPrimary,
                letterSpacing: -0.3,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...content.map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: NeumorphismTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(
              icon,
              color: NeumorphismTheme.coffeeMedium,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: NeumorphismTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMessage(String text, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: isHighlight ? 20 : 18,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
          color: isHighlight
              ? NeumorphismTheme.coffeeMedium
              : NeumorphismTheme.textPrimary,
          letterSpacing: isHighlight ? -0.3 : -0.2,
          height: 1.4,
        ),
      ),
    );
  }
}

