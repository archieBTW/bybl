package database

import (
	"log"
	"theword/Backend/lib/models"
	"time"

	"gorm.io/gorm"
)

func SeedDatabase(db *gorm.DB) {
	// Check if we already have churches
	var count int64
	db.Model(&models.Church{}).Count(&count)
	if count > 0 {
		log.Println("Database already seeded")
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
			TranslationId:   "ESV",
			TranslationName: "English Standard Version",
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
			TranslationId:   "ESV",
			TranslationName: "English Standard Version",
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
			TranslationId:   "ESV",
			TranslationName: "English Standard Version",
			IsAdmin:         false,
		},
	}

	for i := range users {
		if err := db.Create(&users[i]).Error; err != nil {
			log.Printf("Error creating user: %v", err)
			continue
		}

		// Create saved verses for each user
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

			// Create comments for each verse
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

				// Create likes for some comments
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

		// Create friend relationships
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

		// Create notifications
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

	// Create sample churches
	churches := []models.Church{}

	for i := range churches {
		if err := db.Create(&churches[i]).Error; err != nil {
			log.Printf("Error creating church: %v", err)
			continue
		}

		// Create sample groups for each church
		groups := []models.SmallGroup{
			{
				Name:            "Youth Group",
				Description:     "A group for teenagers to grow in their faith",
				MeetingDay:      "Wednesday",
				MeetingTime:     "6:00 PM",
				MeetingLocation: "Church Fellowship Hall",
				MemberCount:     15,
			},
			{
				Name:            "Bible Study",
				Description:     "Weekly Bible study for adults",
				MeetingDay:      "Thursday",
				MeetingTime:     "7:00 PM",
				MeetingLocation: "Church Library",
				MemberCount:     10,
			},
		}

		for j := range groups {
			groups[j].ChurchID = churches[i].ChurchID
			if err := db.Create(&groups[j]).Error; err != nil {
				log.Printf("Error creating group: %v", err)
				continue
			}

			// Create sample events for each group
			events := []models.ChurchEvent{
				{
					Title:       "Summer Retreat",
					Description: "Annual summer retreat for the group",
					StartTime:   time.Now().AddDate(0, 1, 0),
					EndTime:     time.Now().AddDate(0, 1, 2),
					Location:    "Camp Grounds",
					GroupID:     groups[j].GroupID,
					GroupName:   groups[j].Name,
				},
				{
					Title:       "Bible Study Series",
					Description: "New series on the book of Romans",
					StartTime:   time.Now().AddDate(0, 0, 7),
					EndTime:     time.Now().AddDate(0, 0, 7).Add(time.Hour * 2),
					Location:    groups[j].MeetingLocation,
					GroupID:     groups[j].GroupID,
					GroupName:   groups[j].Name,
				},
			}

			for k := range events {
				events[k].ChurchID = churches[i].ChurchID
				if err := db.Create(&events[k]).Error; err != nil {
					log.Printf("Error creating event: %v", err)
				}
			}

			// Create sample messages for each group
			messages := []models.Message{
				{
					Title:    "Weekly Announcements",
					Content:  "Don't forget about our upcoming events!",
					ChurchID: churches[i].ChurchID,
					GroupID:  groups[j].GroupID,
				},
				{
					Title:    "Prayer Requests",
					Content:  "Please keep our members in your prayers",
					ChurchID: churches[i].ChurchID,
					GroupID:  groups[j].GroupID,
				},
			}

			for k := range messages {
				if err := db.Create(&messages[k]).Error; err != nil {
					log.Printf("Error creating message: %v", err)
				}
			}

			// Create sample prayer requests for each group
			prayerRequests := []models.PrayerRequest{
				{
					Content:     "Pray for healing for our member who is sick",
					IsAnonymous: false,
					ChurchID:    churches[i].ChurchID,
					GroupID:     groups[j].GroupID,
				},
				{
					Content:     "Pray for guidance in our upcoming decisions",
					IsAnonymous: true,
					ChurchID:    churches[i].ChurchID,
					GroupID:     groups[j].GroupID,
				},
			}

			for k := range prayerRequests {
				if err := db.Create(&prayerRequests[k]).Error; err != nil {
					log.Printf("Error creating prayer request: %v", err)
				}
			}
		}
	}

	log.Println("Database seeded successfully")
}
