import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../models/audio_ad_model.dart';

/// ✅ FASE 5: Contador de duración restante para anuncios no saltables
/// Muestra barra de progreso no interactiva y tiempo restante formateado
/// ✅ OPTIMIZADO: Usa select() para reducir reconstrucciones y RepaintBoundary para mejor rendimiento
class AdDurationCounter extends ConsumerWidget {
  final AudioAd ad;

  const AdDurationCounter({
    super.key,
    required this.ad,
  });

  String _formatRemainingTime(Duration remaining) {
    final totalSeconds = remaining.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    // Formato: -0:15 (con signo negativo, sin padding en minutos para formato más limpio)
    return '-$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ OPTIMIZACIÓN CRÍTICA: Usar select() para observar solo currentPosition y totalDuration
    // Esto previene reconstrucciones innecesarias que causan que la barra se detenga o salte
    final currentPosition = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.currentPosition),
    );
    final totalDurationFromState = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.totalDuration),
    );
    
    // ✅ FIX: Usar duración del modelo AudioAd como fallback si totalDuration es cero
    final totalDuration = totalDurationFromState.inMilliseconds > 0 
        ? totalDurationFromState 
        : ad.duration;

    // Calcular tiempo restante
    final timeElapsed = currentPosition.inMilliseconds;
    final totalMilliseconds = totalDuration.inMilliseconds;
    final remainingMs = (totalMilliseconds - timeElapsed).clamp(0, totalMilliseconds);
    final remaining = Duration(milliseconds: remainingMs);
    
    // Calcular progreso para la barra
    final progress = totalMilliseconds > 0 
        ? (timeElapsed / totalMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // ✅ OPTIMIZACIÓN: Usar RepaintBoundary para aislar repintados y mejorar fluidez
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Barra de progreso no interactiva (simple indicador de carga)
            // ✅ OPTIMIZACIÓN: ClipRRect evita repintados fuera de los bordes
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
            
            const SizedBox(height: 8.0),

            // Contador de tiempo restante (alineado a la derecha)
            // Formato: -0:15 (según guía Fase 5)
            // ✅ OPTIMIZACIÓN: RepaintBoundary adicional para el texto
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
