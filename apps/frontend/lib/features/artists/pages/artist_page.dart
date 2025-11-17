import 'package:flutter/material.dart';
import '../../../core/config/api_config.dart';
import '../../../core/models/song_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../artists/services/artists_api.dart';
import '../models/artist.dart';
import '../../../core/utils/url_normalizer.dart';

class ArtistPage extends ConsumerStatefulWidget {
  final ArtistLite artist;
  const ArtistPage({super.key, required this.artist});

  @override
  ConsumerState<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends ConsumerState<ArtistPage> {
  late final ArtistsApi _api;
  Map<String, dynamic>? _details;
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = ArtistsApi(ApiConfig.baseUrl);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final details = await _api.getById(widget.artist.id);
      final songsRaw = await _api.getSongsByArtist(widget.artist.id, limit: 50);
      final songs = songsRaw.map((e) => Song.fromJson(e)).toList();
      setState(() {
        _details = details;
        _songs = songs;
      });
    } catch (_) {
      setState(() {
        _details = null;
        _songs = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final bool isAdmin = currentUser?.isAdmin == true;

    final artist = widget.artist;
    // Datos efectivos: primero los del detalle, luego los del lite
    final effectiveName = (_details?['name'] as String?) ?? artist.name;
    final detailCover = _details?['coverPhotoUrl'] as String? ?? _details?['cover_photo_url'] as String?;
    final detailProfile = _details?['profilePhotoUrl'] as String? ?? _details?['profile_photo_url'] as String?;
    final coverUrl = UrlNormalizer.normalizeImageUrl(detailCover ?? artist.coverPhotoUrl);
    final profileUrl = UrlNormalizer.normalizeImageUrl(detailProfile ?? artist.profilePhotoUrl);
    final rawBio = ((_details?['biography'] as String?) ?? (_details?['bio'] as String?))?.trim();
    final nationality = ((_details?['nationalityCode'] as String?) ?? (_details?['nationality_code'] as String?) ?? artist.nationalityCode)?.toUpperCase();
    final social = (_details?['socialLinks'] as Map<String, dynamic>?) ?? (_details?['social_links'] as Map<String, dynamic>?) ?? const {};
    final String? phone = (social['phone'] as String?)?.trim();

    final String bio = _sanitizeBio(rawBio, isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text(effectiveName),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera con portada y overlay
                AspectRatio(
                  aspectRatio: 2.4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      coverUrl != null && coverUrl.isNotEmpty
                          ? Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                            )
                          : Container(color: Colors.grey.shade300),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Avatar superpuesto y nombre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -24),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: (profileUrl != null && profileUrl.isNotEmpty)
                                ? Image.network(
                                    profileUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.person, color: Colors.grey),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey.shade300,
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.person, color: Colors.grey),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    effectiveName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (nationality != null) ...[
                                  const SizedBox(width: 8),
                                  Text(_flagEmoji(nationality), style: const TextStyle(fontSize: 22)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                  const SizedBox(height: 12),
                ],
                if (bio.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Biografía', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      bio,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Biografía', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Sin biografía', style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ),
                  const SizedBox(height: 12),
                ],

                if (isAdmin && phone != null && phone.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Contacto', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(phone, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text('Canciones', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_songs.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Row(
                      children: const [
                        Icon(Icons.music_off, color: Colors.black45),
                        SizedBox(width: 8),
                        Text('Este artista aún no tiene canciones subidas', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ] else ...[
                  // Lista de canciones estilo profesional
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      itemCount: _songs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, endIndent: 16),
                      itemBuilder: (context, index) => _buildSongRow(index, _songs[index], effectiveName),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _flagEmoji(String code) {
    if (code.length != 2) return '🏳️';
    final cc = code.toUpperCase();
    final runes = cc.runes.map((c) => 0x1F1E6 - 65 + c).toList();
    return String.fromCharCodes(runes);
  }


  String _sanitizeBio(String? bio, bool isAdmin) {
    if (bio == null || bio.trim().isEmpty) return '';
    if (isAdmin) return bio.trim();
    // Ocultar posibles líneas de teléfono para usuarios no admin
    final lines = bio.split('\n');
    final filtered = lines.where((line) {
      final l = line.toLowerCase().trim();
      final hasTelWord = l.startsWith('tel') || l.contains('tel:');
      final hasManyDigits = RegExp(r'(?:\+?\d[\s-]?){8,}').hasMatch(l);
      return !(hasTelWord || hasManyDigits);
    }).toList();
    return filtered.join('\n').trim();
  }

  Widget _buildSongRow(int index, Song s, String artistName) {
    final songCover = UrlNormalizer.normalizeImageUrl(s.coverArtUrl);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (songCover != null && songCover.isNotEmpty)
                ? Image.network(
                    songCover,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.music_note, size: 20, color: Colors.grey),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.music_note, size: 20, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (s.title ?? 'Sin título'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            s.durationFormatted,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF667eea)),
            onPressed: () {},
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}


