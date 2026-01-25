package handlers

import (
	"log"
	"net/http"
	"strconv"
	"theword/Backend/lib/models"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func GetChurches(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var churches []models.Church
		if err := db.Find(&churches).Error; err != nil {
			log.Printf("Error fetching churches: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch churches"})
			return
		}

		log.Printf("Found %d churches in database", len(churches))
		for i, church := range churches {
			log.Printf("Church %d: ID=%d, Name=%s", i+1, church.ChurchID, church.Name)
		}

		c.JSON(http.StatusOK, churches)
	}
}

func GetChurchDetails(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		churchID := c.Param("id")
		var church models.Church
		if err := db.First(&church, "church_id = ?", churchID).Error; err != nil {
			church = models.Church{}
		}

		var groups []models.SmallGroup
		var events []models.ChurchEvent
		var messages []models.Message
		var prayerRequests []models.PrayerRequest

		if err := db.Where("church_id = ?", churchID).Find(&groups).Error; err != nil {
			log.Printf("Error fetching groups for church %s: %v", churchID, err)
			groups = []models.SmallGroup{}
		} else {
			log.Printf("Found %d groups for church %s", len(groups), churchID)
		}

		if err := db.Where("church_id = ?", churchID).Find(&events).Error; err != nil {
			events = []models.ChurchEvent{}
		}

		if err := db.Where("church_id = ?", churchID).Find(&messages).Error; err != nil {
			messages = []models.Message{}
		}

		if err := db.Where("church_id = ?", churchID).Find(&prayerRequests).Error; err != nil {
			prayerRequests = []models.PrayerRequest{}
		}

		response := gin.H{
			"church":         church,
			"groups":         groups,
			"events":         events,
			"messages":       messages,
			"prayerRequests": prayerRequests,
		}

		c.JSON(http.StatusOK, response)
	}
}

func CreateChurch(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		// Check if user is a church leader
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can create churches"})
			return
		}

		var church models.Church
		if err := c.ShouldBindJSON(&church); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		church.CreatedAt = time.Now()
		church.UpdatedAt = time.Now()

		if err := db.Create(&church).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create church"})
			return
		}

		// Update the user's ChurchID
		if err := db.Model(&user).Update("church_id", church.ChurchID).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user's church"})
			return
		}

		c.JSON(http.StatusCreated, church)
	}
}

func UpdateChurch(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchID := c.Param("id")

		// Check if user is a church leader
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can update churches"})
			return
		}

		var church models.Church
		if err := db.First(&church, "church_id = ?", churchID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Church not found"})
			return
		}

		if err := c.ShouldBindJSON(&church); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		church.UpdatedAt = time.Now()

		if err := db.Save(&church).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update church"})
			return
		}

		c.JSON(http.StatusOK, church)
	}
}

func DeleteChurch(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchID := c.Param("id")

		// Check if user is a church leader
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can delete churches"})
			return
		}

		if err := db.Delete(&models.Church{}, "church_id = ?", churchID).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete church"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Church deleted successfully"})
	}
}

func GetChurchEvents(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		churchID := c.Param("id")
		var events []models.ChurchEvent
		if err := db.Where("church_id = ?", churchID).Find(&events).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch events"})
			return
		}
		c.JSON(http.StatusOK, events)
	}
}

func CreateEvent(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchIDStr := c.Param("id")
		churchID, err := strconv.ParseUint(churchIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid church ID"})
			return
		}

		var event models.ChurchEvent
		if err := c.ShouldBindJSON(&event); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		event.ChurchID = uint(churchID)
		event.CreatedBy = userID
		event.CreatedAt = time.Now()
		event.UpdatedAt = time.Now()

		if err := db.Create(&event).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create event"})
			return
		}

		c.JSON(http.StatusCreated, event)
	}
}

func UpdateEvent(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		eventID := c.Param("id")

		var event models.ChurchEvent
		if err := db.First(&event, "event_id = ?", eventID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		// Check if user is the creator or an admin
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if event.CreatedBy != userID && !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to update this event"})
			return
		}

		if err := c.ShouldBindJSON(&event); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		event.UpdatedAt = time.Now()

		if err := db.Save(&event).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update event"})
			return
		}

		c.JSON(http.StatusOK, event)
	}
}

func DeleteMessage(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		messageID := c.Param("id")

		var message models.Message
		if err := db.First(&message, "message_id = ?", messageID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Message not found"})
			return
		}

		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if message.CreatedBy != userID && !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to delete this message"})
			return
		}

		if err := db.Delete(&message).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete message"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Message deleted successfully"})
	}
}

func DeleteSmallGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupID := c.Param("id")

		var group models.SmallGroup
		if err := db.First(&group, "group_id = ?", groupID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Small group not found"})
			return
		}

		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can delete small groups"})
			return
		}

		if err := db.Delete(&group).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete small group"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Small group deleted successfully"})
	}
}

func DeleteEvent(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		eventID := c.Param("id")

		var event models.ChurchEvent
		if err := db.First(&event, "event_id = ?", eventID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		// Check if user is the creator or an admin
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if event.CreatedBy != userID && !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to delete this event"})
			return
		}

		if err := db.Delete(&event).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete event"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Event deleted successfully"})
	}
}

func GetChurchMessages(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		churchID := c.Param("id")
		var messages []models.Message
		if err := db.Where("church_id = ?", churchID).Find(&messages).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch messages"})
			return
		}
		c.JSON(http.StatusOK, messages)
	}
}

func CreateMessage(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchIDStr := c.Param("id")
		churchID, err := strconv.ParseUint(churchIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid church ID"})
			return
		}

		var message models.Message
		if err := c.ShouldBindJSON(&message); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		message.ChurchID = uint(churchID)
		message.CreatedBy = userID
		message.CreatedAt = time.Now()
		message.UpdatedAt = time.Now()

		// Get username
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}
		message.Username = user.Username

		if err := db.Create(&message).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create message"})
			return
		}

		c.JSON(http.StatusCreated, message)
	}
}

func GetChurchPrayerRequests(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		churchID := c.Param("id")
		var prayerRequests []models.PrayerRequest
		if err := db.Where("church_id = ?", churchID).Find(&prayerRequests).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch prayer requests"})
			return
		}
		c.JSON(http.StatusOK, prayerRequests)
	}
}

func CreatePrayerRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchIDStr := c.Param("id")
		churchID, err := strconv.ParseUint(churchIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid church ID"})
			return
		}

		var prayerRequest models.PrayerRequest
		if err := c.ShouldBindJSON(&prayerRequest); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		prayerRequest.ChurchID = uint(churchID)
		prayerRequest.CreatedBy = userID
		prayerRequest.CreatedAt = time.Now()
		prayerRequest.UpdatedAt = time.Now()

		// Get username if not anonymous
		if !prayerRequest.IsAnonymous {
			var user models.User
			if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
				return
			}
			prayerRequest.Username = user.Username
		} else {
			prayerRequest.Username = "Anonymous"
		}

		if err := db.Create(&prayerRequest).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create prayer request"})
			return
		}

		c.JSON(http.StatusCreated, prayerRequest)
	}
}

func CreateChurchLeader(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Email    string `json:"email"`
			Username string `json:"username"`
			Password string `json:"password"`
			ChurchID uint   `json:"church_id,omitempty"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Check if user already exists
		var existingUser models.User
		if err := db.First(&existingUser, "email = ?", req.Email).Error; err == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email already registered"})
			return
		}

		passwordHash, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		user := models.User{
			Email:           req.Email,
			Username:        req.Username,
			PasswordHash:    string(passwordHash),
			PublicProfile:   false,
			PrimaryColor:    4284955319,
			HighlightColor:  4294961979,
			DarkMode:        true,
			TranslationId:   "ESV",
			TranslationName: "English Standard Version",
			IsAdmin:         true,
			ChurchID:        req.ChurchID,
		}

		if err := db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Church leader created successfully"})
	}
}

func GetChurchLeader(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		leaderID := c.Param("id")
		var user models.User
		if err := db.First(&user, "user_id = ? AND is_admin = ?", leaderID, true).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Church leader not found"})
			return
		}
		c.JSON(http.StatusOK, user)
	}
}

func UpdateChurchLeader(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		leaderID := c.Param("id")

		// Check if the requesting user is an admin
		var requestingUser models.User
		if err := db.First(&requestingUser, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !requestingUser.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only admins can update church leaders"})
			return
		}

		var user models.User
		if err := db.First(&user, "user_id = ? AND is_admin = ?", leaderID, true).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Church leader not found"})
			return
		}

		if err := c.ShouldBindJSON(&user); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Ensure the user remains an admin
		user.IsAdmin = true

		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update church leader"})
			return
		}

		c.JSON(http.StatusOK, user)
	}
}
func JoinChurch(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchID := c.Param("id")

		var church models.Church
		if err := db.First(&church, "church_id = ?", churchID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Church not found"})
			return
		}

		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if user.ChurchID != 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User is already a member of a church"})
			return
		}

		user.ChurchID = church.ChurchID
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to join church"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Successfully joined church"})
	}
}

func LeaveChurch(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if user.ChurchID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User is not a member of any church"})
			return
		}

		if user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Church leaders cannot leave their church"})
			return
		}

		user.ChurchID = 0
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to leave church"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Successfully left church"})
	}
}

func DeleteChurchMessage(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		messageID := c.Param("messageId")

		var message models.Message
		if err := db.First(&message, "message_id = ?", messageID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Message not found"})
			return
		}

		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if message.CreatedBy != userID && !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to delete this message"})
			return
		}

		if err := db.Delete(&message).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete message"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Message deleted successfully"})
	}
}

func DeleteChurchPrayerRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		requestID := c.Param("requestId")

		var request models.PrayerRequest
		if err := db.First(&request, "prayer_request_id = ?", requestID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Prayer request not found"})
			return
		}

		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if request.CreatedBy != userID && !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to delete this request"})
			return
		}

		if err := db.Delete(&request).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete prayer request"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Prayer request deleted successfully"})
	}
}
