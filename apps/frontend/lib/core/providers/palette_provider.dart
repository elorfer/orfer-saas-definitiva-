import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

/// Provider para extraer el color dominante de una imagen (Caché en memoria)
final imagePaletteProvider = FutureProvider.family<Color, String>((ref, imageUrl) async {
  if (imageUrl.isEmpty) return Colors.grey;
  
  try {
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(imageUrl),
      maximumColorCount: 5,
    );
    return paletteGenerator.dominantColor?.color ?? Colors.grey;
  } catch (e) {
    return Colors.grey;
  }
});

/// Extensión para manejar Shimmer colorido (Opcional en V2)
class PaletteIndicator extends ConsumerWidget {
  final String imageUrl;
  final Widget child;

  const PaletteIndicator({super.key, required this.imageUrl, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paletteColor = ref.watch(imagePaletteProvider(imageUrl));
    
    return paletteColor.when(
      data: (color) => child, // Aquí se podría aplicar el color al Shimmer
      loading: () => child,
      error: (_, _) => child,
    );
  }
}
