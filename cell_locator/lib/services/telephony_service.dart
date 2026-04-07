import 'package:flutter/services.dart';
import '../models/cell_info.dart';

class TelephonyService {
  static const MethodChannel _channel =
      MethodChannel('com.celllocator/telephony');
  static const EventChannel _eventChannel =
      EventChannel('com.celllocator/tower_stream');

  Stream<CellInfo>? _towerStream;

  /// Get current cell tower info (one-time)
  Future<CellInfo?> getCellInfo() async {
    try {
      final result = await _channel.invokeMethod('getCellInfo');
      if (result == null) return null;
      return CellInfo.fromMap(Map<dynamic, dynamic>.from(result));
    } on PlatformException catch (e) {
      if (e.code == 'NO_DATA') return null;
      rethrow;
    }
  }

  /// Get network operator info
  Future<NetworkOperatorInfo?> getNetworkOperator() async {
    try {
      final result = await _channel.invokeMethod('getNetworkOperator');
      if (result == null) return null;
      return NetworkOperatorInfo.fromMap(Map<dynamic, dynamic>.from(result));
    } catch (_) {
      return null;
    }
  }

  /// Get all visible cells (not just serving)
  Future<List<Map<String, dynamic>>> getAllCells() async {
    try {
      final result =
          await _channel.invokeMethod<List>('getAllCells');
      if (result == null) return [];
      return result
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream tower changes (handover detection)
  Stream<CellInfo> get towerStream {
    _towerStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event != null)
        .map((event) =>
            CellInfo.fromMap(Map<dynamic, dynamic>.from(event as Map)));
    return _towerStream!;
  }
}
