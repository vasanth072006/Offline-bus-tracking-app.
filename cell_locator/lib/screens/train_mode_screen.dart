import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_provider.dart';
import '../models/cell_info.dart';

/// Offline train-tracker style screen shown when there's no internet
class TrainModeScreen extends StatefulWidget {
  const TrainModeScreen({super.key});

  @override
  State<TrainModeScreen> createState() => _TrainModeScreenState();
}

class _TrainModeScreenState extends State<TrainModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _trainController;
  late AnimationController _dotController;
  int _dotCount = 1;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _trainController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat();

    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _trainController.dispose();
    _dotController.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, _) {
        final area = provider.currentArea;
        final cell = provider.currentCell;

        return Scaffold(
          backgroundColor: const Color(0xFF050B14),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent(provider, area, cell)),
                _buildFooter(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1528),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF2979FF).withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.train, color: Color(0xFF2979FF), size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Where Am I?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFAB40),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Offline Mode — Cell Tower Tracking',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

  Widget _buildContent(
      LocationProvider provider, AreaMatch? area, CellInfo? cell) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Animated train track
          _buildTrainTrack(provider),
          const SizedBox(height: 24),

          // Current location card
          _buildCurrentLocation(area, cell),
          const SizedBox(height: 16),

          // Tower tech data
          if (cell != null) _buildTechPanel(cell),
          const SizedBox(height: 16),

          // Journey history (handover log)
          if (provider.history.isNotEmpty)
            _buildJourneyLog(provider),
        ],
      ),
    );
  }

  Widget _buildTrainTrack(LocationProvider provider) {
    final history = provider.history;
    final stations = history
        .where((h) => h.areaMatch != null)
        .take(5)
        .toList()
        .reversed
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0D1528),
        border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF2979FF), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Journey Track',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${history.length} tower${history.length == 1 ? '' : 's'} detected',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Train animation bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 48,
              color: Colors.white.withOpacity(0.04),
              child: Stack(
                children: [
                  // Track lines
                  Positioned.fill(
                    child: CustomPaint(painter: _TrackPainter()),
                  ),
                  // Train
                  AnimatedBuilder(
                    animation: _trainController,
                    builder: (_, __) {
                      final pos = _trainController.value;
                      return Positioned(
                        left: pos * (MediaQuery.of(context).size.width - 120),
                        top: 8,
                        child: _TrainIcon(moving: true),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Station stops
          if (stations.isEmpty)
            Center(
              child: Text(
                'Start moving to see your journey...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Column(
              children: stations.asMap().entries.map((entry) {
                final i = entry.key;
                final h = entry.value;
                final isCurrent = i == stations.length - 1;
                return _StationStop(
                  name: h.areaMatch!.area,
                  city: h.areaMatch!.city,
                  time: h.detectedAt,
                  isCurrent: isCurrent,
                  isFirst: i == 0,
                  isLast: i == stations.length - 1,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocation(AreaMatch? area, CellInfo? cell) {
    final isLocating = area == null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: area?.isExact == true
              ? [const Color(0xFF0D2547), const Color(0xFF071A35)]
              : [const Color(0xFF1C1000), const Color(0xFF110B00)],
        ),
        border: Border.all(
          color: area?.isExact == true
              ? const Color(0xFF2979FF).withOpacity(0.5)
              : const Color(0xFFFFAB40).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'YOU ARE HERE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              if (isLocating)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFFFFAB40),
                  ),
                )
              else
                Icon(
                  area!.isExact
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: area.isExact
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFFAB40),
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isLocating
                ? 'Locating${'.' * _dotCount}'
                : area!.area,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (!isLocating) ...[
            const SizedBox(height: 6),
            Text(
              '${area!.city}${area.state.isNotEmpty ? ', ${area.state}' : ''}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusBadge(
                  label: area.matchType == 'exact'
                      ? 'Exact Match'
                      : area.matchType == 'lac_only'
                          ? 'Area Match'
                          : 'City Estimate',
                  color: area.matchType == 'exact'
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFFAB40),
                ),
                if (cell != null) ...[
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: cell.type.split(' ').first,
                    color: const Color(0xFF2979FF),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTechPanel(CellInfo cell) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0D1528),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: Color(0xFF2979FF), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Cell Tower Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _techGrid(cell),
        ],
      ),
    );
  }

  Widget _techGrid(CellInfo cell) {
    final items = [
      ['MCC', '${cell.mcc ?? '--'}', 'Country Code'],
      ['MNC', '${cell.mnc ?? '--'}', 'Network Code'],
      [cell.tac != null ? 'TAC' : 'LAC', '${cell.effectiveLac ?? '--'}', 'Area Code'],
      ['CID', '${cell.cid ?? '--'}', 'Cell ID'],
      ['Signal', cell.dbmDisplay, 'Strength'],
      ['Quality', cell.signalDescription, 'Level'],
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.3,
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item[0],
              style: TextStyle(
                color: const Color(0xFF2979FF).withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              item[1],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              item[2],
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 9,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildJourneyLog(LocationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0D1528),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off,
                  color: Color(0xFF2979FF), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Handover Log',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Tower changes',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...provider.history.take(8).map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.areaMatch != null
                        ? const Color(0xFF2979FF).withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    border: Border.all(
                      color: entry.areaMatch != null
                          ? const Color(0xFF2979FF).withOpacity(0.4)
                          : Colors.orange.withOpacity(0.4),
                    ),
                  ),
                  child: Icon(
                    entry.areaMatch != null
                        ? Icons.cell_tower
                        : Icons.help_outline,
                    size: 14,
                    color: entry.areaMatch != null
                        ? const Color(0xFF2979FF)
                        : Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.areaMatch?.displayName ??
                            'Unknown (CID: ${entry.cellInfo.cid ?? '--'})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        entry.cellInfo.type,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(entry.detectedAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                    if (entry.cellInfo.signalDbm != null)
                      Text(
                        '${entry.cellInfo.signalDbm}dBm',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFooter(LocationProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: const Color(0xFF050B14),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Scan Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                if (provider.isTracking) {
                  provider.stopTracking();
                } else {
                  provider.startTracking();
                }
              },
              icon: Icon(
                provider.isTracking ? Icons.pause : Icons.play_arrow,
                size: 18,
              ),
              label: Text(provider.isTracking ? 'Pause' : 'Auto-Track'),
              style: OutlinedButton.styleFrom(
                foregroundColor: provider.isTracking
                    ? const Color(0xFF00E676)
                    : Colors.white60,
                side: BorderSide(
                  color: provider.isTracking
                      ? const Color(0xFF00E676).withOpacity(0.5)
                      : Colors.white.withOpacity(0.15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StationStop extends StatelessWidget {
  final String name;
  final String city;
  final DateTime time;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;

  const _StationStop({
    required this.name,
    required this.city,
    required this.time,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFF2979FF).withOpacity(0.3),
                    ),
                  )
                else
                  const SizedBox(height: 8),
                Container(
                  width: isCurrent ? 14 : 10,
                  height: isCurrent ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? const Color(0xFF2979FF)
                        : const Color(0xFF2979FF).withOpacity(0.4),
                    border: isCurrent
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFF2979FF).withOpacity(0.3),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Station info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.white70,
                            fontSize: isCurrent ? 14 : 13,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        Text(
                          city,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF2979FF)
                          : Colors.white.withOpacity(0.25),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainIcon extends StatelessWidget {
  final bool moving;
  const _TrainIcon({required this.moving});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2979FF).withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.train, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2;

    // Rail lines
    canvas.drawLine(
        Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.35),
        paint);
    canvas.drawLine(
        Offset(0, size.height * 0.65),
        Offset(size.width, size.height * 0.65),
        paint);

    // Sleepers
    final sleeperPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    for (double x = 10; x < size.width; x += 24) {
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height * 0.8),
        sleeperPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => false;
}
