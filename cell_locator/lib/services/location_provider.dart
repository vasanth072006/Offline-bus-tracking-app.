import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/cell_info.dart';
import '../services/telephony_service.dart';
import '../database/cell_database.dart';

enum AppStatus { initializing, permissionDenied, locating, found, notFound, error }

class LocationProvider extends ChangeNotifier {
  final TelephonyService _telephony = TelephonyService();
  final CellDatabaseService _db = CellDatabaseService();

  AppStatus _status = AppStatus.initializing;
  CellInfo? _currentCell;
  AreaMatch? _currentArea;
  NetworkOperatorInfo? _networkInfo;
  bool _isOnline = false;
  bool _isTracking = false;
  List<TowerHistoryEntry> _history = [];
  String? _errorMessage;
  int _totalMappings = 0;
  StreamSubscription? _towerSub;
  StreamSubscription? _connectivitySub;

  // Getters
  AppStatus get status => _status;
  CellInfo? get currentCell => _currentCell;
  AreaMatch? get currentArea => _currentArea;
  NetworkOperatorInfo? get networkInfo => _networkInfo;
  bool get isOnline => _isOnline;
  bool get isTracking => _isTracking;
  List<TowerHistoryEntry> get history => _history;
  String? get errorMessage => _errorMessage;
  int get totalMappings => _totalMappings;

  Future<void> initialize() async {
    _status = AppStatus.initializing;
    notifyListeners();

    // Check connectivity
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      _isOnline = result != ConnectivityResult.none;
      notifyListeners();
    });
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = connectivity != ConnectivityResult.none;

    // Request permissions
    final granted = await _requestPermissions();
    if (!granted) {
      _status = AppStatus.permissionDenied;
      notifyListeners();
      return;
    }

    // Load DB stats
    _totalMappings = await _db.getTotalMappings();

    // Initial scan
    await refresh();

    // Load history
    await _loadHistory();
  }

  Future<bool> _requestPermissions() async {
    final phoneState = await Permission.phone.request();
    final location = await Permission.locationWhenInUse.request();
    return phoneState.isGranted && location.isGranted;
  }

  Future<void> refresh() async {
    _status = AppStatus.locating;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get cell info
      final cell = await _telephony.getCellInfo();
      if (cell == null) {
        _status = AppStatus.error;
        _errorMessage = 'Could not read cell tower data.\nEnsure permissions are granted and SIM card is inserted.';
        notifyListeners();
        return;
      }

      _currentCell = cell;

      // Get network operator info
      _networkInfo = await _telephony.getNetworkOperator();

      // Match area
      final match = await _db.lookup(cell);
      _currentArea = match;

      // Save to history
      await _db.saveHistory(cell, match);

      _status = match.matchType == 'none' ? AppStatus.notFound : AppStatus.found;
      notifyListeners();

      // Reload history
      await _loadHistory();
    } catch (e) {
      _status = AppStatus.error;
      _errorMessage = 'Error: ${e.toString()}';
      notifyListeners();
    }
  }

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    notifyListeners();

    _towerSub = _telephony.towerStream.listen(
      (cell) async {
        // Detect handover (tower change)
        final prevCid = _currentCell?.cid;
        if (prevCid != null && cell.cid != null && cell.cid != prevCid) {
          // Tower changed! Update location
          _currentCell = cell;
          final match = await _db.lookup(cell);
          _currentArea = match;
          await _db.saveHistory(cell, match);
          _status = match.matchType == 'none' ? AppStatus.notFound : AppStatus.found;
          await _loadHistory();
          notifyListeners();
        }
      },
      onError: (_) {},
    );
  }

  void stopTracking() {
    _isTracking = false;
    _towerSub?.cancel();
    _towerSub = null;
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final rows = await _db.getHistory(limit: 30);
    _history = rows.map((row) {
      final cell = CellInfo(
        type: row['cell_type']?.toString() ?? 'Unknown',
        mcc: row['mcc'] as int?,
        mnc: row['mnc'] as int?,
        lac: row['lac'] as int?,
        cid: row['cid'] as int?,
        signalDbm: row['signal_dbm'] as int?,
        signalLevel: row['signal_level'] as int?,
        operator: row['operator']?.toString(),
        timestamp: DateTime.parse(
            row['detected_at']?.toString() ?? DateTime.now().toIso8601String()),
      );
      AreaMatch? match;
      if (row['area'] != null) {
        match = AreaMatch(
          area: row['area'] as String,
          city: row['city']?.toString() ?? '',
          state: '',
          matchType: 'exact',
        );
      }
      return TowerHistoryEntry(
        cellInfo: cell,
        areaMatch: match,
        detectedAt: cell.timestamp,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addManualMapping({
    required String area,
    required String city,
    required String state,
    double? lat,
    double? lon,
  }) async {
    final cell = _currentCell;
    if (cell == null) return;
    await _db.addCustomMapping(
      mcc: cell.mcc ?? 0,
      mnc: cell.mnc ?? 0,
      lac: cell.effectiveLac ?? 0,
      cid: cell.cid ?? 0,
      area: area,
      city: city,
      state: state,
      lat: lat,
      lon: lon,
    );
    _totalMappings = await _db.getTotalMappings();
    await refresh();
  }

  @override
  void dispose() {
    _towerSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
