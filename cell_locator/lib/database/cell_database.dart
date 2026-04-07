import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/cell_info.dart';

class CellDatabaseService {
  static Database? _db;
  static bool _seeded = false;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cell_towers.db');

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    if (!_seeded) {
      await _seedFromAssets(db);
      _seeded = true;
    }

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cell_areas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mcc INTEGER NOT NULL,
        mnc INTEGER NOT NULL,
        lac INTEGER NOT NULL,
        cid INTEGER NOT NULL,
        area TEXT NOT NULL,
        city TEXT NOT NULL,
        state TEXT NOT NULL,
        lat REAL,
        lon REAL,
        type TEXT DEFAULT 'urban',
        UNIQUE(mcc, mnc, lac, cid)
      )
    ''');

    await db.execute('''
      CREATE TABLE tower_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mcc INTEGER,
        mnc INTEGER,
        lac INTEGER,
        cid INTEGER,
        cell_type TEXT,
        area TEXT,
        city TEXT,
        signal_dbm INTEGER,
        signal_level INTEGER,
        operator TEXT,
        detected_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE lac_hints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mcc INTEGER NOT NULL,
        mnc INTEGER NOT NULL,
        lac INTEGER NOT NULL,
        city TEXT NOT NULL,
        state TEXT NOT NULL,
        lat REAL,
        lon REAL,
        UNIQUE(mcc, mnc, lac)
      )
    ''');

    await db.execute('CREATE INDEX idx_cells ON cell_areas(mcc, mnc, lac, cid)');
    await db.execute('CREATE INDEX idx_lac ON lac_hints(mcc, mnc, lac)');
    await db.execute('CREATE INDEX idx_history ON tower_history(detected_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration: add type column if missing
      try {
        await db.execute("ALTER TABLE cell_areas ADD COLUMN type TEXT DEFAULT 'urban'");
      } catch (_) {}
    }
  }

  Future<void> _seedFromAssets(Database db) async {
    try {
      // Check if already seeded
      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cell_areas'));
      if ((count ?? 0) > 0) return;

      // Load from JSON asset
      final jsonStr =
          await rootBundle.loadString('assets/cell_database.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final areas = data['areas'] as List;

      final batch = db.batch();
      for (final area in areas) {
        batch.insert(
          'cell_areas',
          {
            'mcc': area['mcc'],
            'mnc': area['mnc'],
            'lac': area['lac'],
            'cid': area['cid'],
            'area': area['area'],
            'city': area['city'],
            'state': area['state'],
            'lat': area['lat'],
            'lon': area['lon'],
            'type': area['type'] ?? 'urban',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);

      // Seed LAC hints from india_cells.json
      final hintStr =
          await rootBundle.loadString('assets/india_cells.json');
      final hintData = json.decode(hintStr) as Map<String, dynamic>;
      final lacHints = hintData['lac_city_hints'] as Map<String, dynamic>? ?? {};

      final hintBatch = db.batch();
      lacHints.forEach((lac, city) {
        hintBatch.insert('lac_hints', {
          'mcc': 404,
          'mnc': 20,
          'lac': int.tryParse(lac) ?? 0,
          'city': city,
          'state': 'India',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        // Also add for Jio
        hintBatch.insert('lac_hints', {
          'mcc': 405,
          'mnc': 840,
          'lac': int.tryParse(lac) ?? 0,
          'city': city,
          'state': 'India',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });
      await hintBatch.commit(noResult: true);
    } catch (e) {
      // Silently handle seeding errors
    }
  }

  /// Exact lookup: MCC + MNC + LAC + CID
  Future<AreaMatch?> lookupExact(
      {required int mcc, required int mnc, required int lac, required int cid}) async {
    final db = await database;
    final rows = await db.query(
      'cell_areas',
      where: 'mcc = ? AND mnc = ? AND lac = ? AND cid = ?',
      whereArgs: [mcc, mnc, lac, cid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AreaMatch(
      area: row['area'] as String,
      city: row['city'] as String,
      state: row['state'] as String,
      lat: row['lat'] as double?,
      lon: row['lon'] as double?,
      matchType: 'exact',
    );
  }

  /// Fuzzy lookup: just LAC (any CID in that area)
  Future<AreaMatch?> lookupByLac(
      {required int mcc, required int mnc, required int lac}) async {
    final db = await database;

    // Try exact LAC match in cell_areas
    final rows = await db.query(
      'cell_areas',
      where: 'mcc = ? AND mnc = ? AND lac = ?',
      whereArgs: [mcc, mnc, lac],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final row = rows.first;
      return AreaMatch(
        area: 'Near ${row['area']}',
        city: row['city'] as String,
        state: row['state'] as String,
        lat: row['lat'] as double?,
        lon: row['lon'] as double?,
        matchType: 'lac_only',
      );
    }

    // Try LAC hints table
    final hints = await db.query(
      'lac_hints',
      where: 'mcc = ? AND mnc = ? AND lac = ?',
      whereArgs: [mcc, mnc, lac],
      limit: 1,
    );
    if (hints.isNotEmpty) {
      final hint = hints.first;
      return AreaMatch(
        area: 'Area in ${hint['city']}',
        city: hint['city'] as String,
        state: hint['state'] as String,
        lat: hint['lat'] as double?,
        lon: hint['lon'] as double?,
        matchType: 'city_hint',
      );
    }

    return null;
  }

  /// Best effort: try all strategies
  Future<AreaMatch> lookup(CellInfo cell) async {
    final mcc = cell.mcc;
    final mnc = cell.mnc;
    final lac = cell.effectiveLac;
    final cid = cell.cid;

    if (mcc == null || mnc == null) {
      return AreaMatch(
        area: 'Unknown Area',
        city: 'Unknown',
        state: '',
        matchType: 'none',
      );
    }

    // 1. Exact match
    if (lac != null && cid != null) {
      final exact = await lookupExact(mcc: mcc, mnc: mnc, lac: lac, cid: cid);
      if (exact != null) return exact;
    }

    // 2. LAC only
    if (lac != null) {
      final lacMatch = await lookupByLac(mcc: mcc, mnc: mnc, lac: lac);
      if (lacMatch != null) return lacMatch;
    }

    // 3. Unknown
    return AreaMatch(
      area: 'Unknown Area',
      city: 'MCC:$mcc MNC:$mnc',
      state: lac != null ? 'LAC:$lac' : 'No location data',
      matchType: 'none',
    );
  }

  /// Save tower to history
  Future<void> saveHistory(CellInfo cell, AreaMatch? match) async {
    final db = await database;
    await db.insert('tower_history', {
      'mcc': cell.mcc,
      'mnc': cell.mnc,
      'lac': cell.effectiveLac,
      'cid': cell.cid,
      'cell_type': cell.type,
      'area': match?.area,
      'city': match?.city,
      'signal_dbm': cell.signalDbm,
      'signal_level': cell.signalLevel,
      'operator': cell.operator,
      'detected_at': DateTime.now().toIso8601String(),
    });

    // Keep only last 200 entries
    await db.rawDelete('''
      DELETE FROM tower_history WHERE id NOT IN (
        SELECT id FROM tower_history ORDER BY id DESC LIMIT 200
      )
    ''');
  }

  /// Get tower history
  Future<List<Map<String, dynamic>>> getHistory({int limit = 50}) async {
    final db = await database;
    return db.query(
      'tower_history',
      orderBy: 'detected_at DESC',
      limit: limit,
    );
  }

  /// Add a custom mapping
  Future<void> addCustomMapping({
    required int mcc,
    required int mnc,
    required int lac,
    required int cid,
    required String area,
    required String city,
    required String state,
    double? lat,
    double? lon,
  }) async {
    final db = await database;
    await db.insert(
      'cell_areas',
      {
        'mcc': mcc,
        'mnc': mnc,
        'lac': lac,
        'cid': cid,
        'area': area,
        'city': city,
        'state': state,
        'lat': lat,
        'lon': lon,
        'type': 'custom',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getTotalMappings() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM cell_areas')) ??
        0;
  }
}
