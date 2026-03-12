import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/torrent_service.dart';

class AppState with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _defaultSavePath = '/storage/emulated/0/Download/DirXplore';
  int _maxConcurrentDownloads = 1;
  String _appVersion = 'Unknown';
  bool _initialized = false;

  // Added Phase 1-4 Toggles
  bool _trueAmoledDark = false;
  bool _showDownloadNotifications = true;
  int _speedLimitCap = 0; // 0 means no limit (in KB/s)
  bool _keepScreenAwake = false;
  bool _smartFolderRouting = false;
  bool _downloadOnWifiOnly = false;
  bool _pauseLowBattery = false;
  bool _requireBiometrics = false;
  String _lockType = 'none'; // 'none', 'device', 'custom'
  String _customPinHash = '';
  String _securityQuestion = '';
  String _securityAnswer = '';
  int _autoLockSeconds = 0; // 0 = Immediate, 30, 60, 120
  bool _useProxyForTorrents = false;
  bool _torrentWifiOnly = false;
  bool _torrentPauseOnLowBattery = false;
  double _torrentDownloadLimit = 0; // MB/s
  double _torrentUploadLimit = 0;
  bool _monitorClipboardMagnet = false;
  List<TorrentSearchProvider> _selectedTorrentProviders = TorrentSearchProvider.values;

  ThemeMode get themeMode => _themeMode;
  String get defaultSavePath => _defaultSavePath;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  String get appVersion => _appVersion;
  bool get isInitialized => _initialized;

  // Added Getters
  bool get trueAmoledDark => _trueAmoledDark;
  bool get showDownloadNotifications => _showDownloadNotifications;
  int get speedLimitCap => _speedLimitCap;
  bool get keepScreenAwake => _keepScreenAwake;
  bool get smartFolderRouting => _smartFolderRouting;
  bool get downloadOnWifiOnly => _downloadOnWifiOnly;
  bool get pauseLowBattery => _pauseLowBattery;
  bool get requireBiometrics => _requireBiometrics;
  String get lockType => _lockType;
  String get customPinHash => _customPinHash;
  String get securityQuestion => _securityQuestion;
  String get securityAnswer => _securityAnswer;
  int get autoLockSeconds => _autoLockSeconds;
  bool get useProxyForTorrents => _useProxyForTorrents;
  bool get torrentWifiOnly => _torrentWifiOnly;
  bool get torrentPauseOnLowBattery => _torrentPauseOnLowBattery;
  double get torrentDownloadLimit => _torrentDownloadLimit;
  double get torrentUploadLimit => _torrentUploadLimit;
  bool get monitorClipboardMagnet => _monitorClipboardMagnet;
  List<TorrentSearchProvider> get selectedTorrentProviders =>
      _selectedTorrentProviders;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme
    final tIdx = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[tIdx];

    // Load Settings
    _defaultSavePath =
        prefs.getString('savePath') ?? '/storage/emulated/0/Download/DirXplore';
    _maxConcurrentDownloads = prefs.getInt('maxConcurrent') ?? 1;

    // Load Added Feature Toggles
    _trueAmoledDark = prefs.getBool('trueAmoledDark') ?? false;
    _showDownloadNotifications =
        prefs.getBool('showDownloadNotifications') ?? true;
    _speedLimitCap = prefs.getInt('speedLimitCap') ?? 0;
    _keepScreenAwake = prefs.getBool('keepScreenAwake') ?? false;
    _smartFolderRouting = prefs.getBool('smartFolderRouting') ?? false;
    _downloadOnWifiOnly = prefs.getBool('downloadOnWifiOnly') ?? false;
    _pauseLowBattery = prefs.getBool('pauseLowBattery') ?? false;
    _requireBiometrics = prefs.getBool('requireBiometrics') ?? false;
    _lockType = prefs.getString('lockType') ?? 'none';
    _customPinHash = prefs.getString('customPinHash') ?? '';
    _securityQuestion = prefs.getString('securityQuestion') ?? '';
    _securityAnswer = prefs.getString('securityAnswer') ?? '';
    _autoLockSeconds = prefs.getInt('autoLockSeconds') ?? 0;
    _useProxyForTorrents = prefs.getBool('useProxyForTorrents') ?? false;
    _torrentWifiOnly = prefs.getBool('torrentWifiOnly') ?? false;
    _torrentPauseOnLowBattery = prefs.getBool('torrentPauseOnLowBattery') ?? false;
    _torrentDownloadLimit = prefs.getDouble('torrentDownloadLimit') ?? 0;
    _torrentUploadLimit = prefs.getDouble('torrentUploadLimit') ?? 0;
    _monitorClipboardMagnet = prefs.getBool('monitorClipboardMagnet') ?? false;
    final pList = prefs.getStringList('selectedTorrentProviders');
    if (pList != null) {
      _selectedTorrentProviders = pList
          .map((e) => TorrentSearchProvider.values
              .firstWhere((v) => v.name == e, orElse: () => TorrentSearchProvider.yts))
          .toList();
    }

    // Load App Version
    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;

    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setDefaultSavePath(String path) async {
    _defaultSavePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savePath', path);
  }

  Future<void> setMaxConcurrentDownloads(int max) async {
    _maxConcurrentDownloads = max;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxConcurrent', max);
  }

  // --- Added Setters ---

  Future<void> setTrueAmoledDark(bool val) async {
    _trueAmoledDark = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trueAmoledDark', val);
  }

  Future<void> setShowDownloadNotifications(bool val) async {
    _showDownloadNotifications = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showDownloadNotifications', val);
  }

  Future<void> setSpeedLimitCap(int val) async {
    _speedLimitCap = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speedLimitCap', val);
  }

  Future<void> setKeepScreenAwake(bool val) async {
    _keepScreenAwake = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keepScreenAwake', val);
  }

  Future<void> setSmartFolderRouting(bool val) async {
    _smartFolderRouting = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smartFolderRouting', val);
  }

  Future<void> setDownloadOnWifiOnly(bool val) async {
    _downloadOnWifiOnly = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('downloadOnWifiOnly', val);
  }

  Future<void> setPauseLowBattery(bool val) async {
    _pauseLowBattery = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pauseLowBattery', val);
  }

  Future<void> setRequireBiometrics(bool val) async {
    _requireBiometrics = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('requireBiometrics', val);
  }

  Future<void> setLockType(String type) async {
    _lockType = type;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lockType', type);
  }

  Future<void> setCustomPin(String pin, String question, String answer) async {
    _customPinHash = pin; // In real app, use sha256 or similar
    _securityQuestion = question;
    _securityAnswer = answer;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customPinHash', pin);
    await prefs.setString('securityQuestion', question);
    await prefs.setString('securityAnswer', answer);
  }

  Future<void> resetCustomPin() async {
    _customPinHash = '';
    _securityQuestion = '';
    _securityAnswer = '';
    _lockType = 'none';
    _requireBiometrics = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customPinHash');
    await prefs.remove('securityQuestion');
    await prefs.remove('securityAnswer');
    await prefs.setBool('requireBiometrics', false);
    await prefs.setString('lockType', 'none');
  }

  bool get isSecurityEnabled => _lockType != 'none';

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoLockSeconds', seconds);
  }

  Future<void> setUseProxyForTorrents(bool val) async {
    _useProxyForTorrents = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useProxyForTorrents', val);
  }

  Future<void> setTorrentWifiOnly(bool val) async {
    _torrentWifiOnly = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('torrentWifiOnly', val);
  }

  Future<void> setTorrentPauseOnLowBattery(bool val) async {
    _torrentPauseOnLowBattery = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('torrentPauseOnLowBattery', val);
  }

  Future<void> setTorrentDownloadLimit(double val) async {
    _torrentDownloadLimit = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('torrentDownloadLimit', val);
  }

  Future<void> setTorrentUploadLimit(double val) async {
    _torrentUploadLimit = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('torrentUploadLimit', val);
  }

  Future<void> setMonitorClipboardMagnet(bool val) async {
    _monitorClipboardMagnet = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monitorClipboardMagnet', val);
  }

  Future<void> setSelectedTorrentProviders(
      List<TorrentSearchProvider> providers) async {
    _selectedTorrentProviders = providers;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'selectedTorrentProviders', providers.map((e) => e.name).toList());
  }

  Future<void> toggleTorrentProvider(TorrentSearchProvider provider) async {
    if (_selectedTorrentProviders.contains(provider)) {
      if (_selectedTorrentProviders.length > 1) {
        _selectedTorrentProviders.remove(provider);
      }
    } else {
      _selectedTorrentProviders.add(provider);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selectedTorrentProviders',
        _selectedTorrentProviders.map((e) => e.name).toList());
  }
}
