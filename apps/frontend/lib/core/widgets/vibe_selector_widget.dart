import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/genre_model.dart';
import '../providers/search_provider.dart';
import '../providers/vibe_selector_provider.dart';
import '../theme/neumorphism_theme.dart';

/// 🎛️ VIBE SELECTOR WIDGET
/// 
/// Fila horizontal de chips para seleccionar el género/modo del autoplay infinito.
/// - "🔀 Mix" al principio: canciones aleatorias de cualquier género
/// - Géneros dinámicos desde la base de datos
/// - Cambio de rumbo limpia la cola y recarga
class VibeSelectorWidget extends ConsumerWidget {
  const VibeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(allGenresProvider);
    final selectedVibe = ref.watch(vibeSelectorProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: genresAsync.when(
        data: (genres) => _buildChipRow(context, ref, genres, selectedVibe),
        loading: () => _buildLoadingRow(),
        error: (_, __) => _buildChipRow(context, ref, [], selectedVibe), // Solo mostrar Mix
      ),
    );
  }

  Widget _buildChipRow(
    BuildContext context,
    WidgetRef ref,
    List<Genre> genres,
    VibeSelection selectedVibe,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 🔀 Chip "Mix" siempre al principio
          _VibeChip(
            label: '🔀 Mix',
            isSelected: selectedVibe.isMixMode,
            onTap: () {
              ref.read(vibeSelectorProvider.notifier).selectMixMode();
            },
          ),
          const SizedBox(width: 8),
          
          // Géneros dinámicos
          ...genres.map((genre) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _VibeChip(
              label: _getGenreEmoji(genre.name) + genre.name,
              isSelected: selectedVibe.genreId == genre.id,
              colorHex: genre.colorHex,
              onTap: () {
                ref.read(vibeSelectorProvider.notifier).selectGenre(genre);
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildLoadingRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Solo mostrar el chip Mix mientras carga
          _VibeChip(
            label: '🔀 Mix',
            isSelected: true,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          // Placeholders
          for (int i = 0; i < 3; i++) ...[
            Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// Asignar emoji según género
  String _getGenreEmoji(String genreName) {
    final name = genreName.toLowerCase();
    if (name.contains('pop')) return '🎤 ';
    if (name.contains('rock')) return '🎸 ';
    if (name.contains('hip') || name.contains('rap')) return '🎤 ';
    if (name.contains('electr') || name.contains('edm')) return '🎧 ';
    if (name.contains('jazz')) return '🎷 ';
    if (name.contains('clasic') || name.contains('classic')) return '🎻 ';
    if (name.contains('reggae')) return '🌴 ';
    if (name.contains('latin') || name.contains('salsa')) return '💃 ';
    if (name.contains('country')) return '🤠 ';
    if (name.contains('blues')) return '🎺 ';
    if (name.contains('r&b') || name.contains('soul')) return '🎙️ ';
    if (name.contains('metal')) return '🤘 ';
    if (name.contains('indie')) return '🎹 ';
    if (name.contains('folk')) return '🪕 ';
    if (name.contains('punk')) return '⚡ ';
    if (name.contains('reggaeton')) return '🔥 ';
    if (name.contains('trap')) return '💎 ';
    if (name.contains('ambient') || name.contains('chill')) return '🌙 ';
    return '🎵 '; // Default
  }
}

/// 🎨 Chip individual de vibe/género
class _VibeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final String? colorHex;
  final VoidCallback onTap;

  const _VibeChip({
    required this.label,
    required this.isSelected,
    this.colorHex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Color base del chip
    final baseColor = colorHex != null 
        ? _hexToColor(colorHex!) 
        : NeumorphismTheme.coffeeMedium;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // Fondo sutil
          color: isSelected 
              ? baseColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          // Borde brillante cuando está seleccionado
          border: Border.all(
            color: isSelected 
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          // Sombra sutil cuando está seleccionado
          boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}
