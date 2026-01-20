import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/playback_notifier.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../models/audio_ad_model.dart';

/// Botón de skip para anuncios con countdown
/// ✅ FIX: Usa el tiempo de reproducción real del estado para sincronización perfecta
/// ✅ PROTECCIÓN: Evita doble click con debounce
class AdsSkipButton extends ConsumerStatefulWidget {
  final AudioAd ad;

  const AdsSkipButton({
    super.key,
    required this.ad,
  });

  @override
  ConsumerState<AdsSkipButton> createState() => _AdsSkipButtonState();
}

class _AdsSkipButtonState extends ConsumerState<AdsSkipButton> {
  bool _isSkipping = false;

  Future<void> _handleSkip() async {
    // 🛡️ PROTECCIÓN DOBLE CLICK: Si ya está saltando, ignorar
    if (_isSkipping) return;
    
    setState(() => _isSkipping = true);
    
    try {
      final playbackNotifier = ref.read(playbackNotifierProvider.notifier);
      await playbackNotifier.skipAd();
    } catch (e) {
      // Error ya manejado en el notifier
    } finally {
      // Resetear el flag después de un delay (debounce)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _isSkipping = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Usar la posición real del audio para sincronizar con los demás widgets
    final playbackState = ref.watch(playbackNotifierProvider);
    final currentPositionSeconds = playbackState.currentPosition.inSeconds;
    
    // Calcular segundos restantes basado en la posición real del audio
    final skipAfterSeconds = widget.ad.skipAfterSeconds;
    final remainingSeconds = (skipAfterSeconds - currentPositionSeconds).clamp(0, skipAfterSeconds);
    final canSkip = currentPositionSeconds >= skipAfterSeconds && !_isSkipping;

    // 🌓 ADAPTACIÓN AL TEMA: Colores dinámicos según modo oscuro/claro
    final buttonColor = canSkip
        ? NeumorphismTheme.accent
        : NeumorphismTheme.accent.withValues(alpha: 0.3);
    final borderColor = NeumorphismTheme.accentDark.withValues(alpha: 0.3);
    final iconColor = canSkip 
        ? (NeumorphismTheme.isDark ? Colors.white : NeumorphismTheme.textPrimary)
        : NeumorphismTheme.textSecondary;
    final textColor = canSkip 
        ? (NeumorphismTheme.isDark ? Colors.white : NeumorphismTheme.textPrimary)
        : NeumorphismTheme.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canSkip ? _handleSkip : null,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mostrar spinner si está saltando
              if (_isSkipping)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                )
              else
                Icon(
                  Icons.skip_next,
                  size: 16,
                  color: iconColor,
                ),
              const SizedBox(width: 4),
              Text(
                _isSkipping 
                    ? 'Saltando...' 
                    : (canSkip ? 'Saltar' : '$remainingSeconds'),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
