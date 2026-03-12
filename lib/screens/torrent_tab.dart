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
  TorrentCategory _selectedCategory = TorrentCategory.all;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_rounded, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Magnet Link Detected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            'A magnet link was found in your clipboard. Would you like to add it to your downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ignore', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleNewTorrent(context, 'New Torrent', magnet, 'Unknown');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Torrent'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tProvider = context.watch<TorrentProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
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
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 120.0,
                  floating: true,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Torrents',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    centerTitle: false,
                    titlePadding: const EdgeInsetsDirectional.only(
                      start: 16,
                      bottom: 16,
                    ),
                    background: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    _buildStatusIcon(
                      context,
                      Icons.vpn_lock,
                      'VPN Active',
                      Colors.green,
                    ),
                    _buildStatusIcon(
                      context,
                      appState.torrentWifiOnly
                          ? Icons.wifi
                          : Icons.signal_cellular_alt,
                      appState.torrentWifiOnly ? 'Wi-Fi Only' : 'All Networks',
                      appState.torrentWifiOnly ? Colors.blue : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      tabs: const [
                        Tab(text: 'Search'),
                        Tab(text: 'Active'),
                      ],
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _buildSearchTab(context, appState),
                _buildActiveTab(tProvider),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: FloatingActionButton.extended(
            onPressed: () => _showAddTorrentDialog(context),
            icon: const Icon(Icons.link),
            label: const Text('Add Link'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab(BuildContext context, AppState appState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(child: _buildSearchBar(context, appState)),
              const SizedBox(width: 8),
              _buildProviderSelector(context, appState),
            ],
          ),
        ),
        _buildFilterHeader(),
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildFilterHeader() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              const Icon(Icons.category_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              ...TorrentCategory.values.map((cat) => _categoryChip(cat)),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              const Icon(Icons.sort_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              _sortChip('Seeds', 'seeds'),
              _sortChip('Size', 'size'),
              _sortChip('Name', 'name'),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _categoryChip(TorrentCategory cat) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ChoiceChip(
          label: Text(
            cat.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
            ),
          ),
          selected: isSelected,
          onSelected: (val) {
            if (val) {
              setState(() {
                _selectedCategory = cat;
              });
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text, context.read<AppState>());
              }
            }
          },
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
          showCheckmark: false,
        ),
      ),
    );
  }

  Widget _sortChip(String label, String key) {
    final isSelected = _sortBy == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ChoiceChip(
          label: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
            ),
          ),
          selected: isSelected,
          onSelected: (val) {
            if (val) {
              setState(() {
                _sortBy = key;
                _sortResults();
              });
            }
          },
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
          showCheckmark: false,
        ),
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
        _searchResults.sort((a, b) => b.size.compareTo(a.size)); 
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
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
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search movies, TV shows...',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                size: 20,
              ),
              suffixIcon: _isLoadingSearch
                  ? Container(
                      padding: const EdgeInsets.all(14.0),
                      width: 20,
                      height: 20,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (val) => _performSearch(val, appState),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderSelector(BuildContext context, AppState appState) {
    return IconButton(
      icon: const Icon(Icons.filter_list),
      onPressed: () => _showProviderSelection(context, appState),
      tooltip: 'Select Providers',
    );
  }

  void _showProviderSelection(BuildContext context, AppState appState) {
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
            const SizedBox(height: 16),
            const Text('Search Providers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Expanded(
              child: ListView(
                children: TorrentSearchProvider.values.map((p) {
                  final isSelected = appState.selectedTorrentProviders.contains(p);
                  return CheckboxListTile(
                    title: Text(p.name.toUpperCase()),
                    value: isSelected,
                    onChanged: (val) => appState.toggleTorrentProvider(p),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performSearch(String query, AppState appState) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoadingSearch = true;
    });

    final results = await TorrentService.searchAll(
      query,
      useProxy: appState.useProxyForTorrents,
      providers: appState.selectedTorrentProviders,
      category: _selectedCategory,
    );

    setState(() {
      _searchResults = results;
      _isLoadingSearch = false;
    });
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_isLoadingSearch) {
      return _buildEmptyState('No torrents found. Try searching for something!', Icons.search_off);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final res = _searchResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      res.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      res.provider.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoBadge(Icons.storage_outlined, res.size, Colors.grey),
                  const SizedBox(width: 16),
                  _infoBadge(Icons.arrow_upward, res.seeds, Colors.green),
                  const SizedBox(width: 16),
                  _infoBadge(Icons.arrow_downward, res.peers, Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _actionButtonCompact(
                      label: 'Magnet',
                      icon: Icons.copy_rounded,
                      color: Colors.blue,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: res.magnet));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Magnet link copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _actionButtonCompact(
                      label: 'Stream',
                      icon: Icons.play_arrow_rounded,
                      color: Colors.green,
                      onPressed: () => _handleNewTorrent(context, res.title, res.magnet, res.size, autoStream: true),
                    ),
                    const SizedBox(width: 8),
                    _actionButtonCompact(
                      label: 'VLC',
                      icon: Icons.video_library_rounded,
                      color: Colors.purple,
                      onPressed: () => _handleExternalPlayerSearch(context, res.title, res.magnet),
                    ),
                    const SizedBox(width: 8),
                    _actionButtonCompact(
                      label: '1DM',
                      icon: Icons.download_rounded,
                      color: Colors.orange,
                      onPressed: () => _launchExternal(res.magnet),
                    ),
                    const SizedBox(width: 8),
                    _actionButtonCompact(
                      label: 'Add',
                      icon: Icons.add_rounded,
                      color: Colors.grey,
                      onPressed: () => _handleNewTorrent(context, res.title, res.magnet, res.size),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _actionButtonCompact({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Torrent', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  title: const Text('Sequential Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Stream while downloading', style: TextStyle(fontSize: 12)),
                  value: isSequential,
                  onChanged: (val) => setDialogState(() => isSequential = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              if (isFetchingMetadata)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(strokeWidth: 3),
                        const SizedBox(height: 12),
                        Text('Fetching metadata...',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                              content: Text('Failed to fetch metadata. Check your connection.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.list_rounded, size: 20),
                    label: const Text('Select Specific Files'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
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
                    final item = provider.torrents.firstWhere((t) => t.magnetLink == magnet);
                    _handleStream(context, item.id, item.name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Torrent added successfully'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Files',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, i) {
                  final file = files[i];
                  final isVideo = file.name.toLowerCase().endsWith('.mp4') ||
                      file.name.toLowerCase().endsWith('.mkv') ||
                      file.name.toLowerCase().endsWith('.avi');
                  
                  return CheckboxListTile(
                    title: Text(file.name, style: const TextStyle(fontSize: 14)),
                    secondary: Icon(isVideo ? Icons.video_file_rounded : Icons.insert_drive_file_rounded,
                        color: isVideo ? Colors.blue : Colors.grey),
                    subtitle: Text(TorrentService.formatBytes(file.length), style: const TextStyle(fontSize: 12)),
                    value: true,
                    onChanged: (val) {
                      // Implementation for partial metadata select maybe later
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Confirm Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTorrentItem(
      BuildContext context, TorrentItem t, TorrentProvider provider) {
    final isDownloading = t.status == TorrentStatus.downloading;
    final isPaused = t.status == TorrentStatus.paused;
    final isCompleted = t.status == TorrentStatus.completed;

    Color statusColor = Colors.blue;
    if (isCompleted) statusColor = Colors.green;
    if (isPaused) statusColor = Colors.orange;
    if (t.status == TorrentStatus.error) statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : (isPaused ? Icons.pause_rounded : Icons.download_rounded),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.size} • ${t.status.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                itemBuilder: (ctx) => [
                  if (isPaused)
                    const PopupMenuItem(value: 'resume', child: Text('Resume'))
                  else if (isDownloading)
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
                  if (val == 'share') {
                    Share.share(t.magnetLink, subject: 'Share Magnet Link');
                  }
                  if (val == 'stream') {
                    if (context.mounted) {
                      _handleStream(context, t.id, t.name);
                    }
                  }
                  if (val == 'open') {
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
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t.progress,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.2),
              color: statusColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(t.progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              if (isDownloading)
                Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      t.speed,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Torrent Link', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Name (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  )),
              const SizedBox(height: 12),
              TextField(
                  controller: linkController,
                  decoration: InputDecoration(
                    hintText: 'Magnet or .torrent URL',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  )),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('Sequential Download', style: TextStyle(fontSize: 14)),
                  value: isSequential,
                  onChanged: (val) => setDialogState(() => isSequential = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hash: ${t.hash.substring(0, 8)}...${t.hash.substring(t.hash.length - 8)}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11, fontFeatures: const [FontFeature.tabularFigures()]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            onPressed: () => _handleStream(context, t.id, t.name),
                            icon: const Icon(Icons.play_arrow_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                            ),
                            tooltip: 'Stream Now',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInfoCol('Size', t.size),
                                _buildInfoCol('Status', t.status.name.toUpperCase()),
                                _buildInfoCol('Peers', peers.length.toString()),
                              ],
                            ),
                            const Divider(height: 24, thickness: 0.5),
                            SwitchListTile(
                              title: const Text('Sequential Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              subtitle: const Text('Required for active streaming', style: TextStyle(fontSize: 11)),
                              value: t.isSequential,
                              onChanged: (val) => provider.toggleSequential(t.id),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: const [
                            Tab(text: 'Files'),
                            Tab(text: 'Peers'),
                            Tab(text: 'Trackers')
                          ],
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
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
      final allFiles = provider.getTaskFiles(id);
      final videoFiles = allFiles.where((f) {
        final name = f.name.toLowerCase();
        return name.endsWith('.mp4') ||
            name.endsWith('.mkv') ||
            name.endsWith('.avi') ||
            name.endsWith('.mov') ||
            name.endsWith('.wmv') ||
            name.endsWith('.flv');
      }).toList();

      List<Map<String, String>> playlist = [];
      int initialIndex = 0;

      if (videoFiles.isEmpty) {
        // Fallback to single file if no videos detected (might be an unknown format)
        playlist = [{ 'url': url, 'title': title }];
      } else {
        playlist = videoFiles.map((f) {
          final fileUrl = 'http://127.0.0.1:9090/${Uri.encodeComponent(f.path)}';
          return { 'url': fileUrl, 'title': f.name };
        }).toList();
        
        if (filePath != null) {
          initialIndex = videoFiles.indexWhere((f) => f.path == filePath);
          if (initialIndex == -1) initialIndex = 0;
        } else {
           // Find which one is currently 'url' (usually the first one found by provider)
           initialIndex = playlist.indexWhere((item) => item['url'] == url);
           if (initialIndex == -1) initialIndex = 0;
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaPlayerScreen(
            url: playlist[initialIndex]['url']!,
            title: playlist[initialIndex]['title']!,
            playlist: playlist,
            initialIndex: initialIndex,
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
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPeersList(List<dynamic> peers) {
    if (peers.isEmpty) {
      return _buildEmptyState('No active peers yet.', Icons.cloud_off_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: peers.length,
      itemBuilder: (context, i) {
        final peer = peers[i];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.dns_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(peer.address.address.address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text('Port: ${peer.address.port}', style: const TextStyle(fontSize: 12)),
          trailing: Text(
            '${(peer.currentDownloadSpeed / 1024).toStringAsFixed(1)} KB/s',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackersList(List<String> trackers) {
    if (trackers.isEmpty) {
      return _buildEmptyState('No trackers found.', Icons.router_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: trackers.length,
      itemBuilder: (context, i) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.router_rounded, size: 18, color: Theme.of(context).colorScheme.secondary),
        ),
        title: Text(trackers[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text('Status: Active', style: TextStyle(color: Colors.green.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: _tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
