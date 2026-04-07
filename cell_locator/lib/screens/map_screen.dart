import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/location_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, _) {
        final area = provider.currentArea;
        final hasCoords = area?.hasCoordinates ?? false;

        final center = hasCoords
            ? LatLng(area!.lat!, area.lon!)
            : const LatLng(13.0827, 80.2707); // Default: Chennai

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D1528),
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Map',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (area != null)
                  Text(
                    area.displayName,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
              ],
            ),
            actions: [
              if (hasCoords)
                IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () => _mapController.move(center, 14),
                ),
            ],
          ),
          body: Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: hasCoords ? 14.0 : 11.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.celllocator.app',
                    maxZoom: 19,
                  ),
                  // Tower location marker
                  if (hasCoords)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(area!.lat!, area.lon!),
                          width: 80,
                          height: 80,
                          child: _TowerMarker(
                            areaName: area.area,
                            isExact: area.isExact,
                          ),
                        ),
                        // History markers
                        ...provider.history
                            .where((h) =>
                                h.areaMatch?.hasCoordinates == true)
                            .take(10)
                            .map((h) => Marker(
                                  point: LatLng(
                                      h.areaMatch!.lat!,
                                      h.areaMatch!.lon!),
                                  width: 20,
                                  height: 20,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.orange.withOpacity(0.6),
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                )),
                      ],
                    ),
                ],
              ),

              // Cell info overlay (top)
              if (provider.currentCell != null)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _CellInfoOverlay(provider: provider),
                ),

              // Offline hint
              if (!provider.isOnline)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.orange.withOpacity(0.9),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Offline - Map tiles may not load',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TowerMarker extends StatefulWidget {
  final String areaName;
  final bool isExact;

  const _TowerMarker({required this.areaName, required this.isExact});

  @override
  State<_TowerMarker> createState() => _TowerMarkerState();
}

class _TowerMarkerState extends State<_TowerMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            width: 60 * _anim.value,
            height: 60 * _anim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (widget.isExact
                      ? const Color(0xFF2979FF)
                      : Colors.orange)
                  .withOpacity(0.2),
            ),
          ),
        ),
        // Main dot
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isExact
                ? const Color(0xFF2979FF)
                : Colors.orange,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: (widget.isExact
                        ? const Color(0xFF2979FF)
                        : Colors.orange)
                    .withOpacity(0.5),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(Icons.cell_tower, size: 14, color: Colors.white),
        ),
      ],
    );
  }
}

class _CellInfoOverlay extends StatelessWidget {
  final LocationProvider provider;
  const _CellInfoOverlay({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cell = provider.currentCell!;
    final area = provider.currentArea;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xE0111827),
        border:
            Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          // Signal bars
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (i) {
                  final level = cell.signalLevel ?? 0;
                  final h = 8.0 + i * 4.0;
                  return Container(
                    margin: const EdgeInsets.only(left: 2),
                    width: 6,
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i < level
                          ? const Color(0xFF00E676)
                          : Colors.white.withOpacity(0.2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                cell.type.split(' ').first,
                style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  area?.displayName ?? 'Unknown area',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'CID: ${cell.cid ?? '--'} | LAC: ${cell.effectiveLac ?? '--'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (cell.signalDbm != null)
            Text(
              '${cell.signalDbm}dBm',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}
