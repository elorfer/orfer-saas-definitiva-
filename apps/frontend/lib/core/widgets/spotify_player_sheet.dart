import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unified_audio_provider_fixed.dart';
import '../theme/neumorphism_theme.dart';
import '../widgets/final_mini_player.dart';
import '../widgets/professional_audio_player.dart';
import '../../features/ads/widgets/ads_mini_player.dart';

/// 🎵 SPOTIFY-STYLE DRAG-TO-EXPAND PLAYER SHEET
/// 
/// Replaces the old navigation-based approach.
/// This widget lives permanently in the widget tree as an overlay.
/// The user drags UP to expand to full player, drags DOWN to collapse.
/// The animation is driven in real-time by the drag gesture.
class SpotifyPlayerSheet extends ConsumerStatefulWidget {
  const SpotifyPlayerSheet({super.key});

  @override
  ConsumerState<SpotifyPlayerSheet> createState() => _SpotifyPlayerSheetState();
}

class _SpotifyPlayerSheetState extends ConsumerState<SpotifyPlayerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Track drag state
  bool _isDragging = false;

  static const double _miniPlayerHeight = 84.0;
  static const double _miniPlayerBottomMargin = 80.0; // above navigation bar

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 280),
    );

    // Listen to expansion state from provider and animate accordingly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(
        unifiedAudioProviderFixed.select((s) => s.isPlayerExpanded),
        (_, isExpanded) {
          if (!mounted) return;
          if (isExpanded && _controller.value < 1.0 && !_isDragging) {
            _controller.animateTo(1.0, curve: Curves.easeOutCubic);
          } else if (!isExpanded && _controller.value > 0.0 && !_isDragging) {
            _controller.animateTo(0.0, curve: Curves.easeInCubic);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Calculate how much to update controller based on delta
    final delta = -details.delta.dy / screenHeight;
    _controller.value = (_controller.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;

    // velocity < 0 = swipe UP (open), velocity > 0 = swipe DOWN (close)
    if (velocity < -500) {
      // Fast swipe up: expand
      _expandPlayer();
    } else if (velocity > 500) {
      // Fast swipe down: collapse
      _collapsePlayer();
    } else if (_controller.value > 0.5) {
      // Past halfway: expand
      _expandPlayer();
    } else {
      // Before halfway: collapse
      _collapsePlayer();
    }
  }

  void _expandPlayer({bool instant = false}) {
    HapticFeedback.lightImpact();
    if (instant) {
      _controller.value = 1.0;
    } else {
      _controller.animateTo(1.0, curve: Curves.easeOutCubic);
    }
    ref.read(unifiedAudioProviderFixed.notifier).openFullPlayer();
  }

  void _collapsePlayer({bool instant = false}) {
    if (instant) {
      _controller.value = 0.0;
      ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
    } else {
      _controller.animateTo(0.0, curve: Curves.easeInCubic).then((_) {
        if (mounted) {
          ref.read(unifiedAudioProviderFixed.notifier).closeFullPlayer();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final currentSong = playbackState.currentSong;
    final isPlayingAd = playbackState.isPlayingAd;
    final hasContent = currentSong != null || isPlayingAd ||
        playbackState.currentAd != null || playbackState.isInsertingAd;
    final isSessionActive = playbackState.isSessionActive;

    // If nothing to show, return empty
    if (!hasContent || !isSessionActive) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // Interpolated values
        final height = lerpDouble(_miniPlayerHeight, screenHeight, t)!;
        final width = lerpDouble(screenWidth - 24.0, screenWidth, t)!;
        
        // ✅ MEJORA: El margen inferior ahora incluye el safe area para evitar solapamiento con la navbar
        // Aumentamos el margen base de 80 a 90 para que flote un poco más alto
        final baseMargin = 90.0 + bottomPadding;
        final bottomInset = lerpDouble(baseMargin, 0.0, t)!;
        
        final leftInset = lerpDouble(12.0, 0.0, t)!;
        final rightInset = lerpDouble(12.0, 0.0, t)!;
        final borderRadius = lerpDouble(32.0, 0.0, t)!;

        // Cross-fade between mini and full content
        // ✅ FIX PARPADEO: Las dos fades se solapan entre t=0.2 y t=0.55
        // El mini sale: de 1.0 → 0.0 entre t=0 y t=0.55
        // El full entra: de 0.0 → 1.0 entre t=0.2 y t=0.75
        // Nunca hay un instante donde los dos sean invisibles al mismo tiempo.
        final miniOpacity = (1.0 - t / 0.55).clamp(0.0, 1.0);
        final fullOpacity = ((t - 0.2) / 0.55).clamp(0.0, 1.0);

        return Positioned(
          bottom: bottomInset,
          left: leftInset,
          right: rightInset,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent, // Captura gestos en toda el área, incluso encima de botones
            // All drag handlers
            onVerticalDragStart: (_) { _isDragging = true; },
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            // Tap on mini-player: opens INSTANTLY (no transition)
            onTap: t < 0.5
                ? () {
                    HapticFeedback.lightImpact();
                    _expandPlayer(instant: true);
                  }
                : null,
            child: RepaintBoundary(
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: NeumorphismTheme.background,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2 + t * 0.15),
                      blurRadius: 20 + t * 10,
                      offset: const Offset(0, -4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Stack(
                    children: [
                      // ── MINI PLAYER CONTENT ──────────────────────────────────
                      if (miniOpacity > 0)
                        Opacity(
                          opacity: miniOpacity,
                          child: Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              height: _miniPlayerHeight,
                              child: isPlayingAd && playbackState.currentAd != null
                                  ? AdsMiniPlayer(
                                      key: const ValueKey('sheet_ads_mini'),
                                      onTap: () => _expandPlayer(instant: true),
                                    )
                                  : FinalMiniPlayer(
                                      key: const ValueKey('sheet_song_mini'),
                                      onTap: () => _expandPlayer(instant: true),
                                    ),
                            ),
                          ),
                        ),

                      // ── FULL PLAYER CONTENT ──────────────────────────────────
                      if (fullOpacity > 0)
                        Opacity(
                          opacity: fullOpacity,
                          child: SizedBox.expand(
                            child: Stack(
                              children: [
                                // Full player
                                const ProfessionalAudioPlayer(),

                                // Close button (arrow down)
                                Positioned(
                                  top: MediaQuery.of(context).padding.top + 8,
                                  left: 16,
                                  child: RepaintBoundary(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _collapsePlayer(instant: true);
                                      },
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          borderRadius:
                                              const BorderRadius.all(Radius.circular(20)),
                                        ),
                                        child: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── DRAG HANDLE (mini mode only) ─────────────────────────
                      if (miniOpacity > 0.3)
                        Opacity(
                          opacity: miniOpacity,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: NeumorphismTheme.textSecondary
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper for linear interpolation (from dart:ui but exported here for clarity)
double? lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
