package main

import (
	"fmt"
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"theword/Backend/lib/database"
	"theword/Backend/lib/handlers"
	"theword/Backend/lib/middleware"
	"theword/Backend/lib/models"
)

var db *gorm.DB

func main() {
	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")
	dbHost := os.Getenv("DB_HOST")
	bibleApiKey := os.Getenv("BIBLE_KEY")
	esvApiKey := os.Getenv("ESV_KEY")

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=5432 sslmode=disable",
		dbHost, dbUser, dbPassword, dbName)

	var err error
	db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	// Add MapPOI and BibleMapPath to migration
	db.AutoMigrate(
		&models.Bookmark{}, &models.User{}, &models.UserVerse{}, &models.Like{}, &models.Comment{},
		&models.Friend{}, &models.Notification{}, &models.Church{}, &models.SmallGroup{},
		&models.ChurchEvent{}, &models.Message{}, &models.PrayerRequest{}, &models.GroupMember{},
		&models.MapPOI{}, &models.BibleMapPath{},
	)
	log.Println("Database tables created or already exist.")

	// Seed the database with initial data
	database.SeedDatabase(db)

	handlers.CreateAdminUser(db)

	r := gin.Default()

	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// --- Map Admin & Data Routes ---
	r.Static("/uploads", "./uploads") // Serve uploaded images
	r.GET("/admin/map", handlers.ServeAdminPanel)
	r.GET("/api/map/data", handlers.GetMapData(db))

	// Admin Auth Routes
	r.POST("/api/admin/login", handlers.LoginAdmin(db))
	r.POST("/api/admin/change-password", middleware.AdminAuthMiddleware, handlers.AdminChangePassword(db))
	r.GET("/api/admin/check-auth", middleware.AdminAuthMiddleware, handlers.CheckAuthStatus(db))

	// Map Admin API (Protected)
	adminMap := r.Group("/api/map")
	adminMap.Use(middleware.AdminAuthMiddleware)
	{
		adminMap.POST("/poi", handlers.CreatePOI(db))
		adminMap.PUT("/poi/:id", handlers.UpdatePOI(db))
		adminMap.DELETE("/poi/:id", handlers.DeletePOI(db))
		adminMap.POST("/path", handlers.CreatePath(db))
		adminMap.PUT("/path/:id", handlers.UpdatePath(db))
		adminMap.DELETE("/path/:id", handlers.DeletePath(db))
		adminMap.POST("/upload-image", handlers.UploadPOIImage)
	}

	// --- Existing GET Routes (Preserved) ---
	// User stats/info (GETs preserved)
	r.GET("/api/user/settings", middleware.AuthMiddleware, handlers.GetUserSettings(db))
	r.GET("/api/user/:id", middleware.AuthMiddleware, handlers.GetUser(db))

	// Verses
	r.GET("/api/verse/:id", middleware.AuthMiddleware, handlers.GetVerse(db))
	r.GET("/api/verses/public", middleware.AuthMiddleware, handlers.GetPublicVerses(db))
	r.GET("/api/verses/public/search", middleware.AuthMiddleware, handlers.SearchPublicVerses(db))
	r.GET("/api/verses/saved", middleware.AuthMiddleware, handlers.GetSavedVerses(db))
	r.GET("/api/verses/saved/search", middleware.AuthMiddleware, handlers.SearchSavedVerses(db))

	r.GET("/api/verse/:id/comments", middleware.AuthMiddleware, handlers.GetComments(db))
	r.GET("/api/verse/:id/likes", middleware.AuthMiddleware, handlers.GetLikesCount(db))
	r.GET("/api/verse/:id/comments/count", middleware.AuthMiddleware, handlers.GetCommentCount(db))
	r.GET("/api/commentRequests", middleware.AuthMiddleware, handlers.GetCommentRequests(db))

	r.GET("/api/friends/suggested", middleware.AuthMiddleware, handlers.ListSuggestedFriends(db))
	r.GET("/api/friends", middleware.AuthMiddleware, handlers.ListFriends(db))
	r.GET("/api/friends/search", middleware.AuthMiddleware, handlers.SearchFriends(db))
	r.GET("/api/friends/requests", middleware.AuthMiddleware, handlers.ListFriendRequests(db))

	// Churches
	r.GET("/api/churches", middleware.AuthMiddleware, handlers.GetChurches(db))
	r.GET("/api/churches/:id", middleware.AuthMiddleware, handlers.GetChurchDetails(db))

	// Groups
	r.GET("/api/churches/:id/groups", handlers.GetChurchGroups(db))
	r.GET("/api/groups/:id", middleware.AuthMiddleware, handlers.GetGroupDetails(db))

	// Events
	r.GET("/api/churches/:id/events", middleware.AuthMiddleware, handlers.GetChurchEvents(db))
	r.GET("/api/groups/:id/events", middleware.AuthMiddleware, handlers.GetGroupEvents(db))

	// Messages
	r.GET("/api/churches/:id/messages", middleware.AuthMiddleware, handlers.GetChurchMessages(db))
	r.GET("/api/groups/:id/messages", middleware.AuthMiddleware, handlers.GetGroupMessages(db))

	// Prayers
	r.GET("/api/churches/:id/prayers", middleware.AuthMiddleware, handlers.GetChurchPrayerRequests(db))
	r.GET("/api/groups/:id/prayers", middleware.AuthMiddleware, handlers.GetGroupPrayerRequests(db))

	// Leaders
	r.GET("/api/church-leaders/:id", middleware.AuthMiddleware, handlers.GetChurchLeader(db))

	// Bible
	r.GET("/api/bible/translations", handlers.GetBibleTranslations(bibleApiKey))
	r.GET("/api/bible/:bibleId/books", handlers.GetBibleBooks(bibleApiKey))
	r.GET("/api/bible/:bibleId/books/:bookId/chapters", handlers.GetBibleChapters(bibleApiKey))
	r.GET("/api/passage/:translationId", handlers.GetBiblePassage(bibleApiKey, esvApiKey))

	r.GET("/api/users/:id", middleware.AuthMiddleware, handlers.GetUserByID(db))
	r.GET("/api/avatar", handlers.GetAvatarHandler(db))

	r.GET("/api/bookmarks", middleware.AuthMiddleware, handlers.GetBookmarks(db))

	r.Run()
}
