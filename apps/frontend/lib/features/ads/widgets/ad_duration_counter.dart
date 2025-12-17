import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../models/audio_ad_model.dart';

/// ✅ FASE 5: Contador de duración restante para anuncios no saltables
/// Muestra barra de progreso no interactiva y tiempo restante formateado
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
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final currentPosition = playbackState.currentPosition;
    // ✅ FIX: Usar duración del modelo AudioAd como fallback si totalDuration es cero
    final totalDuration = playbackState.totalDuration.inMilliseconds > 0 
        ? playbackState.totalDuration 
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Barra de progreso no interactiva (simple indicador de carga)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
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
          Align(
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
        ],
      ),
    );
  }
}
