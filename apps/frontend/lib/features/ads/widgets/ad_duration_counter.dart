import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../models/audio_ad_model.dart';

/// ✅ FASE 5: Contador de duración restante para anuncios
/// ✅ SOLUCIÓN PROFESIONAL: Usa AnimationController para interpolación ultra-suave
/// La barra avanza de forma fluida sin saltos ni retrocesos
class AdDurationCounter extends ConsumerStatefulWidget {
  final AudioAd ad;

  const AdDurationCounter({
    super.key,
    required this.ad,
  });

  @override
  ConsumerState<AdDurationCounter> createState() => _AdDurationCounterState();
}

class _AdDurationCounterState extends ConsumerState<AdDurationCounter> {
  // ✅ ANTI-RETROCESO: Progreso máximo alcanzado
  double _maxProgress = 0.0;
  
  @override
  void didUpdateWidget(AdDurationCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambió el anuncio, resetear todo
    if (oldWidget.ad.id != widget.ad.id) {
      _maxProgress = 0.0;
    }
  }

  String _formatRemainingTime(Duration remaining) {
    final totalSeconds = remaining.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '-$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _updateProgress(double newProgress) {
    // ✅ ANTI-RETROCESO: Solo aceptar progreso mayor o igual
    if (newProgress < _maxProgress - 0.01) {
      // Ignorar retrocesos significativos (tolerancia de 1%)
      return;
    }
    
    // Actualizar máximo
    if (newProgress > _maxProgress) {
      _maxProgress = newProgress;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observar posición y duración
    final currentPosition = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentPosition),
    );
    final totalDurationFromState = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.totalDuration),
    );
    
    // Usar duración del modelo AudioAd como fallback
    final totalDuration = totalDurationFromState.inMilliseconds > 0 
        ? totalDurationFromState 
        : widget.ad.duration;

    // Calcular progreso actual
    final totalMilliseconds = totalDuration.inMilliseconds;
    final timeElapsed = currentPosition.inMilliseconds;
    final currentProgress = totalMilliseconds > 0 
        ? (timeElapsed / totalMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    
    // Actualizar el controlador de animación
    _updateProgress(currentProgress);
    
    // Calcular tiempo restante basado en progreso real (no animado)
    final remainingMs = (totalMilliseconds - timeElapsed).clamp(0, totalMilliseconds);
    final remaining = Duration(milliseconds: remainingMs);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // ✅ FIX CRÍTICO: Eliminar TweenAnimationBuilder
            // El rebuild a 20 FPS del stream ya lo hace lo suficientemente suave
            // Eliminar esto evita la creación de cientos de animaciones encoladas por segundo que bloquean el UI.
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                value: _maxProgress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
            
            const SizedBox(height: 8.0),

            // Contador de tiempo restante
            RepaintBoundary(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatRemainingTime(remaining),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
