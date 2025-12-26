import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/playback_notifier.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../models/audio_ad_model.dart';

/// Botón de skip para anuncios con countdown
/// Solo se muestra cuando el anuncio es skippable y ha pasado el tiempo mínimo
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
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _canSkip = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.ad.skipAfterSeconds;
    _startCountdown();
  }

  @override
  void didUpdateWidget(AdsSkipButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ FIX: Si cambió el anuncio, resetear el countdown
    if (oldWidget.ad.id != widget.ad.id || 
        oldWidget.ad.skipAfterSeconds != widget.ad.skipAfterSeconds) {
      _countdownTimer?.cancel();
      _remainingSeconds = widget.ad.skipAfterSeconds;
      _canSkip = _remainingSeconds <= 0;
      if (_canSkip) {
        // Ya se puede saltar, no iniciar timer
        return;
      }
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (_remainingSeconds <= 0) {
      setState(() {
        _canSkip = true;
      });
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _canSkip = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSkip() async {
    if (!_canSkip) return;

    try {
      final playbackNotifier = ref.read(playbackNotifierProviderFactory.notifier);
      await playbackNotifier.skipAd();
    } catch (e) {
      // Error ya manejado en el notifier
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _canSkip ? _handleSkip : null,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _canSkip
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
                color: _canSkip ? Colors.white : NeumorphismTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _canSkip ? 'Saltar' : '$_remainingSeconds',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _canSkip ? Colors.white : NeumorphismTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
