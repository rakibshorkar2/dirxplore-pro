enum TorrentStatus { downloading, seeding, paused, completed, error }

class TorrentItem {
  final String id;
  final String name;
  final String hash;
  final String magnetLink;
  final String savePath;
  TorrentStatus status;
  double progress;
  String size;
  String speed;
  DateTime addedAt;
  bool isSequential;

  TorrentItem({
    required this.id,
    required this.name,
    required this.hash,
    required this.magnetLink,
    required this.savePath,
    this.status = TorrentStatus.downloading,
    this.progress = 0.0,
    this.size = '0 B',
    this.speed = '0 KB/s',
    required this.addedAt,
    this.isSequential = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hash': hash,
      'magnetLink': magnetLink,
      'savePath': savePath,
      'status': status.index,
      'progress': progress,
      'size': size,
      'speed': speed,
      'addedAt': addedAt.toIso8601String(),
      'isSequential': isSequential ? 1 : 0,
    };
  }

  factory TorrentItem.fromJson(Map<String, dynamic> json) {
    return TorrentItem(
      id: json['id'],
      name: json['name'],
      hash: json['hash'],
      magnetLink: json['magnetLink'],
      savePath: json['savePath'],
      status: TorrentStatus.values[json['status'] ?? 0],
      progress: (json['progress'] ?? 0.0).toDouble(),
      size: json['size'] ?? '0 B',
      speed: json['speed'] ?? '0 KB/s',
      addedAt: DateTime.parse(json['addedAt']),
      isSequential: (json['isSequential'] ?? 0) == 1,
    );
  }
}
