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

class TorrentTab extends StatefulWidget {
  const TorrentTab({super.key});

  @override
  State<TorrentTab> createState() => _TorrentTabState();
}

class _TorrentTabState extends State<TorrentTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<TorrentSearchResult> _searchResults = [];
  bool _isLoadingSearch = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final torrentProvider = context.watch<TorrentProvider>();

    return DefaultTabController(
      length: 4,
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
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Search', icon: Icon(Icons.search, size: 20)),
              Tab(text: 'Active', icon: Icon(Icons.downloading, size: 20)),
              Tab(text: 'Library', icon: Icon(Icons.library_books, size: 20)),
              Tab(text: 'RSS', icon: Icon(Icons.rss_feed, size: 20)),
            ],
            isScrollable: true,
            indicatorColor: Colors.blue,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
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
                SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 48), // +48 for TabBar
                Expanded(
                  child: TabBarView(
                    children: [
                      // Search Tab
                      _buildSearchTab(context, appState),
                      // Active Tab
                      _buildActiveTab(torrentProvider),
                      // Library Tab
                      _buildLibraryTab(torrentProvider),
                      // RSS Tab
                      _buildRSSTab(torrentProvider),
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
                    height: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
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
            label: const Text('Add Link'),
            icon: const Icon(Icons.link),
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
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildActiveTab(TorrentProvider provider) {
    final activeList = provider.torrents.where((t) => 
      t.status != TorrentStatus.completed && t.status != TorrentStatus.error
    ).toList();

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

  Widget _buildLibraryTab(TorrentProvider provider) {
    final completedList = provider.torrents.where((t) => 
      t.status == TorrentStatus.completed
    ).toList();

    if (completedList.isEmpty) {
      return _buildEmptyState('Library is empty', Icons.library_books);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: completedList.length,
      itemBuilder: (context, index) {
        return _buildTorrentItem(context, completedList[index], provider);
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

  Widget _buildRSSTab(TorrentProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: const Text('Managed RSS Feeds', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.add_link),
                onPressed: () => _showAddRSSDialog(context, provider),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.refreshRSSFeeds(),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.rssFeeds.isEmpty
            ? _buildEmptyState('No RSS feeds added', Icons.rss_feed)
            : ListView.builder(
                itemCount: provider.rssFeeds.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.rss_feed, color: Colors.orange),
                  title: Text(provider.rssFeeds[i]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => provider.removeRSSFeed(provider.rssFeeds[i]),
                  ),
                ),
              ),
        ),
      ],
    );
  }

  void _showAddRSSDialog(BuildContext context, TorrentProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add RSS Feed'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'https://example.com/rss'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addRSSFeed(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, IconData icon, String tooltip, Color color) {
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
                    setState(() => _isSearching = false);
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
      _isSearching = true;
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
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Row(
              children: [
                Expanded(child: Text(res.title)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getProviderColor(res.provider).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getProviderColor(res.provider).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    res.provider,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getProviderColor(res.provider),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text('${res.size} • Seeds: ${res.seeds}'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                  onPressed: () => _handleNewTorrent(context, res.title, res.magnet, res.size),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleNewTorrent(BuildContext context, String title, String magnet, String size) {
    bool isSequential = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Torrent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Sequential Download'),
                subtitle: const Text('Watch while downloading'),
                value: isSequential,
                onChanged: (val) => setDialogState(() => isSequential = val),
              ),
              const Divider(),
              TextButton.icon(
                onPressed: () => _showFileSelection(context, title),
                icon: const Icon(Icons.list),
                label: const Text('Select Specific Files'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                context.read<TorrentProvider>().addTorrent(
                    title, magnet, '/storage/emulated/0/Download', size, isSequential: isSequential);
                Navigator.pop(ctx);
                setState(() => _isSearching = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Torrent added to queue')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileSelection(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Files in $title', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, i) => CheckboxListTile(
                  title: Text('File ${i + 1}.mp4'),
                  subtitle: const Text('700 MB'),
                  value: true,
                  onChanged: (val) {},
                ),
              ),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  Color _getProviderColor(String provider) {
    switch (provider) {
      case 'YTS': return Colors.green;
      case 'Solid': return Colors.blue;
      case 'PB': return Colors.orange;
      default: return Colors.grey;
    }
  }


  Widget _buildTorrentItem(BuildContext context, TorrentItem t, TorrentProvider provider) {
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
                t.status == TorrentStatus.completed ? Icons.check_circle : Icons.downloading,
                color: t.status == TorrentStatus.completed ? Colors.green : Colors.blue,
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
                  const PopupMenuItem(value: 'details', child: Text('Torrent Details')),
                  const PopupMenuItem(value: 'open', child: Text('Open Folder')),
                  const PopupMenuItem(value: 'copy', child: Text('Copy Hash')),
                  const PopupMenuItem(value: 'share', child: Text('Share Magnet')),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hash copied!')));
                    }
                  }
                  if (val == 'share') {
                    Share.share(t.magnetLink, subject: 'Share Magnet Link');
                  }
                  if (val == 'open') {
                    // Try to open using url_launcher for file path (simplified)
                    final uri = Uri.file(t.savePath);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open folder automatically.')));
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
              color: t.status == TorrentStatus.completed ? Colors.green : Colors.blue,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(t.progress * 100).toInt()}% • ${t.size} • ${t.status.name}',
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
                  decoration: const InputDecoration(hintText: 'Name (optional)')),
              const SizedBox(height: 8),
              TextField(
                  controller: linkController,
                  decoration: const InputDecoration(hintText: 'Magnet or .torrent URL')),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Sequential Download'),
                value: isSequential,
                onChanged: (val) => setDialogState(() => isSequential = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (linkController.text.isNotEmpty) {
                  context.read<TorrentProvider>().addTorrent(
                    nameController.text.isEmpty ? 'New Torrent' : nameController.text,
                    linkController.text,
                    '/storage/emulated/0/Download',
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
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 2),
                  const SizedBox(height: 8),
                  Text('Hash: ${t.hash}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoCol('Size', t.size),
                      _buildInfoCol('Status', t.status.name),
                      _buildInfoCol('Mode', t.isSequential ? 'Sequential' : 'Normal'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [Tab(text: 'Peers'), Tab(text: 'Trackers')],
                      indicatorColor: Colors.blue,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildPeersList(),
                          _buildTrackersList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildPeersList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.computer, size: 20),
        title: Text('192.168.1.${10 + i}'),
        subtitle: Text('Country ${['US', 'UK', 'CA', 'DE'][i % 4]} • Client: libtorrent/v2.0'),
        trailing: Text('${(2 + i * 0.5).toStringAsFixed(1)} MB/s', style: const TextStyle(color: Colors.blue)),
      ),
    );
  }

  Widget _buildTrackersList() {
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.router, size: 20),
        title: Text(['udp://tracker.opentrackr.org:1337', 'udp://tracker.openbittorrent.com:6969', 'https://tracker.nanoha.org:443', 'udp://9.rarbg.com:2810'][i]),
        subtitle: const Text('Status: Working • Update: 12m ago'),
      ),
    );
  }
}
