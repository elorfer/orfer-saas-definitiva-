import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playback_notifier.dart';

/// 🔮 Widget que muestra indicador "Generando más música..."
/// Se muestra cuando el sistema está buscando nuevas canciones para el autoplay infinito
class GeneratingMusicIndicator extends ConsumerWidget {
  const GeneratingMusicIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGenerating = ref.watch(
      playbackNotifierProviderFactory.select((state) => state.isGeneratingMusic),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
        return SlideTransition(position: offset, child: child);
      },
      child: isGenerating
          ? Container(
              key: const ValueKey('generating'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Generando más música...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }
}

/// 🔮 Widget más compacto para el mini player
class GeneratingMusicIndicatorCompact extends ConsumerWidget {
  const GeneratingMusicIndicatorCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGenerating = ref.watch(
      playbackNotifierProviderFactory.select((state) => state.isGeneratingMusic),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
        return SlideTransition(position: offset, child: child);
      },
      child: isGenerating
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cargando...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
              : const SizedBox.shrink(),
    );
  }
}
