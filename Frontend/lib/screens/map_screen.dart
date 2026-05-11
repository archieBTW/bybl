import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/bible_map_data.dart';
import '../providers/bible_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final BibleMapPath currentPath =
      BibleMapData.paths.first; // Currently hardcoded to first path

  Set<Marker> _createMarkers(Set<String> readChapters) {
    return currentPath.pois
        .map((poi) {
          // Check if unlocked
          // POI is unlocked if its required chapters are empty OR if all required chapters are in readChapters
          bool isUnlocked = poi.requiredChapterIds.isEmpty ||
              poi.requiredChapterIds.every((id) => readChapters.contains(id));

          if (!isUnlocked) return null; // Hide locked POIs

          return Marker(
            markerId: MarkerId(poi.id),
            position: poi.location,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isUnlocked ? BitmapDescriptor.hueRed : BitmapDescriptor.hueViolet,
            ),
            onTap: () => _showPOIDetails(poi, isUnlocked),
          );
        })
        .where((m) => m != null)
        .cast<Marker>()
        .toSet();
  }

  void _showPOIDetails(MapPOI poi, bool isUnlocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poi.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  poi.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(), // Hide if asset missing
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              poi.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isUnlocked
                  ? poi.description
                  : "Keep reading to unlock this location!",
              style: const TextStyle(fontSize: 16),
            ),
            if (!isUnlocked && poi.requiredChapterIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Required Chapters:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...poi.requiredChapterIds.map((id) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("• $id"),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentPath.name),
      ),
      body: Consumer<BibleProvider>(
        builder: (context, bibleProvider, child) {
          return GoogleMap(
            mapType: MapType.hybrid,
            onMapCreated: (controller) {
              mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: currentPath.points.first,
              zoom: 6.0,
            ),
            markers: _createMarkers(bibleProvider.readChapters),
            myLocationButtonEnabled: false,
          );
        },
      ),
    );
  }
}
