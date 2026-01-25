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
	chatApiKey := os.Getenv("OPENAI_KEY")
	bibleApiKey := os.Getenv("BIBLE_KEY")
	esvApiKey := os.Getenv("ESV_KEY")

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=5432 sslmode=disable",
		dbHost, dbUser, dbPassword, dbName)

	var err error
	db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	db.AutoMigrate(&models.Bookmark{}, &models.User{}, &models.UserVerse{}, &models.Like{}, &models.Comment{}, &models.Friend{}, &models.Notification{}, &models.Church{}, &models.SmallGroup{}, &models.ChurchEvent{}, &models.Message{}, &models.PrayerRequest{}, &models.GroupMember{})
	log.Println("Database tables created or already exist.")

	// Seed the database with initial data
	database.SeedDatabase(db)

	handlers.CreateAdminUser(db)

	r := gin.Default()

	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"}, // or ["https://yourapp.com"]
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// User routes
	r.POST("/api/register", handlers.RegisterUser(db))
	r.POST("/api/login", handlers.LoginUser(db))
	r.GET("/api/user/settings", middleware.AuthMiddleware, handlers.GetUserSettings(db))
	r.POST("/api/user/settings", middleware.AuthMiddleware, handlers.UpdateUserSettingsHandler(db))
	r.GET("/api/user/:id", middleware.AuthMiddleware, handlers.GetUser(db))
	r.DELETE("/api/user", middleware.AuthMiddleware, handlers.DeleteUser(db))
	// Password reset and change routes
	r.POST("/api/request-password-reset", handlers.RequestPasswordReset(db))
	r.POST("/api/verify-reset-code", handlers.VerifyResetCode(db))
	r.POST("/api/change-password", middleware.AuthMiddleware, handlers.ChangePassword(db))
	// r.GET("/api/user/avatar/:userId", handlers.GetUserAvatar(db))
	// r.DELETE("/api/user/avatar", middleware.AuthMiddleware, handlers.DeleteAvatarHandler(db))

	r.POST("/api/verse", middleware.AuthMiddleware, handlers.CreateVerse(db))
	r.GET("/api/verse/:id", middleware.AuthMiddleware, handlers.GetVerse(db))
	r.POST("/api/verse/:id/toggle-like", middleware.AuthMiddleware, handlers.ToggleLike(db))
	r.POST("/api/verse/:id/comment", middleware.AuthMiddleware, handlers.AddComment(db))
	r.PUT("/api/verse/:id/comment/:commentID", middleware.AuthMiddleware, handlers.UpdateComment(db))
	r.DELETE("/api/verses/:id", middleware.AuthMiddleware, handlers.DeleteVerse(db))
	r.DELETE("/api/verse/:id/comment/:commentID", middleware.AuthMiddleware, handlers.DeleteComment(db))
	r.GET("/api/verses/public", middleware.AuthMiddleware, handlers.GetPublicVerses(db))
	r.POST("/api/verses/save", middleware.AuthMiddleware, handlers.SaveVerse(db))
	r.POST("/api/verse/:id/publish", middleware.AuthMiddleware, handlers.PublishVerse(db))
	r.POST("/api/verse/:id/unpublish", middleware.AuthMiddleware, handlers.UnpublishVerse(db))
	r.GET("/api/verses/public/search", middleware.AuthMiddleware, handlers.SearchPublicVerses(db))
	r.GET("/api/verses/saved", middleware.AuthMiddleware, handlers.GetSavedVerses(db))
	r.GET("/api/verses/saved/search", middleware.AuthMiddleware, handlers.SearchSavedVerses(db))
	r.PUT("/api/verses/:id", middleware.AuthMiddleware, handlers.UpdateVerse(db))

	r.GET("/api/verse/:id/comments", middleware.AuthMiddleware, handlers.GetComments(db))
	r.GET("/api/verse/:id/likes", middleware.AuthMiddleware, handlers.GetLikesCount(db))
	r.GET("/api/verse/:id/comments/count", middleware.AuthMiddleware, handlers.GetCommentCount(db))
	// todo: can't remember what this is supposed to be
	r.GET("/api/commentRequests", middleware.AuthMiddleware, handlers.GetCommentRequests(db))
	r.DELETE("/api/notifications/comments/:id", middleware.AuthMiddleware, handlers.DeleteCommentNotification(db))

	r.GET("/api/friends/suggested", middleware.AuthMiddleware, handlers.ListSuggestedFriends(db))
	r.POST("/api/friends/:id", middleware.AuthMiddleware, handlers.AddFriend(db))
	r.DELETE("/api/friends/:id", middleware.AuthMiddleware, handlers.RemoveFriend(db))
	r.GET("/api/friends", middleware.AuthMiddleware, handlers.ListFriends(db))
	r.GET("/api/friends/search", middleware.AuthMiddleware, handlers.SearchFriends(db))
	r.GET("/api/friends/requests", middleware.AuthMiddleware, handlers.ListFriendRequests(db))
	r.POST("/api/friends/requests/:id/respond", middleware.AuthMiddleware, handlers.RespondFriendRequest(db))

	// Church routes
	r.GET("/api/churches", middleware.AuthMiddleware, handlers.GetChurches(db))
	r.GET("/api/churches/:id", middleware.AuthMiddleware, handlers.GetChurchDetails(db))
	r.POST("/api/churches", middleware.AuthMiddleware, handlers.CreateChurch(db))
	r.PUT("/api/churches/:id", middleware.AuthMiddleware, handlers.UpdateChurch(db))
	r.DELETE("/api/churches/:id", middleware.AuthMiddleware, handlers.DeleteChurch(db))

	// Small Group routes
	r.GET("/api/churches/:id/groups", handlers.GetChurchGroups(db))
	r.GET("/api/groups/:id", middleware.AuthMiddleware, handlers.GetGroupDetails(db))
	r.POST("/api/churches/:id/groups", middleware.AuthMiddleware, handlers.CreateGroup(db))
	r.PUT("/api/groups/:id", middleware.AuthMiddleware, handlers.UpdateGroup(db))
	r.DELETE("/api/groups/:id", middleware.AuthMiddleware, handlers.DeleteGroup(db))
	// Delete individual group message
	r.DELETE("/api/groups/messages/:messageId", middleware.AuthMiddleware, handlers.DeleteGroupMessage(db))

	// Delete individual group event (only if separate from regular church events)
	r.DELETE("/api/groups/events/:eventId", middleware.AuthMiddleware, handlers.DeleteGroupEvent(db))

	// Delete individual group prayer request
	r.DELETE("/api/groups/prayers/:requestId", middleware.AuthMiddleware, handlers.DeleteGroupPrayerRequest(db))

	// Group membership routes
	r.POST("/api/groups/:id/join", middleware.AuthMiddleware, handlers.JoinGroup(db))
	r.POST("/api/groups/:id/leave", middleware.AuthMiddleware, handlers.LeaveGroup(db))

	// Church Events routes
	r.GET("/api/churches/:id/events", middleware.AuthMiddleware, handlers.GetChurchEvents(db))
	r.GET("/api/groups/:id/events", middleware.AuthMiddleware, handlers.GetGroupEvents(db))
	r.POST("/api/groups/:id/events/create", middleware.AuthMiddleware, handlers.CreateGroupEvent(db))
	r.POST("/api/churches/:id/events", middleware.AuthMiddleware, handlers.CreateEvent(db))
	r.PUT("/api/events/:id", middleware.AuthMiddleware, handlers.UpdateEvent(db))
	r.DELETE("/api/events/:id", middleware.AuthMiddleware, handlers.DeleteEvent(db))
	// Church message delete
	r.DELETE("/api/churches/messages/:messageId", middleware.AuthMiddleware, handlers.DeleteChurchMessage(db))

	// Church prayer request delete
	r.DELETE("/api/churches/prayers/:requestId", middleware.AuthMiddleware, handlers.DeleteChurchPrayerRequest(db))

	// Messages routes
	r.GET("/api/churches/:id/messages", middleware.AuthMiddleware, handlers.GetChurchMessages(db))
	r.GET("/api/groups/:id/messages", middleware.AuthMiddleware, handlers.GetGroupMessages(db))
	r.POST("/api/churches/:id/messages", middleware.AuthMiddleware, handlers.CreateMessage(db))
	r.POST("/api/groups/:id/messages", middleware.AuthMiddleware, handlers.CreateGroupMessage(db))

	// Prayer Requests routes
	r.GET("/api/churches/:id/prayers", middleware.AuthMiddleware, handlers.GetChurchPrayerRequests(db))
	r.GET("/api/groups/:id/prayers", middleware.AuthMiddleware, handlers.GetGroupPrayerRequests(db))
	r.POST("/api/churches/:id/prayers", middleware.AuthMiddleware, handlers.CreatePrayerRequest(db))
	r.POST("/api/groups/:id/prayers", middleware.AuthMiddleware, handlers.CreateGroupPrayerRequest(db))

	// Church Leader routes
	r.POST("/api/church-leaders", handlers.CreateChurchLeader(db))
	r.GET("/api/church-leaders/:id", middleware.AuthMiddleware, handlers.GetChurchLeader(db))
	r.PUT("/api/church-leaders/:id", middleware.AuthMiddleware, handlers.UpdateChurchLeader(db))

	// Add new routes for church membership
	r.POST("/api/churches/:id/join", middleware.AuthMiddleware, handlers.JoinChurch(db))
	r.POST("/api/churches/leave", middleware.AuthMiddleware, handlers.LeaveChurch(db))

	// Chat routes
	r.POST("/api/chat", middleware.AuthMiddleware, handlers.ChatResponse(chatApiKey))
	r.POST("/api/chat/stream", middleware.AuthMiddleware, handlers.StreamChatResponse(chatApiKey))

	//bible routes:
	r.GET("/api/bible/translations", handlers.GetBibleTranslations(bibleApiKey))
	r.GET("/api/bible/:bibleId/books", handlers.GetBibleBooks(bibleApiKey))
	r.GET("/api/bible/:bibleId/books/:bookId/chapters", handlers.GetBibleChapters(bibleApiKey))
	r.GET("/api/passage/:translationId", handlers.GetBiblePassage(bibleApiKey, esvApiKey))

	// Public profile route (new)
	r.GET("/api/users/:id", middleware.AuthMiddleware, handlers.GetUserByID(db))

	r.POST("/api/user/avatar", middleware.AuthMiddleware, handlers.UploadUserAvatarHandler(db))
	r.POST("/api/churches/:id/avatar", middleware.AuthMiddleware, handlers.UploadChurchAvatarHandler(db))
	r.POST("/api/groups/:id/avatar", middleware.AuthMiddleware, handlers.UploadSmallGroupAvatarHandler(db))
	r.GET("/api/avatar", handlers.GetAvatarHandler(db))

	r.POST("/api/bookmarks", middleware.AuthMiddleware, handlers.CreateBookmark(db))
	r.GET("/api/bookmarks", middleware.AuthMiddleware, handlers.GetBookmarks(db))
	r.DELETE("/api/bookmarks/:id", middleware.AuthMiddleware, handlers.DeleteBookmark(db))

	r.Run()
}

func unique(slice []uint) []uint {
	keys := make(map[uint]bool)
	list := []uint{}

	for _, entry := range slice {
		if _, value := keys[entry]; !value {
			keys[entry] = true
			list = append(list, entry)
		}
	}
	return list
}
