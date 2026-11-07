import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/bible_map_data.dart';
import '../models/local_bookmark.dart';
import '../providers/bible_provider.dart';

class MapScreen extends StatefulWidget {
  final String? initialPathId;
  final String? initialPoiId;

  const MapScreen({
    Key? key,
    this.initialPathId,
    this.initialPoiId,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _apiOrigin = 'https://api.bybl.dev';

  GoogleMapController? _mapController;
  late String _selectedPathId;
  String? _selectedPoiId;
  MapPOI? _activePoi;
  bool _hasHandledInitialSelection = false;

  @override
  void initState() {
    super.initState();
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    _selectedPathId = _resolveInitialPathId(bibleProvider.readChapters);
    _selectedPoiId = widget.initialPoiId;

    // Sync latest map paths & POI descriptions/images from gofyrAdmin backend
    unawaited(bibleProvider.fetchMapData(forceRefresh: true));
  }

  String _resolveInitialPathId(Set<String> readChapters) {
    final paths = BibleMapData.paths;
    if (paths.isEmpty) return 'exodus';

    if (widget.initialPathId != null) {
      final match = paths.where((p) => p.id == widget.initialPathId);
      if (match.isNotEmpty) return match.first.id;
    }

    if (widget.initialPoiId != null) {
      for (final path in paths) {
        if (path.pois.any((poi) => poi.id == widget.initialPoiId)) {
          return path.id;
        }
      }
    }

    // Prefer the first path that has at least one unlocked POI
    for (final path in paths) {
      if (path.pois.any((poi) => _isPoiUnlocked(poi, readChapters))) {
        return path.id;
      }
    }

    return paths.first.id;
  }

  BibleMapPath get _currentPath {
    final paths = BibleMapData.paths;
    for (final path in paths) {
      if (path.id == _selectedPathId) return path;
    }
    return paths.first;
  }

  bool _isPoiUnlocked(MapPOI poi, Set<String> readChapters) {
    return poi.requiredChapterIds.isEmpty ||
        poi.requiredChapterIds.every((id) => readChapters.contains(id));
  }

  int _unlockedCountForPath(BibleMapPath path, Set<String> readChapters) {
    return path.pois.where((poi) => _isPoiUnlocked(poi, readChapters)).length;
  }

  void _closePoiDrawer() {
    if (_activePoi != null || _selectedPoiId != null) {
      setState(() {
        _activePoi = null;
        _selectedPoiId = null;
      });
    }
  }

  void _toggleOrSelectPoi(MapPOI poi, {bool animateCamera = false}) {
    if (_activePoi?.id == poi.id) {
      _closePoiDrawer();
      return;
    }
    _focusPoi(poi, openSheet: true, animateCamera: animateCamera);
  }

  Set<Marker> _createMarkers(BibleMapPath path, Set<String> readChapters) {
    final markers = <Marker>{};
    for (final poi in path.pois) {
      final isUnlocked = _isPoiUnlocked(poi, readChapters);
      if (!isUnlocked) continue; // Only show unlocked endpoints

      final isSelected = _selectedPoiId == poi.id && _activePoi != null;

      markers.add(
        Marker(
          markerId: MarkerId(poi.id),
          position: poi.location,
          consumeTapEvents: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
          ),
          onTap: () => _toggleOrSelectPoi(poi, animateCamera: false),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _createPolylines(BibleMapPath path, Set<String> readChapters) {
    final unlockedPois =
        path.pois.where((poi) => _isPoiUnlocked(poi, readChapters)).toList();
    if (unlockedPois.length < 2 || path.points.length < 2) {
      return const {};
    }

    int maxPointIndex = 0;
    for (final poi in unlockedPois) {
      if (poi.pathPointIndex > maxPointIndex) {
        maxPointIndex = poi.pathPointIndex;
      }
    }

    final clampedEnd = (maxPointIndex + 1).clamp(2, path.points.length);
    final visiblePoints = path.points.sublist(0, clampedEnd);

    return {
      Polyline(
        polylineId: PolylineId('path_${path.id}'),
        points: visiblePoints,
        color: Colors.amberAccent.shade400,
        width: 4,
      ),
    };
  }

  Future<void> _focusPoi(
    MapPOI poi, {
    bool openSheet = true,
    bool animateCamera = true,
  }) async {
    if (!mounted) return;
    setState(() {
      _selectedPoiId = poi.id;
      if (openSheet) {
        _activePoi = poi;
      }
    });

    if (animateCamera) {
      final controller = _mapController;
      if (controller != null) {
        try {
          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(poi.location, 8.2),
          );
        } catch (_) {}
      }
    }
  }

  void _selectPath(BibleMapPath path, Set<String> readChapters) {
    setState(() {
      _selectedPathId = path.id;
      _selectedPoiId = null;
      _activePoi = null;
    });

    final unlockedPois =
        path.pois.where((poi) => _isPoiUnlocked(poi, readChapters)).toList();
    final target = unlockedPois.isNotEmpty
        ? unlockedPois.last.location
        : (path.points.isNotEmpty
            ? path.points.first
            : const LatLng(31.7683, 35.2137));

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 6.2),
    );
  }

  Widget _buildPoiImage(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final isNetwork = trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/uploads/') ||
        trimmed.startsWith('/admin/uploads/');

    final resolvedUrl =
        trimmed.startsWith('/') ? '$_apiOrigin$trimmed' : trimmed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isNetwork
            ? Image.network(
                resolvedUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              )
            : Image.asset(
                trimmed,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
      ),
    );
  }

  Widget _buildPoiBottomDrawer(MapPOI poi, bool isUnlocked) {
    final formattedRefs = poi.requiredChapterIds
        .map((id) => BibleReferenceFormatter.format(id))
        .toList();

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 150) {
          _closePoiDrawer();
        }
      },
      child: Material(
        elevation: 12,
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (poi.imageUrl.trim().isNotEmpty)
                  _buildPoiImage(poi.imageUrl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        poi.title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (formattedRefs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            formattedRefs.join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isUnlocked
                      ? poi.description
                      : 'Keep reading to unlock this location!',
                  style: const TextStyle(fontSize: 15.5, height: 1.45),
                ),
                if (!isUnlocked && formattedRefs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Required Chapters:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...formattedRefs.map(
                    (ref) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $ref'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleProvider>(
      builder: (context, bibleProvider, child) {
        final paths = BibleMapData.paths;
        final currentPath = _currentPath;
        final readChapters = bibleProvider.readChapters;
        final unlockedPois = currentPath.pois
            .where((poi) => _isPoiUnlocked(poi, readChapters))
            .toList();

        // Determine initial camera target
        LatLng initialTarget = currentPath.points.isNotEmpty
            ? currentPath.points.first
            : const LatLng(31.7683, 35.2137);
        double initialZoom = 6.0;

        if (widget.initialPoiId != null) {
          for (final poi in currentPath.pois) {
            if (poi.id == widget.initialPoiId) {
              initialTarget = poi.location;
              initialZoom = 8.2;
              break;
            }
          }
        } else if (unlockedPois.isNotEmpty) {
          initialTarget = unlockedPois.last.location;
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentPath.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${unlockedPois.length}/${currentPath.pois.length} locations unlocked',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                            .appBarTheme
                            .foregroundColor
                            ?.withOpacity(0.75) ??
                        Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              GoogleMap(
                mapType: MapType.hybrid,
                onTap: (_) => _closePoiDrawer(),
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (!_hasHandledInitialSelection &&
                      widget.initialPoiId != null) {
                    _hasHandledInitialSelection = true;
                    MapPOI? targetPoi;
                    for (final poi in currentPath.pois) {
                      if (poi.id == widget.initialPoiId) {
                        targetPoi = poi;
                        break;
                      }
                    }
                    if (targetPoi != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _focusPoi(
                            targetPoi!,
                            openSheet: true,
                            animateCamera: true,
                          );
                        }
                      });
                    }
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: initialZoom,
                ),
                markers: _createMarkers(currentPath, readChapters),
                polylines: _createPolylines(currentPath, readChapters),
                myLocationButtonEnabled: false,
              ),

              // Top journey selector pills
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: paths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = paths[index];
                      final isSelected = path.id == currentPath.id;
                      final unlockedCount =
                          _unlockedCountForPath(path, readChapters);
                      return ChoiceChip(
                        label: Text(
                          '${path.name} ($unlockedCount/${path.pois.length})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _selectPath(path, readChapters),
                      );
                    },
                  ),
                ),
              ),

              // Bottom unlocked POI quick-jump strip (visible when drawer is closed)
              if (unlockedPois.isNotEmpty && _activePoi == null)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: unlockedPois.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final poi = unlockedPois[index];
                        final isSelected = _selectedPoiId == poi.id;
                        return ActionChip(
                          avatar: Icon(
                            Icons.place,
                            size: 16,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.redAccent,
                          ),
                          label: Text(
                            poi.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          onPressed: () =>
                              _toggleOrSelectPoi(poi, animateCamera: true),
                        );
                      },
                    ),
                  ),
                ),

              // Inline bottom drawer for active POI
              if (_activePoi != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildPoiBottomDrawer(
                    _activePoi!,
                    _isPoiUnlocked(_activePoi!, readChapters),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
