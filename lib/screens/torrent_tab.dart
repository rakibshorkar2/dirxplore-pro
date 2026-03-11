import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/app_state.dart';
import '../providers/torrent_provider.dart';
import '../models/torrent_item.dart';
import '../services/torrent_service.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'media_player_screen.dart';

class TorrentTab extends StatefulWidget {
  const TorrentTab({super.key});

  @override
  State<TorrentTab> createState() => _TorrentTabState();
}

class _TorrentTabState extends State<TorrentTab> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<TorrentSearchResult> _searchResults = [];
  bool _isLoadingSearch = false;
  String _sortBy = 'seeds'; // 'seeds', 'size', 'name'
  Timer? _clipboardTimer;
  String _lastClipboard = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClipboardMonitor();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipboardTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  void _startClipboardMonitor() {
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkClipboard();
    });
  }

  Future<void> _checkClipboard() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.monitorClipboardMagnet) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty || text == _lastClipboard) return;

      if (text.startsWith('magnet:?xt=urn:btih:')) {
        _lastClipboard = text;
        if (mounted) {
          _showMagnetDetectedDialog(text);
        }
      }
    } catch (_) {}
  }

  void _showMagnetDetectedDialog(String magnet) {
    if (magnet == _lastClipboard &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      // Already handled or not on screen
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.blue),
            SizedBox(width: 8),
            Text('Magnet Link Detected'),
          ],
        ),
        content: const Text(
            'A magnet link was found in your clipboard. Would you like to add it?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Ignore')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleNewTorrent(context, 'New Torrent', magnet, 'Unknown');
            },
            child: const Text('Add Torrent'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final torrentProvider = context.watch<TorrentProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Torrents'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            _buildStatusIcon(
              context,
              Icons.vpn_lock,
              'VPN Active',
              Colors.green,
            ),
            _buildStatusIcon(
              context,
              appState.torrentWifiOnly ? Icons.wifi : Icons.signal_cellular_alt,
              appState.torrentWifiOnly ? 'Wi-Fi Only' : 'All Networks',
              appState.torrentWifiOnly ? Colors.blue : Colors.orange,
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Search', icon: Icon(Icons.search, size: 20)),
              Tab(text: 'Active Sessions', icon: Icon(Icons.downloading, size: 20)),
            ],
            isScrollable: true,
            indicatorColor: Colors.blue,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
            dividerColor: Colors.transparent,
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: appState.trueAmoledDark &&
                          Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : null,
                  gradient: appState.trueAmoledDark &&
                          Theme.of(context).brightness == Brightness.dark
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surface,
                            Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.8),
                          ],
                        ),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(
                    height: MediaQuery.of(context).padding.top +
                        kToolbarHeight +
                        48), // +48 for TabBar
                Expanded(
                  child: TabBarView(
                    children: [
                      // Search Tab
                      _buildSearchTab(context, appState),
                      // Active Tab (Renamed Sessions)
                      _buildActiveTab(torrentProvider),
                    ],
                  ),
                ),
              ],
            ),
            // Blurred Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: MediaQuery.of(context).padding.top +
                        kToolbarHeight +
                        48,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.8),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: FloatingActionButton.extended(
            onPressed: () => _showAddTorrentDialog(context),
            icon: const Icon(Icons.link),
            label: const Text('Add Link'),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab(BuildContext context, AppState appState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: _buildSearchBar(context, appState),
        ),
        if (_searchResults.isNotEmpty) _buildSortHeader(),
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSortHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Text('Sort by: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          _sortChip('Seeds', 'seeds'),
          _sortChip('Size', 'size'),
          _sortChip('Name', 'name'),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String key) {
    final isSelected = _sortBy == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() {
              _sortBy = key;
              _sortResults();
            });
          }
        },
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _sortResults() {
    if (_searchResults.isEmpty) return;
    setState(() {
      if (_sortBy == 'seeds') {
        _searchResults.sort((a, b) => (int.tryParse(b.seeds) ?? 0)
            .compareTo(int.tryParse(a.seeds) ?? 0));
      } else if (_sortBy == 'size') {
        _searchResults.sort((a, b) => b.size.compareTo(a.size)); // Note: Basic string sort for size
      } else if (_sortBy == 'name') {
        _searchResults.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
    });
  }

  Widget _buildActiveTab(TorrentProvider provider) {
    final activeList = provider.torrents
        .where((t) =>
            t.status != TorrentStatus.completed &&
            t.status != TorrentStatus.error)
        .toList();

    if (activeList.isEmpty) {
      return _buildEmptyState('No active downloads', Icons.downloading);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: activeList.length,
      itemBuilder: (context, index) {
        return _buildTorrentItem(context, activeList[index], provider);
      },
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(
      BuildContext context, IconData icon, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.2),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search movies (YTS)...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isLoadingSearch
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (val) => _performSearch(val, appState.useProxyForTorrents),
      ),
    );
  }

  Future<void> _performSearch(String query, bool useProxy) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoadingSearch = true;
    });

    final results = await TorrentService.searchAll(query, useProxy: useProxy);

    setState(() {
      _searchResults = results;
      _isLoadingSearch = false;
    });
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_isLoadingSearch) {
      return const Center(child: Text('No results found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final res = _searchResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(res.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(res.size, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_upward, size: 10, color: Colors.green),
                  Text(res.seeds, style: const TextStyle(fontSize: 11, color: Colors.green)),
                  const Spacer(),
                  Text(res.provider, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              const Divider(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _actionButton(
                    label: 'Copy Magnet',
                    icon: Icons.copy,
                    color: Colors.blue,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: res.magnet));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Magnet copied!')));
                      }
                    },
                  ),
                  _actionButton(
                    label: 'Use 1DM',
                    icon: Icons.download_for_offline,
                    color: Colors.orange,
                    onPressed: () => _launchExternal(res.magnet),
                  ),
                  _actionButton(
                    label: 'Internal Stream',
                    icon: Icons.play_circle_outline,
                    color: Colors.green,
                    onPressed: () => _handleNewTorrent(context, res.title, res.magnet, res.size, autoStream: true),
                  ),
                   _actionButton(
                    label: 'VLC/External',
                    icon: Icons.video_library,
                    color: Colors.purple,
                    onPressed: () => _handleExternalPlayerSearch(context, res.title, res.magnet),
                  ),
                  _actionButton(
                    label: 'Add Active',
                    icon: Icons.add_circle_outline,
                    color: Colors.grey,
                    onPressed: () => _handleNewTorrent(context, res.title, res.magnet, res.size),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _handleExternalPlayerSearch(BuildContext context, String title, String magnet) async {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting engine for external play...')));
     final provider = context.read<TorrentProvider>();
     final appState = context.read<AppState>();
     
     // Check if already exists
     String? id;
     final existing = provider.torrents.where((t) => t.magnetLink == magnet).toList();
     if (existing.isNotEmpty) {
       id = existing.first.id;
     } else {
       // Add it temporarily
       await provider.addTorrent(title, magnet, appState.defaultSavePath, '0', isSequential: true);
       id = provider.torrents.first.id;
     }
     
     // Wait for task initialization
     await Future.delayed(const Duration(seconds: 3));
     final url = await provider.startStreaming(id);
     if (url != null) {
       _launchExternal(url);
     } else {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start stream server.')));
       }
     }
  }

  void _handleNewTorrent(
      BuildContext context, String title, String magnet, String size, {bool autoStream = false}) {
    bool isSequential = autoStream;
    Uint8List? metadata;
    bool isFetchingMetadata = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Torrent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Sequential Download'),
                subtitle: const Text('Watch while downloading'),
                value: isSequential,
                onChanged: (val) => setDialogState(() => isSequential = val),
              ),
              const Divider(),
              if (isFetchingMetadata)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Fetching metadata...',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () async {
                    if (metadata != null) {
                      _showFileSelection(context, title, metadata!);
                      return;
                    }
                    setDialogState(() => isFetchingMetadata = true);
                    final fetched = await context
                        .read<TorrentProvider>()
                        .fetchMetadata(magnet);
                    if (context.mounted) {
                      setDialogState(() {
                        isFetchingMetadata = false;
                        metadata = fetched;
                      });
                      if (metadata != null) {
                        _showFileSelection(context, title, metadata!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Failed to fetch metadata.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.list),
                  label: const Text('Select Specific Files'),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final appState = context.read<AppState>();
                final provider = context.read<TorrentProvider>();
                await provider.addTorrent(
                      title,
                      magnet,
                      appState.defaultSavePath,
                      size,
                      isSequential: isSequential,
                      metadata: metadata,
                    );
                
                if (context.mounted) {
                  Navigator.pop(ctx);
                  if (autoStream) {
                    // Try to finding the newly added item's ID
                    final item = provider.torrents.firstWhere((t) => t.magnetLink == magnet);
                    _handleStream(context, item.id, item.name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Torrent added to queue')),
                    );
                  }
                }
              },
              child: Text(autoStream ? 'Stream Now' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileSelection(
      BuildContext context, String title, Uint8List metadata) {
    final model = TorrentParser.parseBytes(metadata);
    final files = model.files;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Files in $title',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, i) {
                  final file = files[i];
                  return CheckboxListTile(
                    title: Text(file.name),
                    subtitle: Text(TorrentService.formatBytes(file.length)),
                    value: true,
                    onChanged: (val) {
                      // Metadata selection not fully implemented in provider yet,
                      // but showing real data is the first step.
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTorrentItem(
      BuildContext context, TorrentItem t, TorrentProvider provider) {
    final isDownloading = t.status == TorrentStatus.downloading;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerLow
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                t.status == TorrentStatus.completed
                    ? Icons.check_circle
                    : Icons.downloading,
                color: t.status == TorrentStatus.completed
                    ? Colors.green
                    : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: 18),
                itemBuilder: (ctx) => [
                  if (t.status == TorrentStatus.paused)
                    const PopupMenuItem(value: 'resume', child: Text('Resume'))
                  else if (t.status == TorrentStatus.downloading)
                    const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  const PopupMenuItem(
                      value: 'stream', child: Text('Stream / Play Online')),
                  const PopupMenuItem(
                      value: 'details', child: Text('Torrent Details')),
                  const PopupMenuItem(
                      value: 'open', child: Text('Open Folder')),
                  const PopupMenuItem(value: 'copy', child: Text('Copy Hash')),
                  const PopupMenuItem(
                      value: 'share', child: Text('Share Magnet')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (val) async {
                  if (val == 'pause') provider.pauseTorrent(t.id);
                  if (val == 'resume') provider.resumeTorrent(t.id);
                  if (val == 'details') _showTorrentDetails(context, t);
                  if (val == 'delete') provider.deleteTorrent(t.id);
                  if (val == 'copy') {
                    await Clipboard.setData(ClipboardData(text: t.hash));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hash copied!')));
                    }
                  }
                  if (val == 'sequential') {
                    provider.toggleSequential(t.id);
                  }
                  if (val == 'share') {
                    Share.share(t.magnetLink, subject: 'Share Magnet Link');
                  }
                  if (val == 'stream') {
                    if (context.mounted) {
                      _handleStream(context, t.id, t.name);
                    }
                  }
                  if (val == 'open') {
                    // Try to open using url_launcher for file path (simplified)
                    final uri = Uri.file(t.savePath);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Cannot open folder automatically.')));
                      }
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t.progress,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.2),
              color: t.status == TorrentStatus.completed
                  ? Colors.green
                  : Colors.blue,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '${(t.progress * 100).toInt()}% • ${t.size} • ${t.status.name}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
              if (isDownloading)
                Text(t.speed,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTorrentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final linkController = TextEditingController();
    bool isSequential = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Torrent Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(hintText: 'Name (optional)')),
              const SizedBox(height: 8),
              TextField(
                  controller: linkController,
                  decoration: const InputDecoration(
                      hintText: 'Magnet or .torrent URL')),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Sequential Download'),
                value: isSequential,
                onChanged: (val) => setDialogState(() => isSequential = val),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (linkController.text.isNotEmpty) {
                  final appState = context.read<AppState>();
                  context.read<TorrentProvider>().addTorrent(
                        nameController.text.isEmpty
                            ? 'New Torrent'
                            : nameController.text,
                        linkController.text,
                        appState.defaultSavePath,
                        'Unknown size',
                        isSequential: isSequential,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTorrentDetails(BuildContext context, TorrentItem t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<TorrentProvider>(
        builder: (context, provider, _) {
          final peers = provider.getPeers(t.id);
          final trackers = provider.getTrackers(t.id);
          final files = provider.getTaskFiles(t.id);

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(t.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                                maxLines: 2),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => _handleStream(context, t.id, t.name),
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Stream Now',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Hash: ${t.hash}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoCol('Size', t.size),
                          _buildInfoCol('Status', t.status.name),
                          _buildInfoCol(
                              'Peers', peers.length.toString()),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'Files'),
                            Tab(text: 'Peers'),
                            Tab(text: 'Trackers')
                          ],
                          indicatorColor: Colors.blue,
                          labelColor: Colors.blue,
                          unselectedLabelColor: Colors.grey,
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildFilesListTask(t.id, t.name, files),
                              _buildPeersList(peers),
                              _buildTrackersList(trackers),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilesListTask(
      String id, String title, List<TorrentFileModel> files) {
    if (files.isEmpty) {
      return const Center(child: Text('Files metadata loading...'));
    }
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        final isVideo = file.name.toLowerCase().endsWith('.mp4') ||
            file.name.toLowerCase().endsWith('.mkv') ||
            file.name.toLowerCase().endsWith('.avi');

        return ListTile(
          leading: Icon(isVideo ? Icons.video_file : Icons.insert_drive_file,
              color: isVideo ? Colors.blue : Colors.grey),
          title: Text(file.name, style: const TextStyle(fontSize: 14)),
          subtitle: Text(TorrentService.formatBytes(file.length)),
          trailing: isVideo
              ? IconButton(
                  icon: const Icon(Icons.play_circle_outline, color: Colors.blue),
                  onPressed: () => _handleStream(context, id, title,
                      filePath: file.path),
                )
              : null,
        );
      },
    );
  }

  Future<void> _handleStream(BuildContext context, String id, String title,
      {String? filePath}) async {
    final provider = context.read<TorrentProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting streaming server...')),
    );

    final url = await provider.startStreaming(id, filePath: filePath);
    if (url != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaPlayerScreen(
            url: url,
            title: title,
          ),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start streaming.')),
      );
    }
  }

  Widget _buildInfoCol(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildPeersList(List<dynamic> peers) {
    if (peers.isEmpty) {
      return const Center(child: Text('No active peers linked yet.'));
    }
    return ListView.builder(
      itemCount: peers.length,
      itemBuilder: (context, i) {
        final peer = peers[i] as Peer;
        return ListTile(
          leading: const Icon(Icons.computer, size: 20),
          title: Text(peer.address.address.address),
          subtitle: Text('Port: ${peer.address.port} • Client: ${peer.type}'),
          trailing: Text(
              '${(peer.currentDownloadSpeed / 1024).toStringAsFixed(1)} KB/s',
              style: const TextStyle(color: Colors.blue)),
        );
      },
    );
  }

  Widget _buildTrackersList(List<String> trackers) {
    if (trackers.isEmpty) {
      return const Center(child: Text('No trackers found.'));
    }
    return ListView.builder(
      itemCount: trackers.length,
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.router, size: 20),
        title: Text(trackers[i]),
        subtitle: const Text('Status: Active'),
      ),
    );
  }
}
