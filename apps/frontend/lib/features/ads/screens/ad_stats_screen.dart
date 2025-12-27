
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/ads_service.dart';
import '../models/audio_ad_model.dart';
import '../../../core/utils/logger.dart';
import '../providers/ads_provider.dart'; // To reuse service provider

// Private Provider for fetching all ads (Admin)
final _allAdsProvider = FutureProvider.autoDispose<List<AudioAd>>((ref) async {
  final service = ref.read(adsServiceProvider);
  // Important: This assumes the user is logged in as ADMIN.
  // The service handles the request, HttpClientService handles the token.
  return await service.getAllAds();
});

class AdStatsScreen extends ConsumerWidget {
  const AdStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(_allAdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas de Anuncios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(_allAdsProvider),
          ),
        ],
      ),
      body: adsAsync.when(
        data: (ads) {
          if (ads.isEmpty) {
            return const Center(child: Text('No hay anuncios registrados.'));
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Título')),
                  DataColumn(label: Text('Anunciante')),
                  DataColumn(label: Text('Plays'), numeric: true),
                  DataColumn(label: Text('Clicks'), numeric: true),
                  DataColumn(label: Text('CTR'), numeric: true),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: ads.map((ad) {
                  final ctr = ad.totalPlays > 0 
                      ? (ad.totalClicks / ad.totalPlays * 100).toStringAsFixed(1) 
                      : '0.0';
                      
                  return DataRow(cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ad.coverImageUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Image.network(
                                ad.coverImageUrl!,
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 30),
                              ),
                            ),
                          Text(ad.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    DataCell(Text(ad.advertiserName)),
                    DataCell(Text(ad.totalPlays.toString())),
                    DataCell(Text(ad.totalClicks.toString())),
                    DataCell(Text('$ctr%')),
                    DataCell(IconButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.blue),
                      tooltip: 'Ver Estadísticas',
                      onPressed: () {
                         _showAdDetails(context, ad, ref);
                      },
                    )),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Error al cargar estadísticas'),
              Text(err.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(_allAdsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdDetails(BuildContext context, AudioAd ad, WidgetRef ref) async {
    // Calculate CTR
    final ctr = ad.totalPlays > 0 
        ? (ad.totalClicks / ad.totalPlays * 100).toStringAsFixed(2) 
        : '0.00';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(ad.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow(Icons.person, 'Anunciante', ad.advertiserName),
            _buildStatRow(Icons.timer, 'Duración', '${ad.duration.inSeconds} segundos'),
            if (ad.isSkippable)
              _buildStatRow(Icons.skip_next, 'Skippable', 'Sí (tras ${ad.skipAfterSeconds}s)'),
            
            const Divider(height: 24),
            const Text('Rendimiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBigStat('Plays', ad.totalPlays.toString(), Colors.green),
                _buildBigStat('Clicks', ad.totalClicks.toString(), Colors.orange),
                _buildBigStat('CTR', '$ctr%', Colors.blue),
              ],
            ),
            
            if (ad.clickThroughUrl != null)
               Padding(
                 padding: const EdgeInsets.only(top: 16.0),
                 child: Text('URL: ${ad.clickThroughUrl}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
               ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildBigStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
