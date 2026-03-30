import 'package:flutter/material.dart';
import '../theme/neumorphism_theme.dart';

/// Un widget que maneja la carga diferida de una librería de Dart.
/// Utilizado para implementar Code Splitting (Deferred Loading).
class DeferredWidget extends StatefulWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;
  final Widget? placeholder;

  const DeferredWidget({
    super.key,
    required this.loader,
    required this.builder,
    this.placeholder,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  bool _isLoaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.loader();
      if (mounted) {
        setState(() {
          _isLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Error al cargar el módulo'),
              TextButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                  _load();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoaded) {
      return widget.placeholder ?? _DefaultPlaceholder();
    }

    return widget.builder();
  }
}

class _DefaultPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: NeumorphismTheme.backgroundGradient,
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(NeumorphismTheme.coffeeMedium),
          ),
        ),
      ),
    );
  }
}
