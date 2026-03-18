import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';

class CoffeeProductCard extends StatelessWidget {
  final Package package;
  final VoidCallback onPurchase;

  const CoffeeProductCard({
    super.key,
    required this.package,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    final id = package.identifier.toLowerCase();
    
    // Identificar el tipo de café
    final isEspresso = id.contains('espresso');
    final isLatte = id.contains('latte');
    final isCappuccino = id.contains('cappuccino');
    final isNevado = id.contains('nevado');

    final mainColor = _getContrastColor(isEspresso, isLatte, isCappuccino, isNevado);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NeumorphismTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: NeumorphismTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPurchase,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Imagen real del café
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      _getCoffeeImage(isEspresso, isLatte, isCappuccino, isNevado),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        _getCoffeeIcon(isEspresso, isLatte, isCappuccino, isNevado),
                        color: mainColor,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Info del producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.title.split('(').first.trim().toUpperCase(),
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: mainColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: NeumorphismTheme.textSecondary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Badge de precio
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: mainColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          product.priceString,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: mainColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Flecha indicadora
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: mainColor.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCoffeeImage(bool isEspresso, bool isLatte, bool isCappuccino, bool isNevado) {
    if (isNevado) return 'assets/images/coffes/nevado.webp';
    if (isCappuccino) return 'assets/images/coffes/capuchino.webp';
    if (isLatte) return 'assets/images/coffes/late.webp';
    if (isEspresso) return 'assets/images/coffes/expreso.webp';
    return 'assets/images/coffes/expreso.webp';
  }

  IconData _getCoffeeIcon(bool isEspresso, bool isLatte, bool isCappuccino, bool isNevado) {
    if (isNevado) return Icons.ac_unit_rounded;
    if (isCappuccino) return Icons.local_fire_department_rounded;
    if (isLatte) return Icons.coffee_maker_rounded;
    return Icons.coffee_rounded;
  }

  Color _getContrastColor(bool isEspresso, bool isLatte, bool isCappuccino, bool isNevado) {
    if (isNevado) return const Color(0xFF4FC3F7); // Azul nevado más vibrante
    if (isCappuccino) return const Color(0xFFFFB300); // Dorado capuchino
    if (isLatte) return const Color(0xFF8D6E63); // Café latte
    return const Color(0xFF5D4037); // Café espresso oscuro
  }
}
