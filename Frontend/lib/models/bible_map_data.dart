import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPOI {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final LatLng location;
  final List<String>
      requiredChapterIds; // List of chapter IDs required to unlock this POI (e.g., "EXO.1")
  final String
      unlockedChapterId; // The chapter ID that this POI represents or unlocks content for
  final int
      pathPointIndex; // Index in the path points list that this POI corresponds to

  MapPOI({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.requiredChapterIds,
    required this.unlockedChapterId,
    required this.pathPointIndex,
  });
}

class BibleMapPath {
  final String id;
  final String name;
  final String description;
  final List<LatLng> points;
  final List<MapPOI> pois;

  BibleMapPath({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    required this.pois,
  });
}

class BibleMapData {
  static final List<BibleMapPath> paths = [
    BibleMapPath(
      id: 'exodus',
      name: 'The Exodus',
      description:
          'The journey of the Israelites from Egypt to the Promised Land.',
      points: [
        // Approximate path points
        LatLng(30.7900, 31.9700), // Rameses
        LatLng(30.5500, 32.2200), // Succoth
        LatLng(30.3333, 32.5000), // Etham
        LatLng(29.9500, 32.5000), // Pi-hahiroth
        LatLng(29.9000, 32.5500), // Crossing Red Sea
        LatLng(29.3500, 32.9500), // Marah
        LatLng(29.2000, 33.1000), // Elim
        LatLng(28.8000, 33.3000), // Wilderness of Sin
        LatLng(28.6500, 33.6000), // Rephidim
        LatLng(28.5392, 33.9730), // Mount Sinai
        LatLng(28.7000, 34.1000), // Taberah
        LatLng(28.8500, 34.2500), // Kibroth Hattaavah
        LatLng(28.9500, 34.4500), // Hazeroth
        LatLng(30.6500, 34.4000), // Kadesh Barnea
        LatLng(30.3167, 35.4000), // Mount Hor
        LatLng(30.6000, 35.5000), // Punon
        LatLng(30.8000, 35.6000), // Oboth
        LatLng(31.0000, 35.7000), // Iye Abarim
        LatLng(31.8000, 35.6000), // Plains of Moab
        LatLng(31.7650, 35.7250), // Mount Nebo
        LatLng(31.8667, 35.4500), // Jericho (End)
      ],
      pois: [
        MapPOI(
          id: 'start_egypt',
          title: 'Start of the Journey',
          description:
              'The Israelites begin their journey out of Egypt from Rameses.',
          imageUrl: 'assets/pois/egypt_start.png',
          location: LatLng(30.7900, 31.9700),
          requiredChapterIds: [],
          unlockedChapterId: 'EXO.1',
          pathPointIndex: 0,
        ),
        MapPOI(
          id: 'succoth',
          title: 'Succoth',
          description:
              'The first campsite of the Israelites after leaving Rameses.',
          imageUrl: 'assets/models/succoth.png',
          location: LatLng(30.5500, 32.2200),
          requiredChapterIds: ['EXO.12'],
          unlockedChapterId: 'EXO.13',
          pathPointIndex: 1,
        ),
        MapPOI(
          id: 'etham',
          title: 'Etham',
          description: 'Camping on the edge of the wilderness.',
          imageUrl: 'assets/models/etham.png',
          location: LatLng(30.3333, 32.5000),
          requiredChapterIds: ['EXO.13'],
          unlockedChapterId: 'EXO.13',
          pathPointIndex: 2,
        ),
        MapPOI(
          id: 'pi_hahiroth',
          title: 'Pi-hahiroth',
          description: 'Encamping by the sea, before Baal Zephon.',
          imageUrl: 'assets/models/pi_hahiroth.png',
          location: LatLng(29.9500, 32.5000),
          requiredChapterIds: ['EXO.14'],
          unlockedChapterId: 'EXO.14',
          pathPointIndex: 3,
        ),
        MapPOI(
          id: 'crossing_sea',
          title: 'Crossing the Red Sea',
          description:
              'God parts the Red Sea for the Israelites to cross on dry ground.',
          imageUrl: 'assets/pois/red_sea.png',
          location: LatLng(29.9000, 32.5500),
          requiredChapterIds: ['EXO.14'],
          unlockedChapterId: 'EXO.14',
          pathPointIndex: 4,
        ),
        MapPOI(
          id: 'marah',
          title: 'Marah',
          description: 'The bitter waters are made sweet.',
          imageUrl: 'assets/models/marah.png',
          location: LatLng(29.3500, 32.9500),
          requiredChapterIds: ['EXO.15'],
          unlockedChapterId: 'EXO.15',
          pathPointIndex: 5,
        ),
        MapPOI(
          id: 'elim',
          title: 'Elim',
          description: 'Camping by twelve springs and seventy palm trees.',
          imageUrl: 'assets/models/elim.png',
          location: LatLng(29.2000, 33.1000),
          requiredChapterIds: ['EXO.15'],
          unlockedChapterId: 'EXO.15',
          pathPointIndex: 6,
        ),
        MapPOI(
          id: 'wilderness_sin',
          title: 'Wilderness of Sin',
          description: 'God provides manna and quail for the Israelites.',
          imageUrl: 'assets/models/manna.png',
          location: LatLng(28.8000, 33.3000),
          requiredChapterIds: ['EXO.16'],
          unlockedChapterId: 'EXO.16',
          pathPointIndex: 7,
        ),
        MapPOI(
          id: 'rephidim',
          title: 'Rephidim',
          description: 'Water from the rock and battle with the Amalekites.',
          imageUrl: 'assets/models/rephidim.png',
          location: LatLng(28.6500, 33.6000),
          requiredChapterIds: ['EXO.17'],
          unlockedChapterId: 'EXO.17',
          pathPointIndex: 8,
        ),
        MapPOI(
          id: 'mt_sinai',
          title: 'Mount Sinai',
          description: 'Moses receives the Ten Commandments.',
          imageUrl: 'assets/models/mt_sinai.png',
          location: LatLng(28.5392, 33.9730),
          requiredChapterIds: ['EXO.19', 'EXO.20'],
          unlockedChapterId: 'EXO.20',
          pathPointIndex: 9,
        ),
        MapPOI(
          id: 'taberah',
          title: 'Taberah',
          description:
              'Fire from the Lord consumes part of the camp due to complaining.',
          imageUrl: 'assets/models/taberah.png',
          location: LatLng(28.7000, 34.1000),
          requiredChapterIds: ['NUM.11'],
          unlockedChapterId: 'NUM.11',
          pathPointIndex: 10,
        ),
        MapPOI(
          id: 'kibroth_hattaavah',
          title: 'Kibroth Hattaavah',
          description: 'Graves of craving; plague strikes after eating quail.',
          imageUrl: 'assets/models/kibroth.png',
          location: LatLng(28.8500, 34.2500),
          requiredChapterIds: ['NUM.11'],
          unlockedChapterId: 'NUM.11',
          pathPointIndex: 11,
        ),
        MapPOI(
          id: 'hazeroth',
          title: 'Hazeroth',
          description: 'Miriam and Aaron oppose Moses.',
          imageUrl: 'assets/models/hazeroth.png',
          location: LatLng(28.9500, 34.4500),
          requiredChapterIds: ['NUM.12'],
          unlockedChapterId: 'NUM.12',
          pathPointIndex: 12,
        ),
        MapPOI(
          id: 'kadesh_barnea',
          title: 'Kadesh Barnea',
          description: 'Spies sent into Canaan; people refuse to enter.',
          imageUrl: 'assets/models/kadesh.png',
          location: LatLng(30.6500, 34.4000),
          requiredChapterIds: ['NUM.13', 'NUM.14'],
          unlockedChapterId: 'NUM.14',
          pathPointIndex: 13,
        ),
        MapPOI(
          id: 'mount_hor',
          title: 'Mount Hor',
          description: 'Death of Aaron.',
          imageUrl: 'assets/models/mt_hor.png',
          location: LatLng(30.3167, 35.4000),
          requiredChapterIds: ['NUM.20'],
          unlockedChapterId: 'NUM.20',
          pathPointIndex: 14,
        ),
        MapPOI(
          id: 'punon',
          title: 'Punon',
          description: 'The bronze serpent heals those bitten by snakes.',
          imageUrl: 'assets/models/punon.png',
          location: LatLng(30.6000, 35.5000),
          requiredChapterIds: ['NUM.21'],
          unlockedChapterId: 'NUM.21',
          pathPointIndex: 15,
        ),
        MapPOI(
          id: 'oboth',
          title: 'Oboth',
          description: 'Camping place on the journey.',
          imageUrl: 'assets/models/oboth.png',
          location: LatLng(30.8000, 35.6000),
          requiredChapterIds: ['NUM.21'],
          unlockedChapterId: 'NUM.21',
          pathPointIndex: 16,
        ),
        MapPOI(
          id: 'iye_abarim',
          title: 'Iye Abarim',
          description: 'Camping at the border of Moab.',
          imageUrl: 'assets/models/iye_abarim.png',
          location: LatLng(31.0000, 35.7000),
          requiredChapterIds: ['NUM.21'],
          unlockedChapterId: 'NUM.21',
          pathPointIndex: 17,
        ),
        MapPOI(
          id: 'plains_moab',
          title: 'Plains of Moab',
          description: 'Encampment across from Jericho.',
          imageUrl: 'assets/models/moab.png',
          location: LatLng(31.8000, 35.6000),
          requiredChapterIds: ['NUM.22'],
          unlockedChapterId: 'NUM.22',
          pathPointIndex: 18,
        ),
        MapPOI(
          id: 'mt_nebo',
          title: 'Mount Nebo',
          description: 'Moses views the Promised Land and dies.',
          imageUrl: 'assets/models/mt_nebo.png',
          location: LatLng(31.7650, 35.7250),
          requiredChapterIds: ['DEU.34'],
          unlockedChapterId: 'DEU.34',
          pathPointIndex: 19,
        ),
      ],
    ),
    BibleMapPath(
        id: 'pauls_first_journey',
        name: "Paul's First Missionary Journey",
        description:
            'Paul and Barnabas travel to Cyprus and Galatia (Acts 13-14).',
        points: [
          LatLng(36.2021, 36.1606), // Antioch (Syria)
          LatLng(36.1260, 35.9220), // Seleucia
          LatLng(35.1558, 33.9030), // Salamis
          LatLng(34.7733, 32.4233), // Paphos
          LatLng(36.9583, 30.8500), // Perga
          LatLng(38.3000, 31.1833), // Antioch (Pisidia)
          LatLng(37.8667, 32.4833), // Iconium
          LatLng(37.5667, 32.1833), // Lystra
          LatLng(37.3500, 33.1667), // Derbe
          LatLng(37.5667, 32.1833), // Lystra (Return)
          LatLng(37.8667, 32.4833), // Iconium (Return)
          LatLng(38.3000, 31.1833), // Antioch (Pisidia) (Return)
          LatLng(36.9583, 30.8500), // Perga (Return)
          LatLng(36.8833, 30.7000), // Attalia
          LatLng(36.1260, 35.9220), // Seleucia (Return)
          LatLng(36.2021, 36.1606), // Antioch (Syria) (End)
        ],
        pois: [
          MapPOI(
            id: 'antioch_syria',
            title: 'Antioch (Syria)',
            description:
                'The Holy Spirit sets apart Barnabas and Saul for the work.',
            imageUrl: 'assets/models/antioch_syria.png',
            location: LatLng(36.2021, 36.1606),
            requiredChapterIds: ['ACT.13'],
            unlockedChapterId: 'ACT.13',
            pathPointIndex: 0,
          ),
          MapPOI(
            id: 'seleucia',
            title: 'Seleucia',
            description: 'They sailed from here to Cyprus.',
            imageUrl: 'assets/models/seleucia.png',
            location: LatLng(36.1260, 35.9220),
            requiredChapterIds: ['ACT.13'],
            unlockedChapterId: 'ACT.13',
            pathPointIndex: 1,
          ),
          MapPOI(
            id: 'salamis',
            title: 'Salamis',
            description:
                'They proclaimed the word of God in the Jewish synagogues.',
            imageUrl: 'assets/models/salamis.png',
            location: LatLng(35.1558, 33.9030),
            requiredChapterIds: ['ACT.13'],
            unlockedChapterId: 'ACT.13',
            pathPointIndex: 2,
          ),
          MapPOI(
            id: 'paphos',
            title: 'Paphos',
            description:
                'Elymas the sorcerer is blinded; Sergius Paulus believes.',
            imageUrl: 'assets/models/paphos.png',
            location: LatLng(34.7733, 32.4233),
            requiredChapterIds: ['ACT.13'],
            unlockedChapterId: 'ACT.13',
            pathPointIndex: 3,
          ),
          MapPOI(
            id: 'perga',
            title: 'Perga',
            description: 'John Mark leaves them and returns to Jerusalem.',
            imageUrl: 'assets/models/perga.png',
            location: LatLng(36.9583, 30.8500),
            requiredChapterIds: ['ACT.13'],
            unlockedChapterId: 'ACT.13',
            pathPointIndex: 4,
          ),
          MapPOI(
            id: 'antioch_pisidia',
            title: 'Antioch (Pisidia)',
            description:
                'Paul preaches in the synagogue; many Gentiles believe.',
            imageUrl: 'assets/models/antioch_pisidia.png',
            location: LatLng(38.3000, 31.1833),
            requiredChapterIds: ['ACT.13'],
            unlockedChapterId: 'ACT.13',
            pathPointIndex: 5,
          ),
          MapPOI(
            id: 'iconium',
            title: 'Iconium',
            description:
                'Paul and Barnabas speak effectively; a plot to stone them.',
            imageUrl: 'assets/models/iconium.png',
            location: LatLng(37.8667, 32.4833),
            requiredChapterIds: ['ACT.14'],
            unlockedChapterId: 'ACT.14',
            pathPointIndex: 6,
          ),
          MapPOI(
            id: 'lystra',
            title: 'Lystra',
            description: 'Paul heals a lame man; later he is stoned.',
            imageUrl: 'assets/models/lystra.png',
            location: LatLng(37.5667, 32.1833),
            requiredChapterIds: ['ACT.14'],
            unlockedChapterId: 'ACT.14',
            pathPointIndex: 7,
          ),
          MapPOI(
            id: 'derbe',
            title: 'Derbe',
            description:
                'They preached the gospel and won a large number of disciples.',
            imageUrl: 'assets/models/derbe.png',
            location: LatLng(37.3500, 33.1667),
            requiredChapterIds: ['ACT.14'],
            unlockedChapterId: 'ACT.14',
            pathPointIndex: 8,
          ),
          MapPOI(
            id: 'attalia',
            title: 'Attalia',
            description:
                'They preached the word here before sailing back to Antioch.',
            imageUrl: 'assets/models/attalia.png',
            location: LatLng(36.8833, 30.7000),
            requiredChapterIds: ['ACT.14'],
            unlockedChapterId: 'ACT.14',
            pathPointIndex: 13,
          ),
        ]),
  ];
}
