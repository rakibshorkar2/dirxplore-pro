import 'dart:math';
import '../services/dio_client.dart';

class TorrentSearchResult {
  final String title;
  final String magnet;
  final String size;
  final String seeds;
  final String peers;
  final String hash;
  final String provider;

  TorrentSearchResult({
    required this.title,
    required this.magnet,
    required this.size,
    required this.seeds,
    required this.peers,
    required this.hash,
    required this.provider,
  });
}

class TorrentService {
  static Future<List<TorrentSearchResult>> searchAll(String query,
      {bool useProxy = false}) async {
    if (query.isEmpty) return [];

    final results = await Future.wait([
      searchYTS(query, useProxy: useProxy),
      searchSolidTorrents(query, useProxy: useProxy),
      searchPirateBay(query, useProxy: useProxy),
    ]);

    // Flatten and sort by seeds (optional)
    final allResults = results.expand((x) => x).toList();
    allResults.sort((a, b) {
      final sA = int.tryParse(a.seeds) ?? 0;
      final sB = int.tryParse(b.seeds) ?? 0;
      return sB.compareTo(sA);
    });

    return allResults;
  }

  static Future<List<TorrentSearchResult>> searchYTS(String query,
      {bool useProxy = false}) async {
    if (query.isEmpty) return [];

    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://yts.mx/api/v2/list_movies.json',
        queryParameters: {'query_term': query, 'limit': 15},
      );

      if (response.data['status'] == 'ok' &&
          response.data['data']['movies'] != null) {
        final List movies = response.data['data']['movies'];
        final List<TorrentSearchResult> results = [];

        for (var movie in movies) {
          final title = movie['title_long'] ?? movie['title'];
          final torrents = movie['torrents'] as List?;

          if (torrents != null) {
            for (var t in torrents) {
              final hash = t['hash'];
              final magnet =
                  'magnet:?xt=urn:btih:$hash&dn=${Uri.encodeComponent(title)}';

              results.add(TorrentSearchResult(
                title: '$title (${t['quality']} ${t['type']})',
                magnet: magnet,
                size: t['size'],
                seeds: t['seeds'].toString(),
                peers: t['peers'].toString(),
                hash: hash,
                provider: 'YTS',
              ));
            }
          }
        }
        return results;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchSolidTorrents(String query,
      {bool useProxy = false}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://solidtorrents.to/api/v1/search',
        queryParameters: {'q': query, 'category': 'all', 'sort': 'seeders'},
      );

      if (response.data['results'] != null) {
        final List items = response.data['results'];
        return items.map((item) {
          return TorrentSearchResult(
            title: item['title'],
            magnet: item['magnet'],
            size: formatBytes(item['size']),
            seeds: item['swarm']['seeders'].toString(),
            peers: item['swarm']['leechers'].toString(),
            hash: item['infoHash'],
            provider: 'Solid',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TorrentSearchResult>> searchPirateBay(String query,
      {bool useProxy = false}) async {
    try {
      final dio = useProxy ? DioClient().dio : DioClient().cleanDio;
      final response = await dio.get(
        'https://apibay.org/q.php',
        queryParameters: {'q': query},
      );

      if (response.data is List) {
        final List items = response.data;
        // Filter out "No results" dummy item (id=0)
        return items.where((i) => i['id'] != '0').map((item) {
          final hash = item['info_hash'];
          final title = item['name'];
          final magnet =
              'magnet:?xt=urn:btih:$hash&dn=${Uri.encodeComponent(title)}';
          return TorrentSearchResult(
            title: title,
            magnet: magnet,
            size: formatBytes(int.tryParse(item['size'].toString()) ?? 0),
            seeds: item['seeders'].toString(),
            peers: item['leechers'].toString(),
            hash: hash,
            provider: 'PB',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }
}
