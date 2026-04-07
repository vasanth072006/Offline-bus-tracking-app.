import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_provider.dart';
import '../models/cell_info.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(provider),
                Expanded(
                  child: _buildBody(provider),
                ),
                _buildBottomBar(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(LocationProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2035),
            const Color(0xFF0D1528),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.blue.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF2979FF), Color(0xFF00B0FF)],
              ),
            ),
            child: const Icon(Icons.cell_tower, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TowerTrack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                provider.isOnline ? '● Online Mode' : '● Offline Mode',
                style: TextStyle(
                  color: provider.isOnline
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFFAB40),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Tracking toggle
          GestureDetector(
            onTap: () {
              if (provider.isTracking) {
                provider.stopTracking();
              } else {
                provider.startTracking();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: provider.isTracking
                    ? const Color(0xFF00E676).withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: provider.isTracking
                      ? const Color(0xFF00E676)
                      : Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.isTracking ? Icons.track_changes : Icons.gps_off,
                    size: 14,
                    color: provider.isTracking
                        ? const Color(0xFF00E676)
                        : Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.isTracking ? 'Live' : 'Track',
                    style: TextStyle(
                      color: provider.isTracking
                          ? const Color(0xFF00E676)
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Map button
          if (provider.isOnline)
            IconButton(
              icon: const Icon(Icons.map_outlined, color: Color(0xFF2979FF)),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapScreen())),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(LocationProvider provider) {
    switch (provider.status) {
      case AppStatus.initializing:
      case AppStatus.locating:
        return _buildLocating();
      case AppStatus.permissionDenied:
        return _buildPermissionDenied();
      case AppStatus.found:
        return _buildFound(provider);
      case AppStatus.notFound:
        return _buildNotFound(provider);
      case AppStatus.error:
        return _buildError(provider);
    }
  }

  Widget _buildLocating() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scanController,
            builder: (_, __) {
              return CustomPaint(
                size: const Size(180, 180),
                painter: RadarPainter(_scanController.value),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Scanning Cell Towers...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reading TelephonyManager data',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFound(LocationProvider provider) {
    final cell = provider.currentCell!;
    final area = provider.currentArea!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Main location card
          _buildLocationCard(area, cell),
          const SizedBox(height: 16),
          // Tower details
          _buildTowerCard(cell, provider),
          const SizedBox(height: 16),
          // Signal strength
          _buildSignalCard(cell),
          const SizedBox(height: 16),
          // History
          if (provider.history.isNotEmpty) _buildHistoryCard(provider),
        ],
      ),
    );
  }

  Widget _buildLocationCard(AreaMatch area, CellInfo cell) {
    final isExact = area.isExact;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isExact
              ? [const Color(0xFF1B3A6B), const Color(0xFF0D2040)]
              : [const Color(0xFF2D2016), const Color(0xFF1A1308)],
        ),
        border: Border.all(
          color: isExact
              ? const Color(0xFF2979FF).withOpacity(0.4)
              : const Color(0xFFFFAB40).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isExact
                      ? const Color(0xFF2979FF).withOpacity(0.2)
                      : const Color(0xFFFFAB40).withOpacity(0.2),
                ),
                child: Text(
                  isExact ? '✓ EXACT MATCH' : '~ APPROXIMATE',
                  style: TextStyle(
                    color: isExact
                        ? const Color(0xFF2979FF)
                        : const Color(0xFFFFAB40),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.location_on,
                color: isExact
                    ? const Color(0xFF2979FF)
                    : const Color(0xFFFFAB40),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            area.area,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            area.city,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (area.state.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              area.state,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
          if (area.hasCoordinates) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed, size: 14,
                      color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 6),
                  Text(
                    '${area.lat!.toStringAsFixed(4)}, ${area.lon!.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTowerCard(CellInfo cell, LocationProvider provider) {
    final net = provider.networkInfo;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF111827),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cell_tower, color: Color(0xFF2979FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Tower Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF2979FF).withOpacity(0.15),
                ),
                child: Text(
                  cell.type,
                  style: const TextStyle(
                    color: Color(0xFF2979FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoGrid([
            _InfoItem('MCC', '${cell.mcc ?? '--'}'),
            _InfoItem('MNC', '${cell.mnc ?? '--'}'),
            _InfoItem(cell.tac != null ? 'TAC' : 'LAC',
                '${cell.effectiveLac ?? '--'}'),
            _InfoItem('Cell ID', '${cell.cid ?? '--'}'),
            if (cell.pci != null) _InfoItem('PCI', '${cell.pci}'),
            _InfoItem('Network', net?.networkType ?? cell.type),
          ]),
          if (net != null) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  net.name ?? net.simOperator ?? 'Unknown Operator',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (net.roaming) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.orange.withOpacity(0.2),
                    ),
                    child: const Text('ROAMING',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoGrid(List<_InfoItem> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSignalCard(CellInfo cell) {
    final level = cell.signalLevel ?? 0;
    final bars = List.generate(4, (i) => i < level);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF111827),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signal Strength',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cell.signalDescription,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                cell.dbmDisplay,
                style: const TextStyle(
                  color: Color(0xFF2979FF),
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final filled = bars[i];
              final h = 12.0 + i * 8.0;
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 10,
                height: h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: filled
                      ? _signalColor(level)
                      : Colors.white.withOpacity(0.15),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _signalColor(int level) {
    switch (level) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.yellow;
      case 4: return const Color(0xFF00E676);
      default: return Colors.grey;
    }
  }

  Widget _buildHistoryCard(LocationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF111827),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF2979FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Tower History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${provider.history.length} entries',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...provider.history.take(5).map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.areaMatch != null
                        ? const Color(0xFF00E676)
                        : Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.areaMatch?.displayName ??
                        'CID: ${entry.cellInfo.cid ?? 'Unknown'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTime(entry.detectedAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  Widget _buildNotFound(LocationProvider provider) {
    final cell = provider.currentCell;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF1A1508),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.location_searching,
                    color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Tower Not in Database',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cell tower detected but area not mapped.\nYou can add it manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (cell != null) ...[
                  const SizedBox(height: 16),
                  _infoGrid([
                    _InfoItem('MCC', '${cell.mcc ?? '--'}'),
                    _InfoItem('MNC', '${cell.mnc ?? '--'}'),
                    _InfoItem('LAC/TAC', '${cell.effectiveLac ?? '--'}'),
                    _InfoItem('Cell ID', '${cell.cid ?? '--'}'),
                  ]),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _showAddMappingDialog(provider),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add to Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (cell != null) _buildTowerCard(cell, provider),
          if (cell != null) ...[
            const SizedBox(height: 16),
            _buildSignalCard(cell),
          ],
        ],
      ),
    );
  }

  Widget _buildError(LocationProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_off, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Unable to Read Cell Data',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Permissions Required',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'TowerTrack needs READ_PHONE_STATE and ACCESS_FINE_LOCATION permissions to detect cell towers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await openAppSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(LocationProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1528),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Text(
            '${provider.totalMappings} areas mapped',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: provider.status == AppStatus.locating
                ? null
                : provider.refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2979FF),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMappingDialog(LocationProvider provider) {
    final areaCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Area Mapping',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(areaCtrl, 'Area Name (e.g. T. Nagar)'),
            const SizedBox(height: 12),
            _dialogField(cityCtrl, 'City (e.g. Chennai)'),
            const SizedBox(height: 12),
            _dialogField(stateCtrl, 'State (e.g. Tamil Nadu)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (areaCtrl.text.isNotEmpty && cityCtrl.text.isNotEmpty) {
                provider.addManualMapping(
                  area: areaCtrl.text,
                  city: cityCtrl.text,
                  state: stateCtrl.text,
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}

// Radar scanner painter
class RadarPainter extends CustomPainter {
  final double progress;
  RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw rings
    for (int i = 1; i <= 3; i++) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF2979FF).withOpacity(0.2);
      canvas.drawCircle(center, radius * i / 3, ringPaint);
    }

    // Draw sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [
          Colors.transparent,
          const Color(0xFF2979FF).withOpacity(0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Blip
    final blipAngle = progress * math.pi * 2 - math.pi / 2;
    final blipPos = Offset(
      center.dx + radius * 0.6 * math.cos(blipAngle),
      center.dy + radius * 0.6 * math.sin(blipAngle),
    );
    canvas.drawCircle(
      blipPos,
      4,
      Paint()..color = const Color(0xFF00E676),
    );
  }

  @override
  bool shouldRepaint(RadarPainter old) => old.progress != progress;
}
