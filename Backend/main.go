package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"theword/Backend/lib/database"
	"theword/Backend/lib/handlers"
	"theword/Backend/lib/middleware"
	"theword/Backend/lib/models"

	"github.com/archieBTW/gofyr/pkg/gofyr"
)

var db *gorm.DB

func main() {
	dbDriver := os.Getenv("DB_DRIVER")
	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	if dbPort == "" {
		dbPort = "5432"
	}
	bibleApiKey := os.Getenv("BIBLE_KEY")
	esvApiKey := os.Getenv("ESV_KEY")

	var err error
	if dbDriver == "sqlite" || (dbHost == "" && dbDriver != "postgres") {
		dbPath := os.Getenv("SQLITE_PATH")
		if dbPath == "" {
			dbPath = "theword.db"
		}
		log.Printf("Connecting to SQLite database: %s", dbPath)
		db, err = gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
	} else {
		dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=disable",
			dbHost, dbUser, dbPassword, dbName, dbPort)
		log.Printf("Connecting to PostgreSQL database at %s:%s (db: %s)", dbHost, dbPort, dbName)
		db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	}
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	// AutoMigrate all application domain models
	err = db.AutoMigrate(
		&models.Bookmark{}, &models.User{}, &models.UserVerse{}, &models.Like{}, &models.Comment{},
		&models.Friend{}, &models.Notification{}, &models.Church{}, &models.SmallGroup{},
		&models.ChurchEvent{}, &models.Message{}, &models.PrayerRequest{}, &models.GroupMember{},
		&models.MapPOI{}, &models.BibleMapPath{},
	)
	if err != nil {
		log.Printf("warning during AutoMigrate: %v", err)
	}
	log.Println("Database tables verified/migrated.")

	// Seed application database with initial data if empty
	database.SeedDatabase(db)

	// Configure gofyrAdmin
	adminCfg := gofyr.DefaultConfig()
	adminBasePath := os.Getenv("ADMIN_BASE_PATH")
	if adminBasePath == "" {
		adminBasePath = "/admin"
	}
	adminCfg.BasePath = adminBasePath

	adminTitle := os.Getenv("ADMIN_TITLE")
	if adminTitle == "" {
		adminTitle = "bybl Admin"
	}
	adminCfg.Title = adminTitle

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret != "" {
		adminCfg.JWTSecret = jwtSecret
	}

	adminDisk := os.Getenv("ADMIN_DEFAULT_DISK")
	if adminDisk != "" {
		adminCfg.DefaultDisk = adminDisk
	}

	adminCfg.LocalStorage.BaseDir = "./uploads"
	adminCfg.LocalStorage.PublicURLPrefix = adminCfg.BasePath + "/uploads"

	// Support Wasabi / S3-compatible storage if configured
	if os.Getenv("WASABI_BUCKET") != "" {
		adminCfg.S3Storage.Bucket = os.Getenv("WASABI_BUCKET")
		adminCfg.S3Storage.Region = os.Getenv("WASABI_REGION")
		adminCfg.S3Storage.Endpoint = os.Getenv("WASABI_ENDPOINT")
		adminCfg.S3Storage.AccessKey = os.Getenv("WASABI_ACCESS_KEY")
		adminCfg.S3Storage.SecretKey = os.Getenv("WASABI_SECRET_KEY")
		adminCfg.S3Storage.UsePathStyle = true
		if os.Getenv("ADMIN_DEFAULT_DISK") == "s3" {
			adminCfg.DefaultDisk = "s3"
		}
	}

	admin, err := gofyr.New(adminCfg)
	if err != nil {
		log.Fatalf("failed to initialize gofyrAdmin: %v", err)
	}

	// Register Primary Datasource (auto-migrates internal gofyr tables: gofyr_admin_users, gofyr_audit_logs, etc.)
	if err := admin.AddDatasource("primary", db, true); err != nil {
		log.Fatalf("failed to register primary datasource in gofyrAdmin: %v", err)
	}

	// Register all application domain models in gofyrAdmin
	_ = admin.RegisterModel("primary", &models.User{})
	_ = admin.RegisterModel("primary", &models.Church{})
	_ = admin.RegisterModel("primary", &models.SmallGroup{})
	_ = admin.RegisterModel("primary", &models.GroupMember{})
	_ = admin.RegisterModel("primary", &models.ChurchEvent{})
	_ = admin.RegisterModel("primary", &models.Message{})
	_ = admin.RegisterModel("primary", &models.PrayerRequest{})
	_ = admin.RegisterModel("primary", &models.UserVerse{})
	_ = admin.RegisterModel("primary", &models.Bookmark{})
	_ = admin.RegisterModel("primary", &models.Comment{})
	_ = admin.RegisterModel("primary", &models.Like{})
	_ = admin.RegisterModel("primary", &models.Friend{})
	_ = admin.RegisterModel("primary", &models.Notification{})
	_ = admin.RegisterModel("primary", &models.MapPOI{})
	_ = admin.RegisterModel("primary", &models.BibleMapPath{})

	// Seed default superuser requiring password reset & MFA enrollment (NO recovery codes)
	seedGofyrAdmin(db)

	// Ensure uploads directory exists
	_ = os.MkdirAll("./uploads", 0755)

	corsConfig := cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}

	// -------------------------------------------------------------
	// Host API Engine (Serving public REST endpoints)
	// -------------------------------------------------------------
	apiRouter := gin.Default()
	apiRouter.Use(cors.New(corsConfig))
	apiRouter.Static("/uploads", "./uploads")

	// Map data route for mobile and web clients
	apiRouter.GET("/api/map/data", handlers.GetMapData(db))

	// Application Routes
	apiRouter.GET("/api/user/settings", middleware.AuthMiddleware, handlers.GetUserSettings(db))
	apiRouter.GET("/api/user/:id", middleware.AuthMiddleware, handlers.GetUser(db))

	// Verses
	apiRouter.GET("/api/verse/:id", middleware.AuthMiddleware, handlers.GetVerse(db))
	apiRouter.GET("/api/verses/public", middleware.AuthMiddleware, handlers.GetPublicVerses(db))
	apiRouter.GET("/api/verses/public/search", middleware.AuthMiddleware, handlers.SearchPublicVerses(db))
	apiRouter.GET("/api/verses/saved", middleware.AuthMiddleware, handlers.GetSavedVerses(db))
	apiRouter.GET("/api/verses/saved/search", middleware.AuthMiddleware, handlers.SearchSavedVerses(db))

	apiRouter.GET("/api/verse/:id/comments", middleware.AuthMiddleware, handlers.GetComments(db))
	apiRouter.GET("/api/verse/:id/likes", middleware.AuthMiddleware, handlers.GetLikesCount(db))
	apiRouter.GET("/api/verse/:id/comments/count", middleware.AuthMiddleware, handlers.GetCommentCount(db))
	apiRouter.GET("/api/commentRequests", middleware.AuthMiddleware, handlers.GetCommentRequests(db))

	apiRouter.GET("/api/friends/suggested", middleware.AuthMiddleware, handlers.ListSuggestedFriends(db))
	apiRouter.GET("/api/friends", middleware.AuthMiddleware, handlers.ListFriends(db))
	apiRouter.GET("/api/friends/search", middleware.AuthMiddleware, handlers.SearchFriends(db))
	apiRouter.GET("/api/friends/requests", middleware.AuthMiddleware, handlers.ListFriendRequests(db))

	// Churches
	apiRouter.GET("/api/churches", middleware.AuthMiddleware, handlers.GetChurches(db))
	apiRouter.GET("/api/churches/:id", middleware.AuthMiddleware, handlers.GetChurchDetails(db))

	// Groups
	apiRouter.GET("/api/churches/:id/groups", handlers.GetChurchGroups(db))
	apiRouter.GET("/api/groups/:id", middleware.AuthMiddleware, handlers.GetGroupDetails(db))

	// Events
	apiRouter.GET("/api/churches/:id/events", middleware.AuthMiddleware, handlers.GetChurchEvents(db))
	apiRouter.GET("/api/groups/:id/events", middleware.AuthMiddleware, handlers.GetGroupEvents(db))

	// Messages
	apiRouter.GET("/api/churches/:id/messages", middleware.AuthMiddleware, handlers.GetChurchMessages(db))
	apiRouter.GET("/api/groups/:id/messages", middleware.AuthMiddleware, handlers.GetGroupMessages(db))

	// Prayers
	apiRouter.GET("/api/churches/:id/prayers", middleware.AuthMiddleware, handlers.GetChurchPrayerRequests(db))
	apiRouter.GET("/api/groups/:id/prayers", middleware.AuthMiddleware, handlers.GetGroupPrayerRequests(db))

	// Leaders
	apiRouter.GET("/api/church-leaders/:id", middleware.AuthMiddleware, handlers.GetChurchLeader(db))

	// Bible
	apiRouter.GET("/api/bible/translations", handlers.GetBibleTranslations(bibleApiKey))
	apiRouter.GET("/api/bible/:bibleId/books", handlers.GetBibleBooks(bibleApiKey))
	apiRouter.GET("/api/bible/:bibleId/books/:bookId/chapters", handlers.GetBibleChapters(bibleApiKey))
	apiRouter.GET("/api/passage/:translationId", handlers.GetBiblePassage(bibleApiKey, esvApiKey))

	apiRouter.GET("/api/users/:id", middleware.AuthMiddleware, handlers.GetUserByID(db))
	apiRouter.GET("/api/avatar", handlers.GetAvatarHandler(db))
	apiRouter.GET("/api/bookmarks", middleware.AuthMiddleware, handlers.GetBookmarks(db))

	// Health check
	apiRouter.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "bybl-api"})
	})

	// Legacy map management endpoints (registered in host router for API Workbench and scripts)
	adminMap := apiRouter.Group("/api/map")
	{
		adminMap.POST("/poi", handlers.CreatePOI(db))
		adminMap.PUT("/poi/:id", handlers.UpdatePOI(db))
		adminMap.DELETE("/poi/:id", handlers.DeletePOI(db))
		adminMap.POST("/path", handlers.CreatePath(db))
		adminMap.PUT("/path/:id", handlers.UpdatePath(db))
		adminMap.DELETE("/path/:id", handlers.DeletePath(db))
		adminMap.POST("/upload-image", handlers.UploadPOIImage)
	}

	// -------------------------------------------------------------
	// Port & Subdomain Architecture Configuration
	// -------------------------------------------------------------
	apiPort := os.Getenv("PORT")
	if apiPort == "" {
		apiPort = "8080"
	}
	adminPort := os.Getenv("ADMIN_PORT")
	if adminPort == "" {
		adminPort = "8081"
	}

	// Link API router to Workbench so admin can introspect & test all API endpoints
	admin.SetTargetEngine(apiRouter)

	if adminPort != "" && adminPort != apiPort {
		// DUAL-PORT MODE: Dedicated admin server for separate subdomain proxying
		adminRouter := gin.Default()
		adminRouter.Use(cors.New(corsConfig))

		// Root redirect to admin panel
		adminRouter.GET("/", func(c *gin.Context) {
			c.Redirect(http.StatusFound, adminCfg.BasePath)
		})
		adminRouter.GET("/admin/map", func(c *gin.Context) {
			c.Redirect(http.StatusMovedPermanently, adminCfg.BasePath)
		})
		adminRouter.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "bybl-admin"})
		})

		// Mount gofyrAdmin onto dedicated admin router
		if err := admin.Mount(adminRouter); err != nil {
			log.Fatalf("failed to mount gofyrAdmin on admin port: %v", err)
		}

		// Also redirect /admin on the API port to inform client
		apiRouter.GET("/admin", func(c *gin.Context) {
			c.Redirect(http.StatusMovedPermanently, fmt.Sprintf("http://%s:%s%s", c.Request.Host, adminPort, adminCfg.BasePath))
		})

		// Start dedicated admin listener in background
		go func() {
			log.Printf("🛡️ gofyrAdmin running on separate port :%s (Subdomain reverse proxy target)", adminPort)
			if err := adminRouter.Run(":" + adminPort); err != nil {
				log.Fatalf("Admin server terminated unexpectedly: %v", err)
			}
		}()
	} else {
		// SINGLE-PORT MODE: Mount admin directly onto main API router
		apiRouter.GET("/admin/map", func(c *gin.Context) {
			c.Redirect(http.StatusMovedPermanently, adminCfg.BasePath)
		})
		if err := admin.Mount(apiRouter); err != nil {
			log.Fatalf("failed to mount gofyrAdmin: %v", err)
		}
	}

	fmt.Println("=============================================================")
	fmt.Printf("🔥 bybl API Server:  http://0.0.0.0:%s\n", apiPort)
	if adminPort != "" && adminPort != apiPort {
		fmt.Printf("🛡️ gofyrAdmin Panel: http://0.0.0.0:%s%s (Separate Port/Subdomain)\n", adminPort, adminCfg.BasePath)
	} else {
		fmt.Printf("🛡️ gofyrAdmin Panel: http://0.0.0.0:%s%s\n", apiPort, adminCfg.BasePath)
	}
	fmt.Printf("   Default Login:    %s / %s\n", getAdminEmail(), getAdminPassword())
	fmt.Printf("   Security Policy:  Forced Password Reset & MFA Setup on first login\n")
	fmt.Printf("   Recovery Codes:   None pre-seeded (generated & saved during MFA setup)\n")
	fmt.Println("=============================================================")

	if err := apiRouter.Run(":" + apiPort); err != nil {
		log.Fatalf("API Server stopped: %v", err)
	}
}

func getAdminEmail() string {
	email := os.Getenv("ADMIN_EMAIL")
	if email == "" {
		return "admin@bybl.local"
	}
	return email
}

func getAdminPassword() string {
	pwd := os.Getenv("ADMIN_PASSWORD")
	if pwd == "" {
		return "admin123"
	}
	return pwd
}

func seedGofyrAdmin(db *gorm.DB) {
	adminEmail := getAdminEmail()
	adminPassword := getAdminPassword()

	var existingUser gofyr.GofyrAdminUser
	if err := db.Where("email = ?", adminEmail).First(&existingUser).Error; err != nil {
		pwdHash, err := gofyr.HashPassword(adminPassword)
		if err != nil {
			log.Printf("gofyr: failed to hash password: %v", err)
			return
		}
		// Default superuser requires resetting password and configuring MFA on first login
		newUser := gofyr.GofyrAdminUser{
			Email:             adminEmail,
			PasswordHash:      pwdHash,
			Name:              "Bybl Administrator",
			Role:              "superadmin",
			MFASecret:         "",
			MFAEnabled:        false,
			MustResetPassword: true,
		}
		if err := db.Create(&newUser).Error; err != nil {
			log.Printf("gofyr: failed to seed admin user: %v", err)
			return
		}
		existingUser = newUser
		log.Printf("✓ gofyr: created default superuser: %s (MustResetPassword=true, MFAEnabled=false)", adminEmail)
	}

	// Explicitly remove any pre-seeded recovery codes so user starts with NO recovery codes
	db.Where("user_id = ?", existingUser.ID).Delete(&gofyr.GofyrMFARecoveryCode{})
}
