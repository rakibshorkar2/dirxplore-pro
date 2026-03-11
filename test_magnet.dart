import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter/foundation.dart';

void main() async {
  try {
    var magnet =
        'magnet:?xt=urn:btih:d123456789012345678901234567890123456789&dn=test&tr=udp://tracker.openbittorrent.com:80';
    // Note: To parse a magnet properly for TorrentModel, we usually need the metadata or use MagnetParser
    final magnetData = MagnetParser.parse(magnet);
    if (magnetData != null) {
      debugPrint('Parsed Magnet: \${magnetData.name}');
      debugPrint('Hash: \${magnetData.infoHashString}');
    }
  } catch (e) {
    debugPrint('Error: \$e');
  }
}
