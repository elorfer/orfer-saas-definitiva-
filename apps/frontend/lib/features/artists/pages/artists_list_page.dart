import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/artist.dart';
import '../services/artists_api.dart';
import '../widgets/artist_card.dart';

class ArtistsListPage extends StatefulWidget {
  final ArtistsApi api;
  const ArtistsListPage({super.key, required this.api});

  @override
  State<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends State<ArtistsListPage> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Artistas')),
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


