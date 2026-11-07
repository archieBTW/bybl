package database

import (
	"errors"
	"log"
	"theword/Backend/lib/models"
	"time"

	"gorm.io/gorm"
)

func SeedDatabase(db *gorm.DB) {
	// Always run non-destructive map data seeding so new paths/POIs are added
	// without overwriting any edits or images added in gofyrAdmin.
	SeedMapData(db)

	// Check if we already have users/churches
	var userCount int64
	db.Model(&models.User{}).Count(&userCount)
	if userCount > 0 {
		log.Println("Database users already seeded")
		return
	}

	// Create sample users
	users := []models.User{
		{
			Email:           "admin@example.com",
			Username:        "Admin",
			PasswordHash:    "$2a$10$X7J3Y5Z8A9B0C1D2E3F4G5H6I7J8K9L0M1N2O3P4Q5R6S7T8U9V0W1X2Y3Z4",
			PublicProfile:   true,
			PrimaryColor:    0xFF000000,
			HighlightColor:  0xFFFF0000,
			DarkMode:        true,
			TranslationId:   "bba9f40183526463-01",
			TranslationName: "Berean Standard Bible",
			IsAdmin:         true,
		},
		{
			Email:           "john@example.com",
			Username:        "John",
			PasswordHash:    "$2a$10$X7J3Y5Z8A9B0C1D2E3F4G5H6I7J8K9L0M1N2O3P4Q5R6S7T8U9V0W1X2Y3Z4",
			PublicProfile:   true,
			PrimaryColor:    0xFF0000FF,
			HighlightColor:  0xFFFFFF00,
			DarkMode:        false,
			TranslationId:   "bba9f40183526463-01",
			TranslationName: "Berean Standard Bible",
			IsAdmin:         false,
		},
		{
			Email:           "sarah@example.com",
			Username:        "Sarah",
			PasswordHash:    "$2a$10$X7J3Y5Z8A9B0C1D2E3F4G5H6I7J8K9L0M1N2O3P4Q5R6S7T8U9V0W1X2Y3Z4",
			PublicProfile:   true,
			PrimaryColor:    0xFF00FF00,
			HighlightColor:  0xFFFF00FF,
			DarkMode:        true,
			TranslationId:   "bba9f40183526463-01",
			TranslationName: "Berean Standard Bible",
			IsAdmin:         false,
		},
	}

	for i := range users {
		if err := db.Create(&users[i]).Error; err != nil {
			log.Printf("Error creating user: %v", err)
			continue
		}

		verses := []models.UserVerse{
			{
				VerseID:     "JHN.3.16",
				Content:     "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
				Verse:       "John 3:16",
				UserID:      users[i].UserID,
				Note:        "A powerful reminder of God's love",
				IsPublished: true,
			},
			{
				VerseID:     "PHP.4.13",
				Content:     "I can do all this through him who gives me strength.",
				Verse:       "Philippians 4:13",
				UserID:      users[i].UserID,
				Note:        "Encouragement for difficult times",
				IsPublished: true,
			},
			{
				VerseID:     "ROM.8.28",
				Content:     "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
				Verse:       "Romans 8:28",
				UserID:      users[i].UserID,
				Note:        "Trusting in God's plan",
				IsPublished: true,
			},
		}

		for j := range verses {
			if err := db.Create(&verses[j]).Error; err != nil {
				log.Printf("Error creating verse: %v", err)
				continue
			}

			comments := []models.Comment{
				{
					Content:         "This verse has been a great comfort to me",
					UserID:          users[i].UserID,
					Username:        users[i].Username,
					UserVerseID:     int(verses[j].UserVerseID),
					ParentCommentID: nil,
				},
				{
					Content:         "I love how this verse reminds us of God's love",
					UserID:          users[i].UserID,
					Username:        users[i].Username,
					UserVerseID:     int(verses[j].UserVerseID),
					ParentCommentID: nil,
				},
			}

			for k := range comments {
				if err := db.Create(&comments[k]).Error; err != nil {
					log.Printf("Error creating comment: %v", err)
					continue
				}

				if k == 0 {
					like := models.Like{
						UserID:      users[i].UserID,
						UserVerseID: int(verses[j].UserVerseID),
					}
					if err := db.Create(&like).Error; err != nil {
						log.Printf("Error creating like: %v", err)
					}
				}
			}
		}

		if i < len(users)-1 {
			friend := models.Friend{
				UserID:    users[i].UserID,
				FriendID:  users[i+1].UserID,
				Status:    "accepted",
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
			}
			if err := db.Create(&friend).Error; err != nil {
				log.Printf("Error creating friend: %v", err)
			}
		}

		notifications := []models.Notification{
			{
				UserID:      users[i].UserID,
				Content:     "You have a new comment on your verse",
				UserVerseID: 1,
				CommentID:   nil,
				CreatedAt:   time.Now(),
			},
			{
				UserID:      users[i].UserID,
				Content:     "Someone liked your verse",
				UserVerseID: 2,
				CommentID:   nil,
				CreatedAt:   time.Now(),
			},
		}

		for j := range notifications {
			if err := db.Create(&notifications[j]).Error; err != nil {
				log.Printf("Error creating notification: %v", err)
			}
		}
	}

	log.Println("Database seeded successfully")
}

// SeedMapData non-destructively seeds Bible map paths and POIs.
// Any existing path or POI (matched by unique Slug) is left untouched so
// changes or images added in gofyrAdmin are never overwritten.
func SeedMapData(db *gorm.DB) {
	seedPaths := getInitialBibleMapPaths()

	pathsAdded := 0
	poisAdded := 0

	for _, seedPath := range seedPaths {
		pois := seedPath.POIs
		seedPath.POIs = nil

		var existingPath models.BibleMapPath
		err := db.Unscoped().Where("slug = ?", seedPath.Slug).First(&existingPath).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			if err := db.Create(&seedPath).Error; err != nil {
				log.Printf("SeedMapData: failed to create path %s: %v", seedPath.Slug, err)
				continue
			}
			existingPath = seedPath
			pathsAdded++
		} else if err != nil {
			log.Printf("SeedMapData: error querying path %s: %v", seedPath.Slug, err)
			continue
		}

		for _, poi := range pois {
			poi.BibleMapPathID = existingPath.ID
			var existingPOI models.MapPOI
			err := db.Unscoped().Where("slug = ?", poi.Slug).First(&existingPOI).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				if err := db.Create(&poi).Error; err != nil {
					log.Printf("SeedMapData: failed to create POI %s: %v", poi.Slug, err)
					continue
				}
				poisAdded++
			}
		}
	}

	if pathsAdded > 0 || poisAdded > 0 {
		log.Printf("✓ SeedMapData: non-destructively added %d paths and %d POIs", pathsAdded, poisAdded)
	} else {
		log.Println("✓ SeedMapData: all map paths and POIs already present")
	}
}

func getInitialBibleMapPaths() []models.BibleMapPath {
	return []models.BibleMapPath{
		// 1. Journey of Abraham
		{
			Slug:        "abrahams_journey",
			Name:        "Journey of Abraham",
			Description: "Abram's call from Mesopotamia to the Promised Land of Canaan (Genesis 11–22).",
			Points: models.PointList{
				{Lat: 30.9625, Lng: 46.1031}, // Ur
				{Lat: 36.8600, Lng: 39.0314}, // Haran
				{Lat: 32.2136, Lng: 35.2819}, // Shechem
				{Lat: 31.9306, Lng: 35.2219}, // Bethel
				{Lat: 31.5326, Lng: 35.0998}, // Hebron (Mamre)
				{Lat: 31.2450, Lng: 34.8408}, // Beersheba
				{Lat: 31.7780, Lng: 35.2354}, // Mount Moriah
			},
			POIs: []models.MapPOI{
				{
					Slug:               "ur_chaldeans",
					Title:              "Ur of the Chaldeans",
					Description:        "Abram's ancestral homeland in Mesopotamia before Terah's family set out toward Canaan.",
					ImageURL:           "",
					Latitude:           30.9625,
					Longitude:          46.1031,
					RequiredChapterIDs: models.StringList{"GEN.11"},
					UnlockedChapterID:  "GEN.11",
					PathPointIndex:     0,
				},
				{
					Slug:               "haran",
					Title:              "Haran",
					Description:        "Where God called Abram to leave his country and father's household to go to the land He would show him.",
					ImageURL:           "",
					Latitude:           36.8600,
					Longitude:          39.0314,
					RequiredChapterIDs: models.StringList{"GEN.12"},
					UnlockedChapterID:  "GEN.12",
					PathPointIndex:     1,
				},
				{
					Slug:               "shechem_abram",
					Title:              "Shechem (Oak of Moreh)",
					Description:        "Abram's first stop in Canaan where the Lord appeared to him, promised the land to his offspring, and Abram built an altar.",
					ImageURL:           "",
					Latitude:           32.2136,
					Longitude:          35.2819,
					RequiredChapterIDs: models.StringList{"GEN.12"},
					UnlockedChapterID:  "GEN.12",
					PathPointIndex:     2,
				},
				{
					Slug:               "bethel_abram",
					Title:              "Bethel & Ai",
					Description:        "In the hill country between Bethel and Ai, Abram pitched his tent, built an altar, and called on the name of the Lord.",
					ImageURL:           "",
					Latitude:           31.9306,
					Longitude:          35.2219,
					RequiredChapterIDs: models.StringList{"GEN.12"},
					UnlockedChapterID:  "GEN.12",
					PathPointIndex:     3,
				},
				{
					Slug:               "hebron_mamre",
					Title:              "Hebron (Oaks of Mamre)",
					Description:        "Where Abraham settled by the great trees of Mamre, welcomed the three heavenly visitors, and interceded for Sodom.",
					ImageURL:           "",
					Latitude:           31.5326,
					Longitude:          35.0998,
					RequiredChapterIDs: models.StringList{"GEN.13", "GEN.18"},
					UnlockedChapterID:  "GEN.18",
					PathPointIndex:     4,
				},
				{
					Slug:               "beersheba_abraham",
					Title:              "Beersheba",
					Description:        "The desert well in the Negev where Abraham made a covenant with Abimelech, planted a tamarisk tree, and called on the Eternal God.",
					ImageURL:           "",
					Latitude:           31.2450,
					Longitude:          34.8408,
					RequiredChapterIDs: models.StringList{"GEN.21"},
					UnlockedChapterID:  "GEN.21",
					PathPointIndex:     5,
				},
				{
					Slug:               "mount_moriah",
					Title:              "Mount Moriah",
					Description:        "The mountain where Abraham's faith was tested with Isaac and God provided a ram in the thicket, naming the place 'The Lord Will Provide.'",
					ImageURL:           "",
					Latitude:           31.7780,
					Longitude:          35.2354,
					RequiredChapterIDs: models.StringList{"GEN.22"},
					UnlockedChapterID:  "GEN.22",
					PathPointIndex:     6,
				},
			},
		},

		// 2. The Exodus
		{
			Slug:        "exodus",
			Name:        "The Exodus",
			Description: "The journey of the Israelites from Egypt to the Promised Land.",
			Points: models.PointList{
				{Lat: 30.7900, Lng: 31.9700}, // Rameses
				{Lat: 30.5500, Lng: 32.2200}, // Succoth
				{Lat: 30.3333, Lng: 32.5000}, // Etham
				{Lat: 29.9500, Lng: 32.5000}, // Pi-hahiroth
				{Lat: 29.9000, Lng: 32.5500}, // Crossing Red Sea
				{Lat: 29.3500, Lng: 32.9500}, // Marah
				{Lat: 29.2000, Lng: 33.1000}, // Elim
				{Lat: 28.8000, Lng: 33.3000}, // Wilderness of Sin
				{Lat: 28.6500, Lng: 33.6000}, // Rephidim
				{Lat: 28.5392, Lng: 33.9730}, // Mount Sinai
				{Lat: 28.7000, Lng: 34.1000}, // Taberah
				{Lat: 28.8500, Lng: 34.2500}, // Kibroth Hattaavah
				{Lat: 28.9500, Lng: 34.4500}, // Hazeroth
				{Lat: 30.6500, Lng: 34.4000}, // Kadesh Barnea
				{Lat: 30.3167, Lng: 35.4000}, // Mount Hor
				{Lat: 30.6000, Lng: 35.5000}, // Punon
				{Lat: 30.8000, Lng: 35.6000}, // Oboth
				{Lat: 31.0000, Lng: 35.7000}, // Iye Abarim
				{Lat: 31.8000, Lng: 35.6000}, // Plains of Moab
				{Lat: 31.7650, Lng: 35.7250}, // Mount Nebo
				{Lat: 31.8667, Lng: 35.4500}, // Jericho (End)
			},
			POIs: []models.MapPOI{
				{
					Slug:               "start_egypt",
					Title:              "Start of the Journey",
					Description:        "The Israelites begin their journey out of Egypt from Rameses.",
					ImageURL:           "assets/pois/egypt_start.png",
					Latitude:           30.7900,
					Longitude:          31.9700,
					RequiredChapterIDs: models.StringList{},
					UnlockedChapterID:  "EXO.1",
					PathPointIndex:     0,
				},
				{
					Slug:               "succoth",
					Title:              "Succoth",
					Description:        "The first campsite of the Israelites after leaving Rameses.",
					ImageURL:           "assets/models/succoth.png",
					Latitude:           30.5500,
					Longitude:          32.2200,
					RequiredChapterIDs: models.StringList{"EXO.12"},
					UnlockedChapterID:  "EXO.13",
					PathPointIndex:     1,
				},
				{
					Slug:               "etham",
					Title:              "Etham",
					Description:        "Camping on the edge of the wilderness, guided by the pillar of cloud and fire.",
					ImageURL:           "assets/models/etham.png",
					Latitude:           30.3333,
					Longitude:          32.5000,
					RequiredChapterIDs: models.StringList{"EXO.13"},
					UnlockedChapterID:  "EXO.13",
					PathPointIndex:     2,
				},
				{
					Slug:               "pi_hahiroth",
					Title:              "Pi-hahiroth",
					Description:        "Encamping by the sea, opposite Baal Zephon, as Pharaoh's chariots pursue.",
					ImageURL:           "assets/models/pi_hahiroth.png",
					Latitude:           29.9500,
					Longitude:          32.5000,
					RequiredChapterIDs: models.StringList{"EXO.14"},
					UnlockedChapterID:  "EXO.14",
					PathPointIndex:     3,
				},
				{
					Slug:               "crossing_sea",
					Title:              "Crossing the Red Sea",
					Description:        "God parts the Red Sea for the Israelites to cross on dry ground.",
					ImageURL:           "assets/pois/red_sea.png",
					Latitude:           29.9000,
					Longitude:          32.5500,
					RequiredChapterIDs: models.StringList{"EXO.14"},
					UnlockedChapterID:  "EXO.14",
					PathPointIndex:     4,
				},
				{
					Slug:               "marah",
					Title:              "Marah",
					Description:        "The bitter waters in the desert of Shur are made sweet when Moses casts in a piece of wood.",
					ImageURL:           "assets/models/marah.png",
					Latitude:           29.3500,
					Longitude:          32.9500,
					RequiredChapterIDs: models.StringList{"EXO.15"},
					UnlockedChapterID:  "EXO.15",
					PathPointIndex:     5,
				},
				{
					Slug:               "elim",
					Title:              "Elim",
					Description:        "Oasis of refreshment where Israel camped by twelve springs and seventy palm trees.",
					ImageURL:           "assets/models/elim.png",
					Latitude:           29.2000,
					Longitude:          33.1000,
					RequiredChapterIDs: models.StringList{"EXO.15"},
					UnlockedChapterID:  "EXO.15",
					PathPointIndex:     6,
				},
				{
					Slug:               "wilderness_sin",
					Title:              "Wilderness of Sin",
					Description:        "God provides manna from heaven each morning and quail in the evening.",
					ImageURL:           "assets/models/manna.png",
					Latitude:           28.8000,
					Longitude:          33.3000,
					RequiredChapterIDs: models.StringList{"EXO.16"},
					UnlockedChapterID:  "EXO.16",
					PathPointIndex:     7,
				},
				{
					Slug:               "rephidim",
					Title:              "Rephidim",
					Description:        "Water flows from the struck rock at Horeb and Joshua defeats the Amalekites while Moses' hands are held up.",
					ImageURL:           "assets/models/rephidim.png",
					Latitude:           28.6500,
					Longitude:          33.6000,
					RequiredChapterIDs: models.StringList{"EXO.17"},
					UnlockedChapterID:  "EXO.17",
					PathPointIndex:     8,
				},
				{
					Slug:               "mt_sinai",
					Title:              "Mount Sinai",
					Description:        "Moses receives the Ten Commandments and God establishes His covenant with Israel.",
					ImageURL:           "assets/models/mt_sinai.png",
					Latitude:           28.5392,
					Longitude:          33.9730,
					RequiredChapterIDs: models.StringList{"EXO.19", "EXO.20"},
					UnlockedChapterID:  "EXO.20",
					PathPointIndex:     9,
				},
				{
					Slug:               "taberah",
					Title:              "Taberah",
					Description:        "Fire from the Lord consumes the outskirts of the camp until Moses prays for the people.",
					ImageURL:           "assets/models/taberah.png",
					Latitude:           28.7000,
					Longitude:          34.1000,
					RequiredChapterIDs: models.StringList{"NUM.11"},
					UnlockedChapterID:  "NUM.11",
					PathPointIndex:     10,
				},
				{
					Slug:               "kibroth_hattaavah",
					Title:              "Kibroth Hattaavah",
					Description:        "Named 'Graves of Craving' after the people demanded meat in the wilderness.",
					ImageURL:           "assets/models/kibroth.png",
					Latitude:           28.8500,
					Longitude:          34.2500,
					RequiredChapterIDs: models.StringList{"NUM.11"},
					UnlockedChapterID:  "NUM.11",
					PathPointIndex:     11,
				},
				{
					Slug:               "hazeroth",
					Title:              "Hazeroth",
					Description:        "Miriam and Aaron speak against Moses, and Miriam is healed after Moses intercedes.",
					ImageURL:           "assets/models/hazeroth.png",
					Latitude:           28.9500,
					Longitude:          34.4500,
					RequiredChapterIDs: models.StringList{"NUM.12"},
					UnlockedChapterID:  "NUM.12",
					PathPointIndex:     12,
				},
				{
					Slug:               "kadesh_barnea",
					Title:              "Kadesh Barnea",
					Description:        "Twelve spies are sent into Canaan; only Caleb and Joshua urge the people to trust the Lord.",
					ImageURL:           "assets/models/kadesh.png",
					Latitude:           30.6500,
					Longitude:          34.4000,
					RequiredChapterIDs: models.StringList{"NUM.13", "NUM.14"},
					UnlockedChapterID:  "NUM.14",
					PathPointIndex:     13,
				},
				{
					Slug:               "mount_hor",
					Title:              "Mount Hor",
					Description:        "High mountain on the border of Edom where Aaron dies and Eleazar succeeds him as high priest.",
					ImageURL:           "assets/models/mt_hor.png",
					Latitude:           30.3167,
					Longitude:          35.4000,
					RequiredChapterIDs: models.StringList{"NUM.20"},
					UnlockedChapterID:  "NUM.20",
					PathPointIndex:     14,
				},
				{
					Slug:               "punon",
					Title:              "Punon (Bronze Serpent)",
					Description:        "Moses lifts up the bronze serpent on a pole so that anyone bitten who looks at it lives.",
					ImageURL:           "assets/models/punon.png",
					Latitude:           30.6000,
					Longitude:          35.5000,
					RequiredChapterIDs: models.StringList{"NUM.21"},
					UnlockedChapterID:  "NUM.21",
					PathPointIndex:     15,
				},
				{
					Slug:               "oboth",
					Title:              "Oboth",
					Description:        "Wilderness station east of Edom on the march toward Moab.",
					ImageURL:           "assets/models/oboth.png",
					Latitude:           30.8000,
					Longitude:          35.6000,
					RequiredChapterIDs: models.StringList{"NUM.21"},
					UnlockedChapterID:  "NUM.21",
					PathPointIndex:     16,
				},
				{
					Slug:               "iye_abarim",
					Title:              "Iye Abarim",
					Description:        "Encampment in the wilderness facing Moab toward the sunrise.",
					ImageURL:           "assets/models/iye_abarim.png",
					Latitude:           31.0000,
					Longitude:          35.7000,
					RequiredChapterIDs: models.StringList{"NUM.21"},
					UnlockedChapterID:  "NUM.21",
					PathPointIndex:     17,
				},
				{
					Slug:               "plains_moab",
					Title:              "Plains of Moab",
					Description:        "Israel camps along the Jordan across from Jericho, where Balaam blesses Israel instead of cursing.",
					ImageURL:           "assets/models/moab.png",
					Latitude:           31.8000,
					Longitude:          35.6000,
					RequiredChapterIDs: models.StringList{"NUM.22"},
					UnlockedChapterID:  "NUM.22",
					PathPointIndex:     18,
				},
				{
					Slug:               "mt_nebo",
					Title:              "Mount Nebo",
					Description:        "Moses views the whole Promised Land from Pisgah's peak before his death.",
					ImageURL:           "assets/models/mt_nebo.png",
					Latitude:           31.7650,
					Longitude:          35.7250,
					RequiredChapterIDs: models.StringList{"DEU.34"},
					UnlockedChapterID:  "DEU.34",
					PathPointIndex:     19,
				},
			},
		},

		// 3. Conquest of Canaan (Joshua)
		{
			Slug:        "joshua_conquest",
			Name:        "Conquest of Canaan",
			Description: "Joshua leads Israel across the Jordan River into the Promised Land (Joshua 3–11).",
			Points: models.PointList{
				{Lat: 31.8369, Lng: 35.5469}, // Jordan Crossing
				{Lat: 31.8550, Lng: 35.4850}, // Gilgal
				{Lat: 31.8711, Lng: 35.4442}, // Jericho
				{Lat: 31.9169, Lng: 35.2611}, // Ai
				{Lat: 32.2089, Lng: 35.2736}, // Mount Ebal & Gerizim
				{Lat: 31.8464, Lng: 35.1844}, // Gibeon
				{Lat: 33.0167, Lng: 35.5683}, // Hazor
			},
			POIs: []models.MapPOI{
				{
					Slug:               "jordan_crossing",
					Title:              "Crossing the Jordan",
					Description:        "The waters of the Jordan stand in a heap as the priests bearing the Ark step in, and Israel crosses on dry ground.",
					ImageURL:           "",
					Latitude:           31.8369,
					Longitude:          35.5469,
					RequiredChapterIDs: models.StringList{"JOS.3", "JOS.4"},
					UnlockedChapterID:  "JOS.4",
					PathPointIndex:     0,
				},
				{
					Slug:               "gilgal_camp",
					Title:              "Gilgal",
					Description:        "Israel sets up twelve memorial stones from the Jordan, renews the covenant, celebrates Passover, and eats the produce of Canaan as the manna ceases.",
					ImageURL:           "",
					Latitude:           31.8550,
					Longitude:          35.4850,
					RequiredChapterIDs: models.StringList{"JOS.5"},
					UnlockedChapterID:  "JOS.5",
					PathPointIndex:     1,
				},
				{
					Slug:               "jericho",
					Title:              "Jericho",
					Description:        "After Israel marches around the city for seven days and sounds the trumpets, the walls of Jericho fall flat and Rahab's household is spared.",
					ImageURL:           "",
					Latitude:           31.8711,
					Longitude:          35.4442,
					RequiredChapterIDs: models.StringList{"JOS.6"},
					UnlockedChapterID:  "JOS.6",
					PathPointIndex:     2,
				},
				{
					Slug:               "ai_battle",
					Title:              "Ai",
					Description:        "Following repentance over Achan's sin, Joshua captures Ai by strategic ambush in the central highlands.",
					ImageURL:           "",
					Latitude:           31.9169,
					Longitude:          35.2611,
					RequiredChapterIDs: models.StringList{"JOS.7", "JOS.8"},
					UnlockedChapterID:  "JOS.8",
					PathPointIndex:     3,
				},
				{
					Slug:               "mount_ebal_gerizim",
					Title:              "Mount Ebal & Mount Gerizim",
					Description:        "Joshua builds an altar on Mount Ebal and reads all the words of the Law—the blessings and the curses—before the whole assembly of Israel.",
					ImageURL:           "",
					Latitude:           32.2089,
					Longitude:          35.2736,
					RequiredChapterIDs: models.StringList{"JOS.8"},
					UnlockedChapterID:  "JOS.8",
					PathPointIndex:     4,
				},
				{
					Slug:               "gibeon",
					Title:              "Gibeon",
					Description:        "Joshua marches all night from Gilgal to defend Gibeon against five Amorite kings, and the sun stands still over Gibeon.",
					ImageURL:           "",
					Latitude:           31.8464,
					Longitude:          35.1844,
					RequiredChapterIDs: models.StringList{"JOS.10"},
					UnlockedChapterID:  "JOS.10",
					PathPointIndex:     5,
				},
				{
					Slug:               "hazor",
					Title:              "Hazor",
					Description:        "Head of all the northern Canaanite kingdoms, defeated by Joshua by the waters of Merom.",
					ImageURL:           "",
					Latitude:           33.0167,
					Longitude:          35.5683,
					RequiredChapterIDs: models.StringList{"JOS.11"},
					UnlockedChapterID:  "JOS.11",
					PathPointIndex:     6,
				},
			},
		},

		// 4. Life of David
		{
			Slug:        "life_of_david",
			Name:        "Life of David",
			Description: "From shepherd boy in Bethlehem to anointed King in Jerusalem (1 Samuel 16 – 2 Samuel 6).",
			Points: models.PointList{
				{Lat: 31.7054, Lng: 35.2024}, // Bethlehem
				{Lat: 31.6906, Lng: 34.9564}, // Valley of Elah
				{Lat: 31.6531, Lng: 34.9964}, // Cave of Adullam
				{Lat: 31.4619, Lng: 35.3889}, // En Gedi
				{Lat: 31.3911, Lng: 34.6800}, // Ziklag
				{Lat: 31.5326, Lng: 35.0998}, // Hebron
				{Lat: 31.7736, Lng: 35.2356}, // Jerusalem (City of David)
			},
			POIs: []models.MapPOI{
				{
					Slug:               "bethlehem_david",
					Title:              "Bethlehem (Anointing of David)",
					Description:        "Samuel anoints Jesse's youngest son David with oil, and the Spirit of the Lord rushes upon him from that day forward.",
					ImageURL:           "",
					Latitude:           31.7054,
					Longitude:          35.2024,
					RequiredChapterIDs: models.StringList{"1SA.16"},
					UnlockedChapterID:  "1SA.16",
					PathPointIndex:     0,
				},
				{
					Slug:               "valley_of_elah",
					Title:              "Valley of Elah",
					Description:        "David confronts the Philistine champion Goliath in the name of the Lord Almighty and strikes him down with a sling and a stone.",
					ImageURL:           "",
					Latitude:           31.6906,
					Longitude:          34.9564,
					RequiredChapterIDs: models.StringList{"1SA.17"},
					UnlockedChapterID:  "1SA.17",
					PathPointIndex:     1,
				},
				{
					Slug:               "cave_of_adullam",
					Title:              "Cave of Adullam",
					Description:        "Stronghold in the Judean foothills where David seeks refuge from Saul and gathers four hundred distressed men.",
					ImageURL:           "",
					Latitude:           31.6531,
					Longitude:          34.9964,
					RequiredChapterIDs: models.StringList{"1SA.22"},
					UnlockedChapterID:  "1SA.22",
					PathPointIndex:     2,
				},
				{
					Slug:               "en_gedi",
					Title:              "Wilderness of En Gedi",
					Description:        "Among the desert crags by the Dead Sea, David refuses to lift his hand against the Lord's anointed and spares Saul's life in a cave.",
					ImageURL:           "",
					Latitude:           31.4619,
					Longitude:          35.3889,
					RequiredChapterIDs: models.StringList{"1SA.24"},
					UnlockedChapterID:  "1SA.24",
					PathPointIndex:     3,
				},
				{
					Slug:               "ziklag",
					Title:              "Ziklag",
					Description:        "After Amalekites raid the town, David strengthens himself in the Lord his God, pursues the raiders, and recovers every person and possession.",
					ImageURL:           "",
					Latitude:           31.3911,
					Longitude:          34.6800,
					RequiredChapterIDs: models.StringList{"1SA.30"},
					UnlockedChapterID:  "1SA.30",
					PathPointIndex:     4,
				},
				{
					Slug:               "hebron_david",
					Title:              "Hebron (King over Judah)",
					Description:        "The men of Judah anoint David king at Hebron, where he reigns for seven and a half years before uniting all Israel.",
					ImageURL:           "",
					Latitude:           31.5326,
					Longitude:          35.0998,
					RequiredChapterIDs: models.StringList{"2SA.2"},
					UnlockedChapterID:  "2SA.2",
					PathPointIndex:     5,
				},
				{
					Slug:               "city_of_david",
					Title:              "Jerusalem (City of David)",
					Description:        "David captures the fortress of Zion, establishes Jerusalem as Israel's capital, and brings the Ark of the Covenant into the city with rejoicing.",
					ImageURL:           "",
					Latitude:           31.7736,
					Longitude:          35.2356,
					RequiredChapterIDs: models.StringList{"2SA.5", "2SA.6"},
					UnlockedChapterID:  "2SA.6",
					PathPointIndex:     6,
				},
			},
		},

		// 5. Elijah & Elisha
		{
			Slug:        "elijah_and_elisha",
			Name:        "Prophets Elijah & Elisha",
			Description: "Miracles and prophetic ministry across Israel, Phoenicia, and Sinai (1 Kings 17 – 2 Kings 5).",
			Points: models.PointList{
				{Lat: 32.3850, Lng: 35.6100}, // Brook Cherith
				{Lat: 33.4475, Lng: 35.2975}, // Zarephath
				{Lat: 32.6486, Lng: 35.0908}, // Mount Carmel
				{Lat: 31.2350, Lng: 34.7900}, // Beersheba Wilderness
				{Lat: 28.5392, Lng: 33.9730}, // Mount Horeb
				{Lat: 31.8369, Lng: 35.5469}, // Jordan River
				{Lat: 32.6056, Lng: 35.3342}, // Shunem
			},
			POIs: []models.MapPOI{
				{
					Slug:               "brook_cherith",
					Title:              "Brook Cherith",
					Description:        "Ravine east of the Jordan where Elijah hides during the drought and ravens bring him bread and meat morning and evening.",
					ImageURL:           "",
					Latitude:           32.3850,
					Longitude:          35.6100,
					RequiredChapterIDs: models.StringList{"1KI.17"},
					UnlockedChapterID:  "1KI.17",
					PathPointIndex:     0,
				},
				{
					Slug:               "zarephath",
					Title:              "Zarephath",
					Description:        "Phoenician town where the widow's jar of flour and jug of oil never run dry and the Lord restores her son to life through Elijah's prayer.",
					ImageURL:           "",
					Latitude:           33.4475,
					Longitude:          35.2975,
					RequiredChapterIDs: models.StringList{"1KI.17"},
					UnlockedChapterID:  "1KI.17",
					PathPointIndex:     1,
				},
				{
					Slug:               "mount_carmel",
					Title:              "Mount Carmel",
					Description:        "Elijah repairs the altar of the Lord and fire falls from heaven, consuming the sacrifice, wood, stones, and water before all Israel.",
					ImageURL:           "",
					Latitude:           32.6486,
					Longitude:          35.0908,
					RequiredChapterIDs: models.StringList{"1KI.18"},
					UnlockedChapterID:  "1KI.18",
					PathPointIndex:     2,
				},
				{
					Slug:               "beersheba_elijah",
					Title:              "Wilderness of Beersheba",
					Description:        "Fleeing Jezebel, an exhausted Elijah sleeps under a broom bush where an angel provides warm bread and water for a forty-day journey.",
					ImageURL:           "",
					Latitude:           31.2350,
					Longitude:          34.7900,
					RequiredChapterIDs: models.StringList{"1KI.19"},
					UnlockedChapterID:  "1KI.19",
					PathPointIndex:     3,
				},
				{
					Slug:               "horeb_elijah",
					Title:              "Mount Horeb (Gentle Whisper)",
					Description:        "At the mountain of God, the Lord speaks to Elijah not in the wind, earthquake, or fire, but in a still, small voice.",
					ImageURL:           "",
					Latitude:           28.5392,
					Longitude:          33.9730,
					RequiredChapterIDs: models.StringList{"1KI.19"},
					UnlockedChapterID:  "1KI.19",
					PathPointIndex:     4,
				},
				{
					Slug:               "jordan_elijah_elisha",
					Title:              "Jordan River (Chariot of Fire)",
					Description:        "Elijah parts the Jordan with his cloak, Elisha receives a double portion of his spirit, and Elijah ascends in a whirlwind by a chariot of fire.",
					ImageURL:           "",
					Latitude:           31.8369,
					Longitude:          35.5469,
					RequiredChapterIDs: models.StringList{"2KI.2"},
					UnlockedChapterID:  "2KI.2",
					PathPointIndex:     5,
				},
				{
					Slug:               "shunem",
					Title:              "Shunem",
					Description:        "Village in the Jezreel Valley where a hospitable woman prepares a room for Elisha and Elisha raises her son back to life.",
					ImageURL:           "",
					Latitude:           32.6056,
					Longitude:          35.3342,
					RequiredChapterIDs: models.StringList{"2KI.4"},
					UnlockedChapterID:  "2KI.4",
					PathPointIndex:     6,
				},
			},
		},

		// 6. Ministry of Jesus
		{
			Slug:        "ministry_of_jesus",
			Name:        "Life & Ministry of Jesus",
			Description: "Key locations from Jesus' birth in Bethlehem through His Galilean ministry to the Cross and Empty Tomb in Jerusalem.",
			Points: models.PointList{
				{Lat: 31.7054, Lng: 35.2024}, // Bethlehem
				{Lat: 32.7022, Lng: 35.2978}, // Nazareth
				{Lat: 31.8369, Lng: 35.5469}, // Jordan Baptism
				{Lat: 32.7475, Lng: 35.3381}, // Cana
				{Lat: 32.2122, Lng: 35.2858}, // Sychar
				{Lat: 32.8803, Lng: 35.5753}, // Capernaum
				{Lat: 32.8819, Lng: 35.5558}, // Mount of Beatitudes
				{Lat: 32.8231, Lng: 35.5831}, // Sea of Galilee
				{Lat: 33.2483, Lng: 35.6939}, // Caesarea Philippi
				{Lat: 31.7714, Lng: 35.2614}, // Bethany
				{Lat: 31.7794, Lng: 35.2403}, // Gethsemane
				{Lat: 31.7784, Lng: 35.2297}, // Golgotha & Garden Tomb
			},
			POIs: []models.MapPOI{
				{
					Slug:               "bethlehem_nativity",
					Title:              "Bethlehem (Birth of Jesus)",
					Description:        "In the city of David, Jesus is born, wrapped in cloths, and laid in a manger as angels proclaim good news of great joy to the shepherds.",
					ImageURL:           "",
					Latitude:           31.7054,
					Longitude:          35.2024,
					RequiredChapterIDs: models.StringList{"LUK.2"},
					UnlockedChapterID:  "LUK.2",
					PathPointIndex:     0,
				},
				{
					Slug:               "nazareth",
					Title:              "Nazareth",
					Description:        "Hometown where Jesus grew in wisdom and stature, and where He read from the scroll of Isaiah in the synagogue.",
					ImageURL:           "",
					Latitude:           32.7022,
					Longitude:          35.2978,
					RequiredChapterIDs: models.StringList{"LUK.4"},
					UnlockedChapterID:  "LUK.4",
					PathPointIndex:     1,
				},
				{
					Slug:               "baptism_of_jesus",
					Title:              "Jordan River (Baptism of Jesus)",
					Description:        "John baptizes Jesus in the Jordan; the heavens open, the Spirit descends like a dove, and the Father declares, 'This is My beloved Son.'",
					ImageURL:           "",
					Latitude:           31.8369,
					Longitude:          35.5469,
					RequiredChapterIDs: models.StringList{"MAT.3"},
					UnlockedChapterID:  "MAT.3",
					PathPointIndex:     2,
				},
				{
					Slug:               "cana_galilee",
					Title:              "Cana of Galilee",
					Description:        "Where Jesus performs the first of His signs at a wedding feast, turning water into choice wine and manifesting His glory.",
					ImageURL:           "",
					Latitude:           32.7475,
					Longitude:          35.3381,
					RequiredChapterIDs: models.StringList{"JHN.2"},
					UnlockedChapterID:  "JHN.2",
					PathPointIndex:     3,
				},
				{
					Slug:               "sychar_jacobs_well",
					Title:              "Sychar (Jacob's Well)",
					Description:        "In Samaria, Jesus offers the Samaritan woman living water that becomes a spring welling up to eternal life.",
					ImageURL:           "",
					Latitude:           32.2122,
					Longitude:          35.2858,
					RequiredChapterIDs: models.StringList{"JHN.4"},
					UnlockedChapterID:  "JHN.4",
					PathPointIndex:     4,
				},
				{
					Slug:               "capernaum",
					Title:              "Capernaum",
					Description:        "Center of Jesus' Galilean ministry where He teaches with authority, heals Peter's mother-in-law, and forgives and heals the paralytic lowered through the roof.",
					ImageURL:           "",
					Latitude:           32.8803,
					Longitude:          35.5753,
					RequiredChapterIDs: models.StringList{"MRK.1", "MRK.2"},
					UnlockedChapterID:  "MRK.2",
					PathPointIndex:     5,
				},
				{
					Slug:               "mount_of_beatitudes",
					Title:              "Mount of Beatitudes",
					Description:        "Hillside above the Sea of Galilee where Jesus delivers the Sermon on the Mount, teaching the Beatitudes and the Lord's Prayer.",
					ImageURL:           "",
					Latitude:           32.8819,
					Longitude:          35.5558,
					RequiredChapterIDs: models.StringList{"MAT.5", "MAT.6", "MAT.7"},
					UnlockedChapterID:  "MAT.7",
					PathPointIndex:     6,
				},
				{
					Slug:               "sea_of_galilee",
					Title:              "Sea of Galilee",
					Description:        "Where Jesus rebukes the wind and waves with 'Peace, be still!' and walks across the water to His disciples in the night.",
					ImageURL:           "",
					Latitude:           32.8231,
					Longitude:          35.5831,
					RequiredChapterIDs: models.StringList{"MAT.14"},
					UnlockedChapterID:  "MAT.14",
					PathPointIndex:     7,
				},
				{
					Slug:               "caesarea_philippi",
					Title:              "Caesarea Philippi",
					Description:        "At the foot of Mount Hermon, Simon Peter confesses to Jesus, 'You are the Christ, the Son of the living God.'",
					ImageURL:           "",
					Latitude:           33.2483,
					Longitude:          35.6939,
					RequiredChapterIDs: models.StringList{"MAT.16"},
					UnlockedChapterID:  "MAT.16",
					PathPointIndex:     8,
				},
				{
					Slug:               "bethany",
					Title:              "Bethany",
					Description:        "Home of Mary, Martha, and Lazarus on the Mount of Olives, where Jesus proclaims 'I am the resurrection and the life' and calls Lazarus from the tomb.",
					ImageURL:           "",
					Latitude:           31.7714,
					Longitude:          35.2614,
					RequiredChapterIDs: models.StringList{"JHN.11"},
					UnlockedChapterID:  "JHN.11",
					PathPointIndex:     9,
				},
				{
					Slug:               "gethsemane",
					Title:              "Garden of Gethsemane",
					Description:        "Olive grove across the Kidron Valley where Jesus prays in deep anguish before His arrest: 'Not My will, but Yours be done.'",
					ImageURL:           "",
					Latitude:           31.7794,
					Longitude:          35.2403,
					RequiredChapterIDs: models.StringList{"MAT.26"},
					UnlockedChapterID:  "MAT.26",
					PathPointIndex:     10,
				},
				{
					Slug:               "golgotha_empty_tomb",
					Title:              "Golgotha & The Empty Tomb",
					Description:        "Outside Jerusalem's walls where Jesus was crucified for our redemption, laid in a new tomb, and rose from the dead on the first day of the week.",
					ImageURL:           "",
					Latitude:           31.7784,
					Longitude:          35.2297,
					RequiredChapterIDs: models.StringList{"JHN.19", "JHN.20"},
					UnlockedChapterID:  "JHN.20",
					PathPointIndex:     11,
				},
			},
		},

		// 7. Paul's First Missionary Journey
		{
			Slug:        "pauls_first_journey",
			Name:        "Paul's First Missionary Journey",
			Description: "Paul and Barnabas travel to Cyprus and Galatia (Acts 13–14).",
			Points: models.PointList{
				{Lat: 36.2021, Lng: 36.1606}, // Antioch (Syria)
				{Lat: 36.1260, Lng: 35.9220}, // Seleucia
				{Lat: 35.1558, Lng: 33.9030}, // Salamis
				{Lat: 34.7733, Lng: 32.4233}, // Paphos
				{Lat: 36.9583, Lng: 30.8500}, // Perga
				{Lat: 38.3000, Lng: 31.1833}, // Antioch (Pisidia)
				{Lat: 37.8667, Lng: 32.4833}, // Iconium
				{Lat: 37.5667, Lng: 32.1833}, // Lystra
				{Lat: 37.3500, Lng: 33.1667}, // Derbe
				{Lat: 37.5667, Lng: 32.1833}, // Lystra (Return)
				{Lat: 37.8667, Lng: 32.4833}, // Iconium (Return)
				{Lat: 38.3000, Lng: 31.1833}, // Antioch (Pisidia) (Return)
				{Lat: 36.9583, Lng: 30.8500}, // Perga (Return)
				{Lat: 36.8833, Lng: 30.7000}, // Attalia
				{Lat: 36.1260, Lng: 35.9220}, // Seleucia (Return)
				{Lat: 36.2021, Lng: 36.1606}, // Antioch (Syria) (End)
			},
			POIs: []models.MapPOI{
				{
					Slug:               "antioch_syria",
					Title:              "Antioch (Syria)",
					Description:        "The Holy Spirit sets apart Barnabas and Saul for the missionary work to which He has called them.",
					ImageURL:           "assets/models/antioch_syria.png",
					Latitude:           36.2021,
					Longitude:          36.1606,
					RequiredChapterIDs: models.StringList{"ACT.13"},
					UnlockedChapterID:  "ACT.13",
					PathPointIndex:     0,
				},
				{
					Slug:               "seleucia",
					Title:              "Seleucia",
					Description:        "Mediterranean port city from which Barnabas and Saul set sail for the island of Cyprus.",
					ImageURL:           "assets/models/seleucia.png",
					Latitude:           36.1260,
					Longitude:          35.9220,
					RequiredChapterIDs: models.StringList{"ACT.13"},
					UnlockedChapterID:  "ACT.13",
					PathPointIndex:     1,
				},
				{
					Slug:               "salamis",
					Title:              "Salamis",
					Description:        "Eastern port of Cyprus where they proclaimed the word of God in the Jewish synagogues with John Mark assisting.",
					ImageURL:           "assets/models/salamis.png",
					Latitude:           35.1558,
					Longitude:          33.9030,
					RequiredChapterIDs: models.StringList{"ACT.13"},
					UnlockedChapterID:  "ACT.13",
					PathPointIndex:     2,
				},
				{
					Slug:               "paphos",
					Title:              "Paphos",
					Description:        "Elymas the sorcerer is struck with temporary blindness, and the Roman proconsul Sergius Paulus believes, astonished at the teaching of the Lord.",
					ImageURL:           "assets/models/paphos.png",
					Latitude:           34.7733,
					Longitude:          32.4233,
					RequiredChapterIDs: models.StringList{"ACT.13"},
					UnlockedChapterID:  "ACT.13",
					PathPointIndex:     3,
				},
				{
					Slug:               "perga",
					Title:              "Perga in Pamphylia",
					Description:        "After sailing from Paphos to Asia Minor, John Mark leaves them here to return to Jerusalem.",
					ImageURL:           "assets/models/perga.png",
					Latitude:           36.9583,
					Longitude:          30.8500,
					RequiredChapterIDs: models.StringList{"ACT.13"},
					UnlockedChapterID:  "ACT.13",
					PathPointIndex:     4,
				},
				{
					Slug:               "antioch_pisidia",
					Title:              "Antioch in Pisidia",
					Description:        "Paul preaches the fulfillment of God's promises in Jesus; the Gentiles rejoice and the word of the Lord spreads through the whole region.",
					ImageURL:           "assets/models/antioch_pisidia.png",
					Latitude:           38.3000,
					Longitude:          31.1833,
					RequiredChapterIDs: models.StringList{"ACT.13"},
					UnlockedChapterID:  "ACT.13",
					PathPointIndex:     5,
				},
				{
					Slug:               "iconium",
					Title:              "Iconium",
					Description:        "Paul and Barnabas speak boldly for the Lord, who confirms the message of His grace by enabling them to perform signs and wonders.",
					ImageURL:           "assets/models/iconium.png",
					Latitude:           37.8667,
					Longitude:          32.4833,
					RequiredChapterIDs: models.StringList{"ACT.14"},
					UnlockedChapterID:  "ACT.14",
					PathPointIndex:     6,
				},
				{
					Slug:               "lystra",
					Title:              "Lystra",
					Description:        "Paul heals a man crippled from birth; after refusing to be worshiped as gods, Paul is stoned, rises up, and continues preaching.",
					ImageURL:           "assets/models/lystra.png",
					Latitude:           37.5667,
					Longitude:          32.1833,
					RequiredChapterIDs: models.StringList{"ACT.14"},
					UnlockedChapterID:  "ACT.14",
					PathPointIndex:     7,
				},
				{
					Slug:               "derbe",
					Title:              "Derbe",
					Description:        "Easternmost city of the journey where Paul and Barnabas preach the gospel and win a large number of disciples before retracing their steps to strengthen the churches.",
					ImageURL:           "assets/models/derbe.png",
					Latitude:           37.3500,
					Longitude:          33.1667,
					RequiredChapterIDs: models.StringList{"ACT.14"},
					UnlockedChapterID:  "ACT.14",
					PathPointIndex:     8,
				},
				{
					Slug:               "attalia",
					Title:              "Attalia",
					Description:        "Coastal port in Pamphylia from which Paul and Barnabas sail back to Syrian Antioch to report all that God had done.",
					ImageURL:           "assets/models/attalia.png",
					Latitude:           36.8833,
					Longitude:          30.7000,
					RequiredChapterIDs: models.StringList{"ACT.14"},
					UnlockedChapterID:  "ACT.14",
					PathPointIndex:     13,
				},
			},
		},

		// 8. Paul's Second Missionary Journey
		{
			Slug:        "pauls_second_journey",
			Name:        "Paul's Second Missionary Journey",
			Description: "The Gospel crosses into Europe: Macedonia, Greece, and Asia Minor (Acts 16–18).",
			Points: models.PointList{
				{Lat: 39.7594, Lng: 26.1536}, // Troas
				{Lat: 41.0131, Lng: 24.2872}, // Philippi
				{Lat: 40.6401, Lng: 22.9444}, // Thessalonica
				{Lat: 40.5244, Lng: 22.2028}, // Berea
				{Lat: 37.9722, Lng: 23.7233}, // Athens
				{Lat: 37.9061, Lng: 22.8806}, // Corinth
				{Lat: 37.9411, Lng: 27.3419}, // Ephesus
			},
			POIs: []models.MapPOI{
				{
					Slug:               "troas",
					Title:              "Troas (Macedonian Call)",
					Description:        "Aegean port where Paul receives a night vision of a man of Macedonia standing and begging, 'Come over to Macedonia and help us.'",
					ImageURL:           "",
					Latitude:           39.7594,
					Longitude:          26.1536,
					RequiredChapterIDs: models.StringList{"ACT.16"},
					UnlockedChapterID:  "ACT.16",
					PathPointIndex:     0,
				},
				{
					Slug:               "philippi",
					Title:              "Philippi",
					Description:        "The Lord opens Lydia's heart by the river, and after Paul and Silas pray and sing hymns at midnight in prison, an earthquake leads to the jailer's household believing.",
					ImageURL:           "",
					Latitude:           41.0131,
					Longitude:          24.2872,
					RequiredChapterIDs: models.StringList{"ACT.16"},
					UnlockedChapterID:  "ACT.16",
					PathPointIndex:     1,
				},
				{
					Slug:               "thessalonica",
					Title:              "Thessalonica",
					Description:        "For three Sabbaths Paul reasons from the Scriptures in the synagogue, explaining and proving that the Christ had to suffer and rise from the dead.",
					ImageURL:           "",
					Latitude:           40.6401,
					Longitude:          22.9444,
					RequiredChapterIDs: models.StringList{"ACT.17"},
					UnlockedChapterID:  "ACT.17",
					PathPointIndex:     2,
				},
				{
					Slug:               "berea",
					Title:              "Berea",
					Description:        "The Bereans are of more noble character, receiving the message with great eagerness and examining the Scriptures every day.",
					ImageURL:           "",
					Latitude:           40.5244,
					Longitude:          22.2028,
					RequiredChapterIDs: models.StringList{"ACT.17"},
					UnlockedChapterID:  "ACT.17",
					PathPointIndex:     3,
				},
				{
					Slug:               "athens_areopagus",
					Title:              "Athens (Mars Hill)",
					Description:        "Standing in the midst of the Areopagus, Paul proclaims the God who made the world and everything in it and calls all people to repent.",
					ImageURL:           "",
					Latitude:           37.9722,
					Longitude:          23.7233,
					RequiredChapterIDs: models.StringList{"ACT.17"},
					UnlockedChapterID:  "ACT.17",
					PathPointIndex:     4,
				},
				{
					Slug:               "corinth",
					Title:              "Corinth",
					Description:        "Paul stays a year and a half working alongside Aquila and Priscilla and teaching the word of God after the Lord assures him, 'I have many people in this city.'",
					ImageURL:           "",
					Latitude:           37.9061,
					Longitude:          22.8806,
					RequiredChapterIDs: models.StringList{"ACT.18"},
					UnlockedChapterID:  "ACT.18",
					PathPointIndex:     5,
				},
				{
					Slug:               "ephesus_paul",
					Title:              "Ephesus",
					Description:        "Major metropolis of Asia Minor where Paul reasons in the synagogue and later teaches daily in the hall of Tyrannus so that all in Asia hear the word of the Lord.",
					ImageURL:           "",
					Latitude:           37.9411,
					Longitude:          27.3419,
					RequiredChapterIDs: models.StringList{"ACT.18", "ACT.19"},
					UnlockedChapterID:  "ACT.19",
					PathPointIndex:     6,
				},
			},
		},

		// 9. Paul's Journey to Rome
		{
			Slug:        "pauls_journey_to_rome",
			Name:        "Paul's Journey to Rome",
			Description: "From imprisonment in Caesarea through tempest and shipwreck to witnessing in Rome (Acts 27–28).",
			Points: models.PointList{
				{Lat: 32.5000, Lng: 34.8917}, // Caesarea Maritima
				{Lat: 34.9281, Lng: 24.8086}, // Fair Havens (Crete)
				{Lat: 35.9469, Lng: 14.4028}, // Malta
				{Lat: 41.8902, Lng: 12.4922}, // Rome
			},
			POIs: []models.MapPOI{
				{
					Slug:               "caesarea_maritima",
					Title:              "Caesarea Maritima",
					Description:        "Roman coastal capital where Paul testifies before Festus and King Agrippa, appeals to Caesar, and boards a ship bound for Italy.",
					ImageURL:           "",
					Latitude:           32.5000,
					Longitude:          34.8917,
					RequiredChapterIDs: models.StringList{"ACT.25", "ACT.27"},
					UnlockedChapterID:  "ACT.27",
					PathPointIndex:     0,
				},
				{
					Slug:               "fair_havens_crete",
					Title:              "Fair Havens (Crete)",
					Description:        "Southern harbor of Crete where Paul warns the centurion that continuing the voyage in late autumn will bring disaster, before the ship is caught by the Northeaster storm.",
					ImageURL:           "",
					Latitude:           34.9281,
					Longitude:          24.8086,
					RequiredChapterIDs: models.StringList{"ACT.27"},
					UnlockedChapterID:  "ACT.27",
					PathPointIndex:     1,
				},
				{
					Slug:               "malta_shipwreck",
					Title:              "Island of Malta",
					Description:        "Just as God promised Paul through an angel, all 276 people aboard survive the shipwreck on Malta, where Paul is unharmed by a viper and heals Publius's father.",
					ImageURL:           "",
					Latitude:           35.9469,
					Longitude:          14.4028,
					RequiredChapterIDs: models.StringList{"ACT.28"},
					UnlockedChapterID:  "ACT.28",
					PathPointIndex:     2,
				},
				{
					Slug:               "rome_paul",
					Title:              "Rome",
					Description:        "For two whole years Paul stays in his own rented house in Rome, welcoming all who come to him and proclaiming the kingdom of God and teaching about the Lord Jesus Christ with all boldness and without hindrance.",
					ImageURL:           "",
					Latitude:           41.8902,
					Longitude:          12.4922,
					RequiredChapterIDs: models.StringList{"ACT.28"},
					UnlockedChapterID:  "ACT.28",
					PathPointIndex:     3,
				},
			},
		},
	}
}
