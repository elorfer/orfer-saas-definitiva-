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

class _AdDurationCounterState extends ConsumerState<AdDurationCounter>
    with SingleTickerProviderStateMixin {
  
  // ✅ PROFESIONAL: AnimationController para interpolación suave
  late AnimationController _progressController;
  double _targetProgress = 0.0;
  double _displayedProgress = 0.0;
  
  // ✅ ANTI-RETROCESO: Progreso máximo alcanzado
  double _maxProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    // Duración corta para interpolación rápida pero suave
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _progressController.addListener(() {
      if (mounted) {
        setState(() {
          _displayedProgress = _progressController.value * _targetProgress;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AdDurationCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambió el anuncio, resetear todo
    if (oldWidget.ad.id != widget.ad.id) {
      _maxProgress = 0.0;
      _targetProgress = 0.0;
      _displayedProgress = 0.0;
      _progressController.reset();
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
    
    // ✅ PROFESIONAL: Interpolar suavemente hacia el nuevo valor
    _targetProgress = _maxProgress;
    
    // Solo animar si hay cambio significativo
    if ((_targetProgress - _displayedProgress).abs() > 0.001) {
      _progressController.forward(from: _displayedProgress / _maxProgress.clamp(0.001, 1.0));
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
            // ✅ Barra de progreso ultra-suave
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: TweenAnimationBuilder<double>(
                // ✅ PROFESIONAL: TweenAnimationBuilder para transiciones automáticas
                tween: Tween<double>(begin: _displayedProgress, end: _maxProgress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  );
                },
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
