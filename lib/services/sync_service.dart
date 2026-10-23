import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class SyncService extends ChangeNotifier {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _isSyncing = false;
  String _syncStatusMessage = 'Online • Data tersinkron';

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String get syncStatusMessage => _syncStatusMessage;

  void init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isNowOnline = !results.contains(ConnectivityResult.none);
      if (_isOnline != isNowOnline) {
        _isOnline = isNowOnline;
        _syncStatusMessage = _isOnline ? 'Online • Terhubung' : 'Offline • Mode Lokal Aktif';
        notifyListeners();
        if (_isOnline) {
          syncPendingData();
        }
      }
    });

    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = !results.contains(ConnectivityResult.none);
      _syncStatusMessage = _isOnline ? 'Online • Terhubung' : 'Offline • Mode Lokal Aktif';
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
    }
  }

  Future<void> syncPendingData() async {
    if (!_isOnline || _isSyncing) return;

    _isSyncing = true;
    _syncStatusMessage = 'Menyinkronkan data ke cloud...';
    notifyListeners();

    try {
      // Kirim seluruh data kendaraan yang belum tersinkron ke cloud backend
      final syncedCount = await DatabaseHelper.instance.syncPendingVehicles();
      if (syncedCount > 0) {
        debugPrint('Sync pending vehicles berhasil: $syncedCount unit.');
      }

      _syncStatusMessage = 'Online • Data tersinkron';
    } catch (e) {
      debugPrint('Sync Error: $e');
      _syncStatusMessage = 'Sinkronisasi tertunda';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
