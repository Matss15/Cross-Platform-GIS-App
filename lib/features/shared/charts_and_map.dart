part of '../../app.dart';

class CategoryPanel extends StatelessWidget {
  const CategoryPanel({super.key, required this.categoryCounts});

  final Map<String, int> categoryCounts;

  @override
  Widget build(BuildContext context) {
    final entries = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visibleEntries = entries.take(4).toList();
    final total = categoryCounts.values.fold<int>(
      0,
      (runningTotal, value) => runningTotal + value,
    );
    final colors = [
      AppColors.fire,
      AppColors.amber,
      AppColors.blue,
      AppColors.success,
    ];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Incident categories',
            subtitle: 'Share by report type.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: Center(
              child: DonutChart(entries: visibleEntries, total: total),
            ),
          ),
          const SizedBox(height: 12),
          if (visibleEntries.isEmpty)
            const Text(
              'No incident categories yet.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            ...List.generate(visibleEntries.length, (index) {
              final entry = visibleEntries[index];
              final percent = total == 0
                  ? 0
                  : (entry.value / total * 100).round();
              return LegendRow(
                label: entry.key,
                color: colors[index % colors.length],
                value: '$percent%',
              );
            }),
        ],
      ),
    );
  }
}

class DashboardChart extends StatelessWidget {
  const DashboardChart({super.key, required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final normalizedValues = values.length == 7
        ? values
        : List<int>.filled(7, 0);
    final maxValue = math.max(
      1,
      normalizedValues.fold<int>(0, (max, value) => math.max(max, value)),
    );

    return SizedBox(
      height: 250,
      child: normalizedValues.every((value) => value == 0)
          ? const Center(
              child: Text(
                'No weekly incident records yet.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(normalizedValues.length, (index) {
                final heightFactor = normalizedValues[index] / maxValue;
                final color = index == 6 ? AppColors.fire : AppColors.blue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              widthFactor: 0.72,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          labels[index],
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.entries,
    required this.total,
    this.dimension = 170,
  });

  final List<MapEntry<String, int>> entries;
  final int total;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const Text(
        '0\nreports',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900),
      );
    }

    return CustomPaint(
      painter: DonutPainter(entries: entries, total: total),
      child: SizedBox.square(
        dimension: dimension,
        child: Center(
          child: Text(
            '$total\nreports',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  const DonutPainter({required this.entries, required this.total});

  final List<MapEntry<String, int>> entries;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      AppColors.fire,
      AppColors.amber,
      AppColors.blue,
      AppColors.success,
    ];
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 22;

    for (var i = 0; i < entries.length; i++) {
      final sweep = entries[i].value / total * math.pi * 2;
      paint.color = colors[i];
      canvas.drawArc(rect.deflate(20), start, sweep - 0.05, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.total != total;
  }
}

class MapPreview extends StatefulWidget {
  const MapPreview({
    super.key,
    required this.accent,
    this.height = 320,
    this.ownOnly = false,
  });

  final Color accent;
  final double height;
  final bool ownOnly;

  @override
  State<MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<MapPreview> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _moveTo(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(11, 18).toDouble();
    _mapController.move(camera.center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: rosarioCenter,
                    initialZoom: widget.height >= 500 ? 13.4 : 12.8,
                    minZoom: 11,
                    maxZoom: 18,
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: rosarioBounds,
                    ),
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.drag |
                          InteractiveFlag.flingAnimation |
                          InteractiveFlag.pinchMove |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.scrollWheelZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'ph.gov.bfp.rosario.gis',
                      maxNativeZoom: 19,
                      retinaMode: RetinaMode.isHighDensity(context),
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: rosarioCenter,
                          radius: 1400,
                          useRadiusInMeter: true,
                          color: widget.accent.withValues(alpha: 0.10),
                          borderColor: widget.accent.withValues(alpha: 0.55),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: responseRoute,
                          color: AppColors.blue,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          (widget.ownOnly
                                  ? appDb
                                        .collection('incidents')
                                        .where(
                                          'uid',
                                          isEqualTo:
                                              appAuth.currentUser?.uid ?? '',
                                        )
                                  : appDb.collection('incidents'))
                              .snapshots(),
                      builder: (context, snapshot) {
                        final incidentPoints =
                            snapshot.data?.docs
                                .map(MapPoint.fromIncidentDocument)
                                .toList() ??
                            [];
                        final points = [fireStationMapPoint, ...incidentPoints];

                        return MarkerLayer(
                          markers: points
                              .map(
                                (point) => Marker(
                                  point: point.point,
                                  width: 54,
                                  height: 54,
                                  child: MapMarkerButton(
                                    point: point,
                                    onTap: () => _moveTo(point.point, 15.6),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: StatusPill(
                  label: 'Rosario live GIS',
                  icon: Icons.gps_fixed_rounded,
                  color: widget.accent,
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  children: [
                    MapControlButton(
                      tooltip: 'Zoom in',
                      icon: Icons.add_rounded,
                      onPressed: () => _zoomBy(1),
                    ),
                    const SizedBox(height: 8),
                    MapControlButton(
                      tooltip: 'Zoom out',
                      icon: Icons.remove_rounded,
                      onPressed: () => _zoomBy(-1),
                    ),
                    const SizedBox(height: 8),
                    MapControlButton(
                      tooltip: 'Center Rosario',
                      icon: Icons.my_location_rounded,
                      onPressed: () => _moveTo(rosarioCenter, 13.4),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: MapOverlayBar(
                  accent: widget.accent,
                  onRoutePressed: () =>
                      _moveTo(fireStationMapPoint.point, 15.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IncidentLocationPicker extends StatefulWidget {
  const IncidentLocationPicker({
    super.key,
    required this.selectedPoint,
    required this.accent,
    required this.onChanged,
    this.height = 320,
  });

  final LatLng? selectedPoint;
  final Color accent;
  final ValueChanged<LatLng> onChanged;
  final double height;

  @override
  State<IncidentLocationPicker> createState() => _IncidentLocationPickerState();
}

class _IncidentLocationPickerState extends State<IncidentLocationPicker> {
  // Gestures that move the map under the fixed center pin.
  static const _panSources = {
    MapEventSource.onDrag,
    MapEventSource.dragEnd,
    MapEventSource.onMultiFinger,
    MapEventSource.multiFingerEnd,
    MapEventSource.flingAnimationController,
    MapEventSource.doubleTapZoomAnimationController,
    MapEventSource.scrollWheel,
    MapEventSource.keyboard,
  };

  late final MapController _mapController;
  Timer? _settleTimer;
  bool _isPanning = false;

  /// The last point this picker reported, so the map does not jump when
  /// that same point comes back in as [IncidentLocationPicker.selectedPoint].
  LatLng? _reportedPoint;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(11, 19).toDouble();
    _mapController.move(camera.center, zoom);
  }

  void _report(LatLng point) {
    _reportedPoint = point;
    widget.onChanged(point);
  }

  /// The pin stays in the middle of the map, like ride-hailing apps: the
  /// citizen drags the map, and the spot under the pin is reported once the
  /// map stops moving.
  void _onMapEvent(MapEvent event) {
    if (!_panSources.contains(event.source)) return;
    if (!_isPanning) setState(() => _isPanning = true);
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _isPanning = false);
      _report(_mapController.camera.center);
    });
  }

  void _onTap(LatLng point) {
    _settleTimer?.cancel();
    _mapController.move(point, _mapController.camera.zoom);
    setState(() => _isPanning = false);
    _report(point);
  }

  @override
  void didUpdateWidget(IncidentLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bring pins placed by GPS or a place search under the center pin.
    final point = widget.selectedPoint;
    if (point != null &&
        point != oldWidget.selectedPoint &&
        point != _reportedPoint) {
      _settleTimer?.cancel();
      _isPanning = false;
      final zoom = math.max(_mapController.camera.zoom, 17).toDouble();
      _mapController.move(point, zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPoint = widget.selectedPoint;
    final isSet = selectedPoint != null;

    return Panel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: selectedPoint ?? rosarioCenter,
                    initialZoom: isSet ? 17 : 13.4,
                    minZoom: 11,
                    maxZoom: 19,
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: rosarioBounds,
                    ),
                    onTap: (_, point) => _onTap(point),
                    onMapEvent: _onMapEvent,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.drag |
                          InteractiveFlag.flingAnimation |
                          InteractiveFlag.pinchMove |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.scrollWheelZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'ph.gov.bfp.rosario.gis',
                      maxNativeZoom: 19,
                      retinaMode: RetinaMode.isHighDensity(context),
                    ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
              // Fixed center pin. Its tip marks the map center; it lifts while
              // the map moves and drops when the spot is picked.
              IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 150),
                        offset: Offset(0, _isPanning ? -0.25 : 0),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: isSet || _isPanning ? 1 : 0.55,
                          child: Icon(
                            Icons.location_pin,
                            color: widget.accent,
                            size: 48,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Mirrors the pin and shadow height so the pin tip, not
                      // the middle of the icon, sits on the map center.
                      const SizedBox(height: 52),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                right: 64,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(
                    label: isSet
                        ? 'Naka-pin na ang lugar'
                        : 'I-drag ang mapa sa lugar',
                    icon: isSet
                        ? Icons.location_on_rounded
                        : Icons.pan_tool_alt_rounded,
                    color: widget.accent,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  children: [
                    MapControlButton(
                      tooltip: 'Zoom in',
                      icon: Icons.add_rounded,
                      onPressed: () => _zoomBy(1),
                    ),
                    const SizedBox(height: 8),
                    MapControlButton(
                      tooltip: 'Zoom out',
                      icon: Icons.remove_rounded,
                      onPressed: () => _zoomBy(-1),
                    ),
                    if (isSet) ...[
                      const SizedBox(height: 8),
                      MapControlButton(
                        tooltip: 'Back to pin',
                        icon: Icons.center_focus_strong_rounded,
                        onPressed: () => _mapController.move(
                          selectedPoint,
                          math.max(_mapController.camera.zoom, 17).toDouble(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapMarkerButton extends StatelessWidget {
  const MapMarkerButton({super.key, required this.point, required this.onTap});

  final MapPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${point.title}\n${point.subtitle}',
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: point.color.withValues(alpha: 0.18),
            border: Border.all(color: point.color, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(point.icon, color: point.color, size: 28),
        ),
      ),
    );
  }
}

class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

class MapOverlayBar extends StatelessWidget {
  const MapOverlayBar({
    super.key,
    required this.accent,
    required this.onRoutePressed,
  });

  final Color accent;
  final VoidCallback onRoutePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  StatusPill(
                    label: 'OSM tiles',
                    icon: Icons.public_rounded,
                    color: AppColors.teal,
                    dense: true,
                  ),
                  StatusPill(
                    label: 'Response route',
                    icon: Icons.route_rounded,
                    color: AppColors.blue,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onRoutePressed,
              icon: const Icon(Icons.route_rounded),
              label: const Text('Route'),
              style: FilledButton.styleFrom(backgroundColor: accent),
            ),
          ],
        ),
      ),
    );
  }
}
