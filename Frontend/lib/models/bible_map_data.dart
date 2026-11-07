import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPOI {
  final String id;
  final String title;
  final String description;
  final LatLng location;
  final String imageUrl;
  final List<String> requiredChapterIds; // Chapters that unlock this POI
  final String unlockedChapterId; // Chapter to navigate to when clicked
  final int pathPointIndex; // Index in the path's points list up to which the path is drawn when this POI is unlocked

  const MapPOI({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.imageUrl,
    required this.requiredChapterIds,
    required this.unlockedChapterId,
    required this.pathPointIndex,
  });

  factory MapPOI.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['ID'] ?? '').toString();
    final rawReq = json['requiredChapterIds'];
    List<String> reqChapters = const [];
    if (rawReq is List) {
      reqChapters = rawReq.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    } else if (rawReq is String && rawReq.trim().isNotEmpty) {
      reqChapters = rawReq.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    }
    final lat = (json['latitude'] is num)
        ? (json['latitude'] as num).toDouble()
        : double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0;
    final lng = (json['longitude'] is num)
        ? (json['longitude'] as num).toDouble()
        : double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0;
    final pointIdx = (json['pathPointIndex'] is num)
        ? (json['pathPointIndex'] as num).toInt()
        : int.tryParse(json['pathPointIndex']?.toString() ?? '0') ?? 0;

    return MapPOI(
      id: rawId,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      location: LatLng(lat, lng),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      requiredChapterIds: reqChapters,
      unlockedChapterId: (json['unlockedChapterId'] ?? '').toString(),
      pathPointIndex: pointIdx,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'imageUrl': imageUrl,
        'requiredChapterIds': requiredChapterIds,
        'unlockedChapterId': unlockedChapterId,
        'pathPointIndex': pathPointIndex,
      };
}

class BibleMapPath {
  final String id;
  final String name;
  final String description;
  final List<LatLng> points;
  final List<MapPOI> pois;

  const BibleMapPath({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.pois,
  });

  factory BibleMapPath.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final List<LatLng> parsedPoints = [];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is Map) {
          final lat = (p['latitude'] is num)
              ? (p['latitude'] as num).toDouble()
              : double.tryParse(p['latitude']?.toString() ?? '0') ?? 0.0;
          final lng = (p['longitude'] is num)
              ? (p['longitude'] as num).toDouble()
              : double.tryParse(p['longitude']?.toString() ?? '0') ?? 0.0;
          parsedPoints.add(LatLng(lat, lng));
        }
      }
    }

    final rawPois = json['pois'];
    final List<MapPOI> parsedPois = [];
    if (rawPois is List) {
      for (final poi in rawPois) {
        if (poi is Map<String, dynamic>) {
          parsedPois.add(MapPOI.fromJson(poi));
        } else if (poi is Map) {
          parsedPois.add(MapPOI.fromJson(Map<String, dynamic>.from(poi)));
        }
      }
    }

    return BibleMapPath(
      id: (json['id'] ?? json['ID'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      points: parsedPoints,
      pois: parsedPois,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'points': points
            .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
            .toList(),
        'pois': pois.map((poi) => poi.toJson()).toList(),
      };
}

class BibleMapData {
  static List<BibleMapPath> paths = List<BibleMapPath>.from(defaultPaths);

  static void updatePathsFromJson(List<dynamic> rawList) {
    final parsed = <BibleMapPath>[];
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        final path = BibleMapPath.fromJson(item);
        if (path.id.isNotEmpty && path.pois.isNotEmpty) {
          parsed.add(path);
        }
      } else if (item is Map) {
        final path = BibleMapPath.fromJson(Map<String, dynamic>.from(item));
        if (path.id.isNotEmpty && path.pois.isNotEmpty) {
          parsed.add(path);
        }
      }
    }
    if (parsed.isNotEmpty) {
      paths = parsed;
    }
  }

  static const List<BibleMapPath> defaultPaths = [
    // 1. Journey of Abraham
    BibleMapPath(
      id: 'abrahams_journey',
      name: 'Journey of Abraham',
      description: "Abram's call from Mesopotamia to the Promised Land of Canaan (Genesis 11–22).",
      points: [
        LatLng(30.9625, 46.1031), // 0: Ur of the Chaldeans
        LatLng(36.8600, 39.0314), // 1: Haran
        LatLng(32.2136, 35.2819), // 2: Shechem
        LatLng(31.9306, 35.2219), // 3: Bethel
        LatLng(31.5326, 35.0998), // 4: Hebron (Mamre)
        LatLng(31.2450, 34.8408), // 5: Beersheba
        LatLng(31.7780, 35.2354), // 6: Mount Moriah
      ],
      pois: [
        MapPOI(
          id: 'ur_chaldeans',
          title: 'Ur of the Chaldeans',
          description: 'Ancient Mesopotamian city from which Terah and Abram set out toward the land of Canaan.',
          location: LatLng(30.9625, 46.1031),
          imageUrl: '',
          requiredChapterIds: ['GEN.11'],
          unlockedChapterId: 'GEN.11',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'haran',
          title: 'Haran',
          description: 'Where the Lord called Abram: "Go from your country, your people and your father\'s household to the land I will show you."',
          location: LatLng(36.8600, 39.0314),
          imageUrl: '',
          requiredChapterIds: ['GEN.12'],
          unlockedChapterId: 'GEN.12',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'shechem_abram',
          title: 'Shechem (Oak of Moreh)',
          description: 'Abram\'s first stop in Canaan, where the Lord appeared to him and promised this land to his offspring.',
          location: LatLng(32.2136, 35.2819),
          imageUrl: '',
          requiredChapterIds: ['GEN.12'],
          unlockedChapterId: 'GEN.12',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'bethel_abram',
          title: 'Bethel & Ai',
          description: 'Abram pitched his tent between Bethel and Ai, built an altar, and called on the name of the Lord.',
          location: LatLng(31.9306, 35.2219),
          imageUrl: '',
          requiredChapterIds: ['GEN.13'],
          unlockedChapterId: 'GEN.13',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'hebron_mamre',
          title: 'Oaks of Mamre (Hebron)',
          description: 'Where Abraham settled, built an altar to the Lord, and received the covenant promise.',
          location: LatLng(31.5326, 35.0998),
          imageUrl: '',
          requiredChapterIds: ['GEN.15'],
          unlockedChapterId: 'GEN.15',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'beersheba_abraham',
          title: 'Beersheba',
          description: 'The "Well of the Oath," where Abraham planted a tamarisk tree and called on the name of the Eternal God.',
          location: LatLng(31.2450, 34.8408),
          imageUrl: '',
          requiredChapterIds: ['GEN.21'],
          unlockedChapterId: 'GEN.21',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'mount_moriah',
          title: 'Mount Moriah',
          description: 'Where Abraham\'s faith was tested with Isaac and the Lord provided a ram in his place ("The Lord Will Provide").',
          location: LatLng(31.7780, 35.2354),
          imageUrl: '',
          requiredChapterIds: ['GEN.22'],
          unlockedChapterId: 'GEN.22',
          pathPointIndex: 6,
        ),
      ],
    ),

    // 2. The Exodus
    BibleMapPath(
      id: 'exodus',
      name: 'The Exodus',
      description: 'The journey of the Israelites from slavery in Egypt to the Promised Land.',
      points: [
        LatLng(30.7889, 31.8333), // 0: Rameses
        LatLng(30.5567, 32.0900), // 1: Succoth
        LatLng(30.5852, 32.2654), // 2: Etham
        LatLng(30.2981, 32.4214), // 3: Pi-hahiroth
        LatLng(29.9668, 32.5498), // 4: Red Sea Crossing
        LatLng(29.3500, 32.9333), // 5: Marah
        LatLng(29.2500, 32.9833), // 6: Elim
        LatLng(29.0000, 33.2000), // 7: Wilderness of Sin
        LatLng(28.7264, 33.6214), // 8: Rephidim
        LatLng(28.5392, 33.9750), // 9: Mount Sinai
        LatLng(28.6800, 34.1000), // 10: Taberah
        LatLng(28.7800, 34.2200), // 11: Kibroth Hattaavah
        LatLng(28.9167, 34.4000), // 12: Hazeroth
        LatLng(30.6483, 34.4222), // 13: Kadesh Barnea
        LatLng(29.5350, 34.9519), // 14: Ezion Geber
        LatLng(30.3167, 35.4000), // 15: Mount Hor
        LatLng(30.1500, 35.6000), // 16: Punon (Bronze Snake)
        LatLng(31.4667, 35.7667), // 17: Arnon River
        LatLng(31.7667, 35.7250), // 18: Mount Nebo
        LatLng(31.8558, 35.4600), // 19: Jericho
      ],
      pois: [
        MapPOI(
          id: 'start_egypt',
          title: 'Goshen (Rameses)',
          description: 'The Israelites lived here in slavery before the Exodus.',
          location: LatLng(30.7889, 31.8333),
          imageUrl: '',
          requiredChapterIds: ['EXO.1'],
          unlockedChapterId: 'EXO.1',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'succoth',
          title: 'Succoth',
          description: 'The first stop of the Israelites after leaving Rameses.',
          location: LatLng(30.5567, 32.0900),
          imageUrl: '',
          requiredChapterIds: ['EXO.12'],
          unlockedChapterId: 'EXO.12',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'etham',
          title: 'Etham',
          description: 'On the edge of the wilderness, where the Lord went before them in a pillar of cloud and fire.',
          location: LatLng(30.5852, 32.2654),
          imageUrl: '',
          requiredChapterIds: ['EXO.13'],
          unlockedChapterId: 'EXO.13',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'pi_hahiroth',
          title: 'Pi-hahiroth',
          description: 'Camped by the sea before Pharaoh\'s army overtook them.',
          location: LatLng(30.2981, 32.4214),
          imageUrl: '',
          requiredChapterIds: ['EXO.14'],
          unlockedChapterId: 'EXO.14',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'crossing_sea',
          title: 'Crossing the Red Sea',
          description: 'Moses parts the waters, and the Israelites cross on dry ground.',
          location: LatLng(29.9668, 32.5498),
          imageUrl: '',
          requiredChapterIds: ['EXO.14'],
          unlockedChapterId: 'EXO.14',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'marah',
          title: 'Marah',
          description: 'The place of bitter water, made sweet when Moses threw a piece of wood into it.',
          location: LatLng(29.3500, 32.9333),
          imageUrl: '',
          requiredChapterIds: ['EXO.15'],
          unlockedChapterId: 'EXO.15',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'elim',
          title: 'Elim',
          description: 'An oasis with twelve springs and seventy palm trees where the Israelites camped.',
          location: LatLng(29.2500, 32.9833),
          imageUrl: '',
          requiredChapterIds: ['EXO.15'],
          unlockedChapterId: 'EXO.15',
          pathPointIndex: 6,
        ),
        MapPOI(
          id: 'wilderness_sin',
          title: 'Wilderness of Sin',
          description: 'Here God first provided Manna and Quail from heaven to feed the hungry Israelites.',
          location: LatLng(29.0000, 33.2000),
          imageUrl: '',
          requiredChapterIds: ['EXO.16'],
          unlockedChapterId: 'EXO.16',
          pathPointIndex: 7,
        ),
        MapPOI(
          id: 'rephidim',
          title: 'Rephidim',
          description: 'Moses struck the rock for water and Joshua defeated the Amalekites while Moses held up his hands.',
          location: LatLng(28.7264, 33.6214),
          imageUrl: '',
          requiredChapterIds: ['EXO.17'],
          unlockedChapterId: 'EXO.17',
          pathPointIndex: 8,
        ),
        MapPOI(
          id: 'mt_sinai',
          title: 'Mount Sinai',
          description: 'God gives the Ten Commandments and the Covenant Law to Moses.',
          location: LatLng(28.5392, 33.9750),
          imageUrl: '',
          requiredChapterIds: ['EXO.19', 'EXO.20'],
          unlockedChapterId: 'EXO.20',
          pathPointIndex: 9,
        ),
        MapPOI(
          id: 'taberah',
          title: 'Taberah',
          description: 'Where fire from the Lord burned among the outskirts of the camp because of the people\'s complaining.',
          location: LatLng(28.6800, 34.1000),
          imageUrl: '',
          requiredChapterIds: ['NUM.11'],
          unlockedChapterId: 'NUM.11',
          pathPointIndex: 10,
        ),
        MapPOI(
          id: 'kibroth_hattaavah',
          title: 'Kibroth Hattaavah',
          description: '"Graves of Craving," where the people craved meat and a plague struck while the quail was still between their teeth.',
          location: LatLng(28.7800, 34.2200),
          imageUrl: '',
          requiredChapterIds: ['NUM.11'],
          unlockedChapterId: 'NUM.11',
          pathPointIndex: 11,
        ),
        MapPOI(
          id: 'hazeroth',
          title: 'Hazeroth',
          description: 'Miriam and Aaron spoke against Moses; Miriam was struck with leprosy for seven days.',
          location: LatLng(28.9167, 34.4000),
          imageUrl: '',
          requiredChapterIds: ['NUM.12'],
          unlockedChapterId: 'NUM.12',
          pathPointIndex: 12,
        ),
        MapPOI(
          id: 'kadesh_barnea',
          title: 'Kadesh Barnea',
          description: 'From here, twelve spies were sent into Canaan. Because of the people\'s lack of faith, they wandered for 40 years.',
          location: LatLng(30.6483, 34.4222),
          imageUrl: '',
          requiredChapterIds: ['NUM.13', 'NUM.14'],
          unlockedChapterId: 'NUM.13',
          pathPointIndex: 13,
        ),
        MapPOI(
          id: 'ezion_geber',
          title: 'Ezion Geber',
          description: 'After years of wandering, Israel bypassed Edom by way of the Red Sea at Ezion Geber.',
          location: LatLng(29.5350, 34.9519),
          imageUrl: '',
          requiredChapterIds: ['DEU.2'],
          unlockedChapterId: 'DEU.2',
          pathPointIndex: 14,
        ),
        MapPOI(
          id: 'mount_hor',
          title: 'Mount Hor',
          description: 'On the border of Edom, Aaron died here and his priestly garments were passed to his son Eleazar.',
          location: LatLng(30.3167, 35.4000),
          imageUrl: '',
          requiredChapterIds: ['NUM.20'],
          unlockedChapterId: 'NUM.20',
          pathPointIndex: 15,
        ),
        MapPOI(
          id: 'bronze_serpent',
          title: 'Wilderness of Edom (Bronze Snake)',
          description: 'Moses lifted up the bronze snake on a pole so that anyone bitten by venomous snakes could look at it and live.',
          location: LatLng(30.1500, 35.6000),
          imageUrl: '',
          requiredChapterIds: ['NUM.21'],
          unlockedChapterId: 'NUM.21',
          pathPointIndex: 16,
        ),
        MapPOI(
          id: 'arnon_river',
          title: 'Arnon Gorge',
          description: 'Israel crossed the Arnon River and defeated Sihon king of the Amorites, taking possession of the eastern bank.',
          location: LatLng(31.4667, 35.7667),
          imageUrl: '',
          requiredChapterIds: ['NUM.21'],
          unlockedChapterId: 'NUM.21',
          pathPointIndex: 17,
        ),
        MapPOI(
          id: 'mount_nebo',
          title: 'Mount Nebo',
          description: 'Moses viewed the Promised Land from this peak before his death.',
          location: LatLng(31.7667, 35.7250),
          imageUrl: '',
          requiredChapterIds: ['DEU.34'],
          unlockedChapterId: 'DEU.34',
          pathPointIndex: 18,
        ),
        MapPOI(
          id: 'jericho_arrival',
          title: 'Plains of Moab (Across from Jericho)',
          description: 'The Israelites camp across the Jordan from Jericho, preparing to enter the Promised Land.',
          location: LatLng(31.8558, 35.4600),
          imageUrl: '',
          requiredChapterIds: ['JOS.1'],
          unlockedChapterId: 'JOS.1',
          pathPointIndex: 19,
        ),
      ],
    ),

    // 3. Conquest of Canaan
    BibleMapPath(
      id: 'joshua_conquest',
      name: 'Conquest of Canaan',
      description: 'Joshua leads Israel across the Jordan River to claim the Promised Land (Joshua 3–11).',
      points: [
        LatLng(31.8389, 35.5472), // 0: Jordan River Crossing
        LatLng(31.8600, 35.4800), // 1: Gilgal
        LatLng(31.8711, 35.4442), // 2: Jericho
        LatLng(31.9169, 35.2611), // 3: Ai
        LatLng(32.2136, 35.2819), // 4: Mount Ebal & Mount Gerizim
        LatLng(31.8475, 35.1844), // 5: Gibeon
        LatLng(33.0169, 35.5681), // 6: Hazor
      ],
      pois: [
        MapPOI(
          id: 'jordan_crossing',
          title: 'Crossing the Jordan River',
          description: 'The waters of the Jordan stood in a heap as the priests bearing the Ark of the Covenant stepped into the river.',
          location: LatLng(31.8389, 35.5472),
          imageUrl: '',
          requiredChapterIds: ['JOS.3'],
          unlockedChapterId: 'JOS.3',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'gilgal_stones',
          title: 'Gilgal (Twelve Memorial Stones)',
          description: 'Joshua set up twelve stones taken from the Jordan River as a lasting memorial to the Lord\'s faithfulness.',
          location: LatLng(31.8600, 35.4800),
          imageUrl: '',
          requiredChapterIds: ['JOS.4'],
          unlockedChapterId: 'JOS.4',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'walls_of_jericho',
          title: 'Walls of Jericho',
          description: 'After marching around the city for seven days, the priests blew the trumpets, the people shouted, and the walls fell flat.',
          location: LatLng(31.8711, 35.4442),
          imageUrl: '',
          requiredChapterIds: ['JOS.6'],
          unlockedChapterId: 'JOS.6',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'battle_of_ai',
          title: 'Ai',
          description: 'After repenting of Achan\'s sin, Israel captured Ai through the ambush strategy given by the Lord.',
          location: LatLng(31.9169, 35.2611),
          imageUrl: '',
          requiredChapterIds: ['JOS.8'],
          unlockedChapterId: 'JOS.8',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'mount_ebal_altar',
          title: 'Mount Ebal & Mount Gerizim',
          description: 'Joshua built an altar on Mount Ebal and read all the words of the Law—the blessings and curses—before all Israel.',
          location: LatLng(32.2136, 35.2819),
          imageUrl: '',
          requiredChapterIds: ['JOS.8'],
          unlockedChapterId: 'JOS.8',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'gibeon_sun_stands_still',
          title: 'Valley of Gibeon',
          description: 'Joshua prayed to the Lord and the sun stood still over Gibeon while Israel defended the city against five Amorite kings.',
          location: LatLng(31.8475, 35.1844),
          imageUrl: '',
          requiredChapterIds: ['JOS.10'],
          unlockedChapterId: 'JOS.10',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'hazor_northern_campaign',
          title: 'Hazor',
          description: 'Head of all the northern kingdoms defeated by Joshua at the waters of Merom, completing the northern campaign.',
          location: LatLng(33.0169, 35.5681),
          imageUrl: '',
          requiredChapterIds: ['JOS.11'],
          unlockedChapterId: 'JOS.11',
          pathPointIndex: 6,
        ),
      ],
    ),

    // 4. Life of David
    BibleMapPath(
      id: 'life_of_david',
      name: 'Life of David',
      description: 'From shepherd boy in Bethlehem to anointed King over all Israel (1 Samuel 16 – 2 Samuel 6).',
      points: [
        LatLng(31.7054, 35.2024), // 0: Bethlehem
        LatLng(31.6906, 34.9567), // 1: Valley of Elah
        LatLng(31.6486, 35.0394), // 2: Cave of Adullam
        LatLng(31.4642, 35.3883), // 3: En Gedi
        LatLng(31.3894, 34.6806), // 4: Ziklag
        LatLng(31.5326, 35.0998), // 5: Hebron
        LatLng(31.7736, 35.2356), // 6: City of David (Jerusalem)
      ],
      pois: [
        MapPOI(
          id: 'bethlehem_david',
          title: 'Bethlehem (David Anointed)',
          description: 'The prophet Samuel anointed Jesse\'s youngest son David with oil, and the Spirit of the Lord came powerfully upon him.',
          location: LatLng(31.7054, 35.2024),
          imageUrl: '',
          requiredChapterIds: ['1SA.16'],
          unlockedChapterId: '1SA.16',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'valley_of_elah',
          title: 'Valley of Elah (David & Goliath)',
          description: 'Armed with a sling, five smooth stones, and faith in the Lord Almighty, David defeated the Philistine giant Goliath.',
          location: LatLng(31.6906, 34.9567),
          imageUrl: '',
          requiredChapterIds: ['1SA.17'],
          unlockedChapterId: '1SA.17',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'cave_of_adullam',
          title: 'Cave of Adullam',
          description: 'Fleeing from King Saul, David took refuge in the cave of Adullam where four hundred distressed men gathered around him.',
          location: LatLng(31.6486, 35.0394),
          imageUrl: '',
          requiredChapterIds: ['1SA.22'],
          unlockedChapterId: '1SA.22',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'en_gedi_david',
          title: 'Strongholds of En Gedi',
          description: 'In a cave at En Gedi, David spared Saul\'s life, cutting only a corner of the king\'s robe.',
          location: LatLng(31.4642, 35.3883),
          imageUrl: '',
          requiredChapterIds: ['1SA.24'],
          unlockedChapterId: '1SA.24',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'ziklag_david',
          title: 'Ziklag',
          description: 'When raiders burned Ziklag, David strengthened himself in the Lord his God and recovered everything that had been taken.',
          location: LatLng(31.3894, 34.6806),
          imageUrl: '',
          requiredChapterIds: ['1SA.30'],
          unlockedChapterId: '1SA.30',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'hebron_king_david',
          title: 'Hebron (Crowned King)',
          description: 'David was anointed king over Judah at Hebron, and later over all the tribes of Israel.',
          location: LatLng(31.5326, 35.0998),
          imageUrl: '',
          requiredChapterIds: ['2SA.2'],
          unlockedChapterId: '2SA.2',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'city_of_david_jerusalem',
          title: 'City of David (Jerusalem)',
          description: 'David captured the fortress of Zion, established Jerusalem as his capital, and brought the Ark of the Covenant into the city with joy.',
          location: LatLng(31.7736, 35.2356),
          imageUrl: '',
          requiredChapterIds: ['2SA.5', '2SA.6'],
          unlockedChapterId: '2SA.6',
          pathPointIndex: 6,
        ),
      ],
    ),

    // 5. Prophets Elijah & Elisha
    BibleMapPath(
      id: 'elijah_and_elisha',
      name: 'Prophets Elijah & Elisha',
      description: 'Miracles and prophetic ministry across Israel and beyond (1 Kings 17 – 2 Kings 5).',
      points: [
        LatLng(32.3833, 35.6333), // 0: Kerith Ravine
        LatLng(33.4478, 35.2975), // 1: Zarephath
        LatLng(32.6606, 35.0956), // 2: Mount Carmel
        LatLng(28.5392, 33.9750), // 3: Mount Horeb
        LatLng(31.8389, 35.5472), // 4: Jordan River (Chariot of Fire)
        LatLng(32.6047, 35.3358), // 5: Shunem
        LatLng(32.2764, 35.1908), // 6: Samaria / Jordan (Naaman)
      ],
      pois: [
        MapPOI(
          id: 'kerith_ravine',
          title: 'Kerith Ravine',
          description: 'During the drought in Israel, Elijah hid by the brook Kerith where ravens brought him bread and meat morning and evening.',
          location: LatLng(32.3833, 35.6333),
          imageUrl: '',
          requiredChapterIds: ['1KI.17'],
          unlockedChapterId: '1KI.17',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'zarephath_widow',
          title: 'Zarephath',
          description: 'At the widow\'s house in Zarephath, the jar of flour was not used up and the jug of oil did not run dry, and Elijah raised her son.',
          location: LatLng(33.4478, 35.2975),
          imageUrl: '',
          requiredChapterIds: ['1KI.17'],
          unlockedChapterId: '1KI.17',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'mount_carmel_fire',
          title: 'Mount Carmel',
          description: 'Fire of the Lord fell from heaven and consumed Elijah\'s water-soaked sacrifice, proving the Lord alone is God.',
          location: LatLng(32.6606, 35.0956),
          imageUrl: '',
          requiredChapterIds: ['1KI.18'],
          unlockedChapterId: '1KI.18',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'horeb_gentle_whisper',
          title: 'Mount Horeb (Gentle Whisper)',
          description: 'After wind, earthquake, and fire, the Lord spoke to a discouraged Elijah in a gentle whisper.',
          location: LatLng(28.5392, 33.9750),
          imageUrl: '',
          requiredChapterIds: ['1KI.19'],
          unlockedChapterId: '1KI.19',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'jordan_chariot_of_fire',
          title: 'Jordan River (Chariot of Fire)',
          description: 'A chariot of fire and horses of fire separated Elijah and Elisha, and Elijah went up to heaven in a whirlwind.',
          location: LatLng(31.8389, 35.5472),
          imageUrl: '',
          requiredChapterIds: ['2KI.2'],
          unlockedChapterId: '2KI.2',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'shunem_elisha',
          title: 'Shunem',
          description: 'Where a hospitable woman built an upper room for Elisha, and through Elisha\'s prayer her son was restored to life.',
          location: LatLng(32.6047, 35.3358),
          imageUrl: '',
          requiredChapterIds: ['2KI.4'],
          unlockedChapterId: '2KI.4',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'naaman_healed',
          title: 'Samaria & the Jordan (Naaman Healed)',
          description: 'At Elisha\'s word, the Aramean commander Naaman dipped seven times in the Jordan and was cleansed of leprosy.',
          location: LatLng(32.2764, 35.1908),
          imageUrl: '',
          requiredChapterIds: ['2KI.5'],
          unlockedChapterId: '2KI.5',
          pathPointIndex: 6,
        ),
      ],
    ),

    // 6. Life & Ministry of Jesus
    BibleMapPath(
      id: 'ministry_of_jesus',
      name: 'Life & Ministry of Jesus',
      description: 'Key places in the earthly life, miracles, death, and resurrection of Jesus Christ.',
      points: [
        LatLng(31.7054, 35.2024), // 0: Bethlehem
        LatLng(32.7021, 35.2978), // 1: Nazareth
        LatLng(31.8372, 35.5469), // 2: Bethany Beyond the Jordan (Baptism)
        LatLng(32.7469, 35.3389), // 3: Cana of Galilee
        LatLng(32.8803, 35.5753), // 4: Capernaum
        LatLng(32.8806, 35.5558), // 5: Mount of Beatitudes
        LatLng(32.8150, 35.5900), // 6: Sea of Galilee
        LatLng(32.2128, 35.2869), // 7: Jacob's Well at Sychar
        LatLng(33.2478, 35.6942), // 8: Caesarea Philippi
        LatLng(31.7714, 35.2581), // 9: Bethany (Lazarus)
        LatLng(31.7792, 35.2397), // 10: Garden of Gethsemane
        LatLng(31.7839, 35.2300), // 11: Golgotha & the Empty Tomb
      ],
      pois: [
        MapPOI(
          id: 'bethlehem_nativity',
          title: 'Bethlehem (Birth of Jesus)',
          description: 'In the town of David, the Savior—Christ the Lord—was born and laid in a manger.',
          location: LatLng(31.7054, 35.2024),
          imageUrl: '',
          requiredChapterIds: ['LUK.2'],
          unlockedChapterId: 'LUK.2',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'nazareth_jesus',
          title: 'Nazareth',
          description: 'The Galilean hometown where Jesus grew in wisdom and stature, and declared in the synagogue that Isaiah\'s prophecy was fulfilled.',
          location: LatLng(32.7021, 35.2978),
          imageUrl: '',
          requiredChapterIds: ['LUK.4'],
          unlockedChapterId: 'LUK.4',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'jordan_baptism_jesus',
          title: 'Jordan River (Baptism of Jesus)',
          description: 'John baptized Jesus in the Jordan; the heavens opened, the Spirit descended like a dove, and the Father spoke.',
          location: LatLng(31.8372, 35.5469),
          imageUrl: '',
          requiredChapterIds: ['MAT.3'],
          unlockedChapterId: 'MAT.3',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'cana_wedding',
          title: 'Cana of Galilee',
          description: 'Where Jesus performed the first of His signs at a wedding feast, turning water into choice wine and revealing His glory.',
          location: LatLng(32.7469, 35.3389),
          imageUrl: '',
          requiredChapterIds: ['JHN.2'],
          unlockedChapterId: 'JHN.2',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'capernaum_ministry',
          title: 'Capernaum',
          description: 'Center of Jesus\' Galilean ministry, where He taught with authority, healed Peter\'s mother-in-law, and forgave the paralytic lowered through the roof.',
          location: LatLng(32.8803, 35.5753),
          imageUrl: '',
          requiredChapterIds: ['MRK.2'],
          unlockedChapterId: 'MRK.2',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'mount_of_beatitudes',
          title: 'Mount of Beatitudes',
          description: 'On a hillside overlooking the Sea of Galilee, Jesus delivered the Sermon on the Mount.',
          location: LatLng(32.8806, 35.5558),
          imageUrl: '',
          requiredChapterIds: ['MAT.5'],
          unlockedChapterId: 'MAT.5',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'sea_of_galilee_storm',
          title: 'Sea of Galilee',
          description: 'Here Jesus called the first disciples, calmed the raging storm with a word, and walked on the water.',
          location: LatLng(32.8150, 35.5900),
          imageUrl: '',
          requiredChapterIds: ['MAT.14'],
          unlockedChapterId: 'MAT.14',
          pathPointIndex: 6,
        ),
        MapPOI(
          id: 'sychar_jacobs_well',
          title: 'Sychar (Jacob\'s Well)',
          description: 'In Samaria, Jesus offered the woman at the well "living water" welling up to eternal life.',
          location: LatLng(32.2128, 35.2869),
          imageUrl: '',
          requiredChapterIds: ['JHN.4'],
          unlockedChapterId: 'JHN.4',
          pathPointIndex: 7,
        ),
        MapPOI(
          id: 'caesarea_philippi',
          title: 'Caesarea Philippi',
          description: 'Where Peter confessed to Jesus: "You are the Messiah, the Son of the living God."',
          location: LatLng(33.2478, 35.6942),
          imageUrl: '',
          requiredChapterIds: ['MAT.16'],
          unlockedChapterId: 'MAT.16',
          pathPointIndex: 8,
        ),
        MapPOI(
          id: 'bethany_lazarus',
          title: 'Bethany',
          description: 'Home of Mary, Martha, and Lazarus, where Jesus declared "I am the resurrection and the life" and called Lazarus from the tomb.',
          location: LatLng(31.7714, 35.2581),
          imageUrl: '',
          requiredChapterIds: ['JHN.11'],
          unlockedChapterId: 'JHN.11',
          pathPointIndex: 9,
        ),
        MapPOI(
          id: 'garden_of_gethsemane',
          title: 'Garden of Gethsemane (Mount of Olives)',
          description: 'On the night He was betrayed, Jesus prayed in agony on the Mount of Olives: "Not my will, but yours be done."',
          location: LatLng(31.7792, 35.2397),
          imageUrl: '',
          requiredChapterIds: ['MAT.26'],
          unlockedChapterId: 'MAT.26',
          pathPointIndex: 10,
        ),
        MapPOI(
          id: 'golgotha_empty_tomb',
          title: 'Golgotha & The Empty Tomb (Jerusalem)',
          description: 'Where Jesus was crucified for the sins of the world and rose victorious from the grave on the third day.',
          location: LatLng(31.7839, 35.2300),
          imageUrl: '',
          requiredChapterIds: ['JHN.19', 'JHN.20'],
          unlockedChapterId: 'JHN.20',
          pathPointIndex: 11,
        ),
      ],
    ),

    // 7. Paul's First Missionary Journey
    BibleMapPath(
      id: 'pauls_first_journey',
      name: "Paul's First Missionary Journey",
      description: 'Paul and Barnabas carry the Gospel to Cyprus and Galatia (Acts 13–14).',
      points: [
        LatLng(36.2021, 36.1606), // 0: Antioch in Syria
        LatLng(36.1239, 35.9219), // 1: Seleucia
        LatLng(35.1856, 33.9019), // 2: Salamis (Cyprus)
        LatLng(34.7558, 32.4042), // 3: Paphos (Cyprus)
        LatLng(36.9608, 30.8533), // 4: Perga in Pamphylia
        LatLng(38.3039, 31.1892), // 5: Pisidian Antioch
        LatLng(37.8714, 32.4847), // 6: Iconium
        LatLng(37.5786, 32.4533), // 7: Lystra
        LatLng(37.3592, 33.3614), // 8: Derbe
        LatLng(36.8841, 30.7056), // 9: Attalia
      ],
      pois: [
        MapPOI(
          id: 'antioch_syria_paul1',
          title: 'Antioch in Syria',
          description: 'Where believers were first called Christians, and the Holy Spirit set apart Barnabas and Saul for missionary work.',
          location: LatLng(36.2021, 36.1606),
          imageUrl: '',
          requiredChapterIds: ['ACT.13'],
          unlockedChapterId: 'ACT.13',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'seleucia_pieria',
          title: 'Seleucia Pieria',
          description: 'Mediterranean port from which Paul, Barnabas, and John Mark set sail for Cyprus.',
          location: LatLng(36.1239, 35.9219),
          imageUrl: '',
          requiredChapterIds: ['ACT.13'],
          unlockedChapterId: 'ACT.13',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'salamis_cyprus',
          title: 'Salamis (Cyprus)',
          description: 'Arriving on the island of Cyprus, Paul and Barnabas proclaimed the word of God in the Jewish synagogues.',
          location: LatLng(35.1856, 33.9019),
          imageUrl: '',
          requiredChapterIds: ['ACT.13'],
          unlockedChapterId: 'ACT.13',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'paphos_cyprus',
          title: 'Paphos',
          description: 'The Roman proconsul Sergius Paulus believed the Gospel after witnessing the power of the Lord against Elymas the sorcerer.',
          location: LatLng(34.7558, 32.4042),
          imageUrl: '',
          requiredChapterIds: ['ACT.13'],
          unlockedChapterId: 'ACT.13',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'perga_pamphylia',
          title: 'Perga in Pamphylia',
          description: 'Landing in Asia Minor, John Mark returned to Jerusalem while Paul and Barnabas pressed inland into the Taurus Mountains.',
          location: LatLng(36.9608, 30.8533),
          imageUrl: '',
          requiredChapterIds: ['ACT.13'],
          unlockedChapterId: 'ACT.13',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'pisidian_antioch',
          title: 'Pisidian Antioch',
          description: 'Paul preached a powerful sermon in the synagogue tracing God\'s salvation history to Jesus, and many Gentiles rejoiced.',
          location: LatLng(38.3039, 31.1892),
          imageUrl: '',
          requiredChapterIds: ['ACT.13'],
          unlockedChapterId: 'ACT.13',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'iconium',
          title: 'Iconium',
          description: 'Paul and Barnabas spoke boldly for the Lord, who confirmed the message of His grace by enabling them to perform signs and wonders.',
          location: LatLng(37.8714, 32.4847),
          imageUrl: '',
          requiredChapterIds: ['ACT.14'],
          unlockedChapterId: 'ACT.14',
          pathPointIndex: 6,
        ),
        MapPOI(
          id: 'lystra',
          title: 'Lystra',
          description: 'After a man lame from birth was healed, the crowds tried to worship Paul and Barnabas, and later stoned Paul.',
          location: LatLng(37.5786, 32.4533),
          imageUrl: '',
          requiredChapterIds: ['ACT.14'],
          unlockedChapterId: 'ACT.14',
          pathPointIndex: 7,
        ),
        MapPOI(
          id: 'derbe',
          title: 'Derbe',
          description: 'They preached the Gospel in Derbe and won a large number of disciples before retracing their steps to strengthen the churches.',
          location: LatLng(37.3592, 33.3614),
          imageUrl: '',
          requiredChapterIds: ['ACT.14'],
          unlockedChapterId: 'ACT.14',
          pathPointIndex: 8,
        ),
        MapPOI(
          id: 'attalia',
          title: 'Attalia',
          description: 'Seaport from which Paul and Barnabas sailed back to Antioch in Syria to report all that God had done through them.',
          location: LatLng(36.8841, 30.7056),
          imageUrl: '',
          requiredChapterIds: ['ACT.14'],
          unlockedChapterId: 'ACT.14',
          pathPointIndex: 9,
        ),
      ],
    ),

    // 8. Paul's Second Missionary Journey
    BibleMapPath(
      id: 'pauls_second_journey',
      name: "Paul's Second Missionary Journey",
      description: 'The Gospel crosses into Europe: Macedonia, Greece, and Asia Minor (Acts 16–19).',
      points: [
        LatLng(39.7544, 26.1394), // 0: Troas
        LatLng(41.0131, 24.2872), // 1: Philippi
        LatLng(40.6401, 22.9444), // 2: Thessalonica
        LatLng(40.5244, 22.2028), // 3: Berea
        LatLng(37.9715, 23.7225), // 4: Athens (Areopagus)
        LatLng(37.9061, 22.8806), // 5: Corinth
        LatLng(37.9411, 27.3419), // 6: Ephesus
      ],
      pois: [
        MapPOI(
          id: 'troas_macedonian_call',
          title: 'Troas (The Macedonian Call)',
          description: 'During the night Paul had a vision of a man of Macedonia standing and begging him, "Come over to Macedonia and help us."',
          location: LatLng(39.7544, 26.1394),
          imageUrl: '',
          requiredChapterIds: ['ACT.16'],
          unlockedChapterId: 'ACT.16',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'philippi_jailer',
          title: 'Philippi',
          description: 'The Lord opened Lydia\'s heart by the river, and an earthquake opened the prison doors while Paul and Silas sang hymns at midnight.',
          location: LatLng(41.0131, 24.2872),
          imageUrl: '',
          requiredChapterIds: ['ACT.16'],
          unlockedChapterId: 'ACT.16',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'thessalonica_paul',
          title: 'Thessalonica',
          description: 'For three Sabbaths Paul reasoned from the Scriptures that the Messiah had to suffer and rise from the dead.',
          location: LatLng(40.6401, 22.9444),
          imageUrl: '',
          requiredChapterIds: ['ACT.17'],
          unlockedChapterId: 'ACT.17',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'berea_noble',
          title: 'Berea',
          description: 'The Bereans received the message with great eagerness and examined the Scriptures every day to see if what Paul said was true.',
          location: LatLng(40.5244, 22.2028),
          imageUrl: '',
          requiredChapterIds: ['ACT.17'],
          unlockedChapterId: 'ACT.17',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'athens_areopagus',
          title: 'Athens (Mars Hill / Areopagus)',
          description: 'Standing before the Areopagus, Paul proclaimed the Unknown God who made the world and raised Jesus from the dead.',
          location: LatLng(37.9715, 23.7225),
          imageUrl: '',
          requiredChapterIds: ['ACT.17'],
          unlockedChapterId: 'ACT.17',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'corinth_paul',
          title: 'Corinth',
          description: 'Paul stayed a year and a half teaching the word of God alongside Priscilla and Aquila, encouraged by a vision from the Lord.',
          location: LatLng(37.9061, 22.8806),
          imageUrl: '',
          requiredChapterIds: ['ACT.18'],
          unlockedChapterId: 'ACT.18',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'ephesus_paul',
          title: 'Ephesus',
          description: 'Paul reasoned daily in the lecture hall of Tyrannus so that all the Jews and Greeks in the province of Asia heard the word of the Lord.',
          location: LatLng(37.9411, 27.3419),
          imageUrl: '',
          requiredChapterIds: ['ACT.19'],
          unlockedChapterId: 'ACT.19',
          pathPointIndex: 6,
        ),
      ],
    ),

    // 9. Paul's Journey to Rome
    BibleMapPath(
      id: 'pauls_journey_to_rome',
      name: "Paul's Journey to Rome",
      description: 'Appealing to Caesar, Paul sails through storm and shipwreck to testify in Rome (Acts 25–28).',
      points: [
        LatLng(32.5000, 34.8919), // 0: Caesarea Maritima
        LatLng(34.9289, 34.8031), // 1: Fair Havens (Crete)
        LatLng(35.9481, 14.3806), // 2: Malta (St. Paul's Bay)
        LatLng(41.8902, 12.4922), // 3: Rome
      ],
      pois: [
        MapPOI(
          id: 'caesarea_maritima_paul',
          title: 'Caesarea Maritima',
          description: 'Imprisoned for two years, Paul testified before Governors Felix and Festus and King Agrippa before appealing to Caesar.',
          location: LatLng(32.5000, 34.8919),
          imageUrl: '',
          requiredChapterIds: ['ACT.25', 'ACT.26'],
          unlockedChapterId: 'ACT.26',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'fair_havens_crete',
          title: 'Fair Havens (Crete)',
          description: 'Paul warned the centurion of impending disaster at sea before the tempestuous "Northeaster" swept the ship away.',
          location: LatLng(34.9289, 34.8031),
          imageUrl: '',
          requiredChapterIds: ['ACT.27'],
          unlockedChapterId: 'ACT.27',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'malta_shipwreck',
          title: 'Malta (Shipwreck)',
          description: 'All 276 aboard survived the shipwreck on Malta, where Paul shook off a viper unharmed and healed many on the island.',
          location: LatLng(35.9481, 14.3806),
          imageUrl: '',
          requiredChapterIds: ['ACT.28'],
          unlockedChapterId: 'ACT.28',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'rome_paul',
          title: 'Rome',
          description: 'For two whole years Paul welcomed all who came to see him, proclaiming the kingdom of God and teaching about the Lord Jesus Christ with all boldness.',
          location: LatLng(41.8902, 12.4922),
          imageUrl: '',
          requiredChapterIds: ['ACT.28'],
          unlockedChapterId: 'ACT.28',
          pathPointIndex: 3,
        ),
      ],
    ),
  ];
}
