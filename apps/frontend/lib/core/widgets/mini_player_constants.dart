/// Constantes para el Mini Player
/// OPTIMIZACIÓN: Centralizar valores mágicos para fácil mantenimiento
class MiniPlayerConstants {
  // Sizes
  static const double albumCoverSize = 48.0;
  static const double progressBarHeight = 2.0;
  static const double buttonSize = 40.0;
  static const double iconSize = 20.0;
  static const double borderRadius = 4.0;
  
  // Padding & Spacing
  static const double horizontalPadding = 12.0;
  static const double verticalPadding = 8.0;
  static const double spacingBetweenElements = 12.0;
  static const double spacingBeforeButton = 8.0;
  static const double textSpacing = 2.0;
  
  // Animations
  static const Duration slideAnimationDuration = Duration(milliseconds: 300);
  static const Duration slideAnimationReverseDuration = Duration(milliseconds: 250);
  static const Duration progressAnimationDuration = Duration(milliseconds: 100);
  static const Duration iconAnimationDuration = Duration(milliseconds: 150);
  static const Duration streamDebounceDuration = Duration(milliseconds: 50);
  
  // Thresholds
  static const double progressChangeThreshold = 0.001;
  
  // Colors & Opacity
  static const double shadowOpacity = 0.08;
  static const double secondaryTextOpacity = 0.8;
  static const double backgroundProgressOpacity = 0.2;
}

