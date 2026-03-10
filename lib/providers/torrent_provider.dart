import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/torrent_item.dart';
import '../services/database_helper.dart';

class TorrentProvider with ChangeNotifier {
  final List<TorrentItem> _torrents = [];
  bool _isInitialized = false;

  List<TorrentItem> get torrents => _torrents;
  final List<String> _rssFeeds = [];
  List<String> get rssFeeds => _rssFeeds;

  double _downloadLimit = 0; // 0 = Unlimited
  double _uploadLimit = 0;

  void setLimits(double dl, double ul) {
    _downloadLimit = dl;
    _uploadLimit = ul;
    notifyListeners();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    final data = await DatabaseHelper().getTorrents();
    _torrents.clear();
    _torrents.addAll(data.map((json) => TorrentItem.fromJson(json)));
    _isInitialized = true;
    notifyListeners();
    _startSimulator();
  }

  Future<void> addTorrent(String name, String magnet, String savePath, String size, {bool isSequential = false}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = _extractHash(magnet);
    
    final newItem = TorrentItem(
      id: id,
      name: name,
      hash: hash,
      magnetLink: magnet,
      savePath: savePath,
      size: size,
      status: TorrentStatus.downloading,
      addedAt: DateTime.now(),
      isSequential: isSequential,
    );

    _torrents.insert(0, newItem);
    await DatabaseHelper().insertTorrent(newItem.toJson());
    notifyListeners();
  }

  String _extractHash(String magnet) {
    // Basic extraction magnet:?xt=urn:btih:HASH
    final xtMatch = RegExp(r'xt=urn:btih:([^&]+)').firstMatch(magnet);
    return xtMatch?.group(1) ?? 'unknown';
  }

  void pauseTorrent(String id) {
    final index = _torrents.indexWhere((t) => t.id == id);
    if (index != -1) {
      _torrents[index].status = TorrentStatus.paused;
      _torrents[index].speed = '0 KB/s';
      DatabaseHelper().updateTorrent(_torrents[index].toJson());
      notifyListeners();
    }
  }

  void resumeTorrent(String id) {
    final index = _torrents.indexWhere((t) => t.id == id);
    if (index != -1) {
      _torrents[index].status = TorrentStatus.downloading;
      DatabaseHelper().updateTorrent(_torrents[index].toJson());
      notifyListeners();
    }
  }

  void deleteTorrent(String id) {
    _torrents.removeWhere((t) => t.id == id);
    DatabaseHelper().deleteTorrent(id);
    notifyListeners();
  }

  void addRSSFeed(String url) {
    if (!_rssFeeds.contains(url)) {
      _rssFeeds.add(url);
      notifyListeners();
    }
  }

  void removeRSSFeed(String url) {
    _rssFeeds.remove(url);
    notifyListeners();
  }

  Future<void> refreshRSSFeeds() async {
    // Simulation: Add a random torrent when refreshing
    if (_rssFeeds.isNotEmpty) {
      await addTorrent(
        'RSS Released Movie ${DateTime.now().second}',
        'magnet:?xt=urn:btih:rssMock${DateTime.now().millisecondsSinceEpoch}',
        '/storage/emulated/0/Download',
        '2.4 GB',
      );
    }
  }

  // Simulator for "Real Download System" feel without a native library
  Timer? _timer;
  void _startSimulator() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool changed = false;
      for (var t in _torrents) {
        if (t.status == TorrentStatus.downloading && t.progress < 1.0) {
          // Simulate progress increment based on speed
          double currentSpeedMB = 1 + (t.id.hashCode % 10);
          
          if (_downloadLimit > 0 && currentSpeedMB > _downloadLimit) {
            currentSpeedMB = _downloadLimit;
          }

          t.progress += (currentSpeedMB * 0.001); // Simplified conversion
          if (t.progress >= 1.0) {
            t.progress = 1.0;
            t.status = TorrentStatus.completed;
            t.speed = '0 KB/s';
          } else {
            t.speed = '${currentSpeedMB.toStringAsFixed(1)} MB/s';
          }
          changed = true;
          // Periodically save to DB every 10%
          if ((t.progress * 100).toInt() % 10 == 0) {
             DatabaseHelper().updateTorrent(t.toJson());
          }
        }
      }
      if (changed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
