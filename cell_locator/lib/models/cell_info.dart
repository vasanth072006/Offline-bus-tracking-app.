class CellInfo {
  final String type;
  final int? mcc;
  final int? mnc;
  final int? lac;
  final int? tac;
  final int? cid;
  final int? pci;
  final int? signalDbm;
  final int? signalLevel;
  final String? operator;
  final DateTime timestamp;
  final String? error;

  CellInfo({
    required this.type,
    this.mcc,
    this.mnc,
    this.lac,
    this.tac,
    this.cid,
    this.pci,
    this.signalDbm,
    this.signalLevel,
    this.operator,
    required this.timestamp,
    this.error,
  });

  factory CellInfo.fromMap(Map<dynamic, dynamic> map) {
    return CellInfo(
      type: map['type']?.toString() ?? 'Unknown',
      mcc: _toInt(map['mcc']),
      mnc: _toInt(map['mnc']),
      lac: _toInt(map['lac']),
      tac: _toInt(map['tac']),
      cid: _toInt(map['cid']),
      pci: _toInt(map['pci']),
      signalDbm: _toInt(map['signal_dbm']),
      signalLevel: _toInt(map['signal_level']),
      operator: map['operator']?.toString(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(_toInt(map['timestamp']) ?? 0)
          : DateTime.now(),
      error: map['error']?.toString(),
    );
  }

  static int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString());
  }

  // Effective LAC (TAC in LTE, LAC in GSM/WCDMA)
  int? get effectiveLac => lac ?? tac;

  String get signalDescription {
    switch (signalLevel) {
      case 0: return 'No Signal';
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Excellent';
      default: return 'Unknown';
    }
  }

  String get dbmDisplay {
    if (signalDbm == null) return '--';
    return '${signalDbm} dBm';
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'mcc': mcc,
    'mnc': mnc,
    'lac': lac,
    'tac': tac,
    'cid': cid,
    'pci': pci,
    'signalDbm': signalDbm,
    'signalLevel': signalLevel,
    'operator': operator,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'CellInfo(type=$type, mcc=$mcc, mnc=$mnc, lac=${effectiveLac}, cid=$cid, dbm=$signalDbm)';
}

class AreaMatch {
  final String area;
  final String city;
  final String state;
  final double? lat;
  final double? lon;
  final String matchType; // 'exact', 'lac_only', 'city_hint', 'none'

  AreaMatch({
    required this.area,
    required this.city,
    required this.state,
    this.lat,
    this.lon,
    required this.matchType,
  });

  bool get isExact => matchType == 'exact';
  bool get hasCoordinates => lat != null && lon != null;

  String get displayName => '$area, $city';
  String get fullDisplay => '$area, $city, $state';
}

class NetworkOperatorInfo {
  final String? name;
  final String? operator;
  final String? countryIso;
  final String? simOperator;
  final String? networkType;
  final bool roaming;

  NetworkOperatorInfo({
    this.name,
    this.operator,
    this.countryIso,
    this.simOperator,
    this.networkType,
    this.roaming = false,
  });

  factory NetworkOperatorInfo.fromMap(Map<dynamic, dynamic> map) {
    return NetworkOperatorInfo(
      name: map['name']?.toString(),
      operator: map['operator']?.toString(),
      countryIso: map['country_iso']?.toString(),
      simOperator: map['sim_operator']?.toString(),
      networkType: map['network_type']?.toString(),
      roaming: map['roaming'] == true,
    );
  }
}

class TowerHistoryEntry {
  final CellInfo cellInfo;
  final AreaMatch? areaMatch;
  final DateTime detectedAt;

  TowerHistoryEntry({
    required this.cellInfo,
    this.areaMatch,
    required this.detectedAt,
  });
}
