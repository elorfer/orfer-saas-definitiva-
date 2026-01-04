import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/playback_notifier.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../models/audio_ad_model.dart';

/// Botón de skip para anuncios con countdown
/// ✅ FIX: Usa el tiempo de reproducción real del estado para sincronización perfecta
class AdsSkipButton extends ConsumerWidget {
  final AudioAd ad;

  const AdsSkipButton({
    super.key,
    required this.ad,
  });

  Future<void> _handleSkip(WidgetRef ref) async {
    try {
      final playbackNotifier = ref.read(playbackNotifierProvider.notifier);
      await playbackNotifier.skipAd();
    } catch (e) {
      // Error ya manejado en el notifier
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ FIX: Usar la posición real del audio para sincronizar con los demás widgets
    final playbackState = ref.watch(playbackNotifierProvider);
    final currentPositionSeconds = playbackState.currentPosition.inSeconds;
    
    // Calcular segundos restantes basado en la posición real del audio
    final skipAfterSeconds = ad.skipAfterSeconds;
    final remainingSeconds = (skipAfterSeconds - currentPositionSeconds).clamp(0, skipAfterSeconds);
    final canSkip = currentPositionSeconds >= skipAfterSeconds;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canSkip ? () => _handleSkip(ref) : null,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: canSkip
                ? NeumorphismTheme.coffeeMedium
                : NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(
              color: NeumorphismTheme.coffeeDark.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.skip_next,
                size: 16,
                color: canSkip ? Colors.white : NeumorphismTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                canSkip ? 'Saltar' : '$remainingSeconds',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: canSkip ? Colors.white : NeumorphismTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
