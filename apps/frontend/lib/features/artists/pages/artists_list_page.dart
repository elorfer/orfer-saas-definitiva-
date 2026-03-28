import 'package:flutter/material.dart'; // ✅ Added back
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart'; // ✅ Added back
import '../models/artist.dart'; // ✅ Added back
import '../services/artists_api.dart'; // ✅ Added back
import '../widgets/artist_card.dart'; // ✅ Added back
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/providers/theme_provider.dart';

class ArtistsListPage extends ConsumerStatefulWidget {
  final ArtistsApi api;
  const ArtistsListPage({super.key, required this.api});

  @override
  ConsumerState<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends ConsumerState<ArtistsListPage> {
  List<ArtistLite> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getFeatured(limit: 24);
      setState(() => _items = list);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 Refresh UI on Theme Change
    ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: NeumorphismTheme.background,
      appBar: AppBar(
        systemOverlayStyle: NeumorphismTheme.isDark 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        backgroundColor: NeumorphismTheme.background,
        elevation: 0,
        title: Text(
          'Artistas',
          style: TextStyle(
            color: NeumorphismTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final a = _items[index];
                  return ArtistCard(
                    artist: a,
                    onTap: () {
                      // Usar go_router para navegación consistente
                      context.push('/artist/${a.id}', extra: a);
                    },
                  );
                },
              ),
            ),
    );
  }
}


