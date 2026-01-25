package handlers

import (
	"net/http"
	"strconv"
	"theword/Backend/lib/models"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func GetChurchGroups(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		churchID := c.Param("id")
		var groups []models.SmallGroup
		if err := db.Where("church_id = ?", churchID).Find(&groups).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch groups"})
			return
		}
		c.JSON(http.StatusOK, groups)
	}
}

func GetGroupDetails(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")
		userID := c.MustGet("userID").(uint)

		var group models.SmallGroup
		if err := db.First(&group, "group_id = ?", groupID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
			return
		}

		// Get associated data
		var events []models.ChurchEvent
		var messages []models.Message
		var prayerRequests []models.PrayerRequest

		db.Where("group_id = ?", groupID).Find(&events)
		db.Where("group_id = ?", groupID).Find(&messages)
		db.Where("group_id = ?", groupID).Find(&prayerRequests)

		// Check if the user is a member
		var isMember bool
		var member models.GroupMember
		if err := db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err == nil {
			isMember = true
		}

		// Check if the user is the leader
		isLeader := group.LeaderID == userID

		response := gin.H{
			"group":          group,
			"events":         events,
			"messages":       messages,
			"prayerRequests": prayerRequests,
			"isMember":       isMember,
			"isLeader":       isLeader,
		}

		c.JSON(http.StatusOK, response)
	}
}

func CreateGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchIDStr := c.Param("id")
		churchID, err := strconv.ParseUint(churchIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid church ID"})
			return
		}

		// Check if user is a church leader
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can create groups"})
			return
		}

		var group models.SmallGroup
		if err := c.ShouldBindJSON(&group); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		group.ChurchID = uint(churchID)
		group.CreatedAt = time.Now()
		group.UpdatedAt = time.Now()

		if err := db.Create(&group).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create group"})
			return
		}

		c.JSON(http.StatusCreated, group)
	}
}

func UpdateGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupID := c.Param("id")

		// Check if user is a church leader
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can update groups"})
			return
		}

		var group models.SmallGroup
		if err := db.First(&group, "group_id = ?", groupID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
			return
		}

		if err := c.ShouldBindJSON(&group); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		group.UpdatedAt = time.Now()

		if err := db.Save(&group).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update group"})
			return
		}

		c.JSON(http.StatusOK, group)
	}
}

func DeleteGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupID := c.Param("id")

		// Check if user is a church leader
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can delete groups"})
			return
		}

		if err := db.Delete(&models.SmallGroup{}, "group_id = ?", groupID).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete group"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Group deleted successfully"})
	}
}

func GetGroupEvents(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")
		var events []models.ChurchEvent
		if err := db.Where("group_id = ?", groupID).Find(&events).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch events"})
			return
		}
		c.JSON(http.StatusOK, events)
	}
}

func CreateGroupPrayerRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupIDStr := c.Param("id")
		groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
			return
		}

		var prayerRequest models.PrayerRequest
		if err := c.ShouldBindJSON(&prayerRequest); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		prayerRequest.GroupID = uint(groupID)
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

func GetGroupPrayerRequests(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")
		var prayerRequests []models.PrayerRequest
		if err := db.Where("group_id = ?", groupID).Find(&prayerRequests).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch prayer requests"})
			return
		}
		c.JSON(http.StatusOK, prayerRequests)
	}
}

func GetGroupMessages(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")
		var messages []models.Message
		if err := db.Where("group_id = ?", groupID).Find(&messages).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch messages"})
			return
		}
		c.JSON(http.StatusOK, messages)
	}
}

func CreateGroupMessage(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupIDStr := c.Param("id")
		groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
			return
		}

		var message models.Message
		if err := c.ShouldBindJSON(&message); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		message.GroupID = uint(groupID)
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

func JoinGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupIDStr := c.Param("id")
		groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
			return
		}

		// Check if already a member
		var existing models.GroupMember
		err = db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&existing).Error
		if err == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Already a member"})
			return
		}

		member := models.GroupMember{
			GroupID:  uint(groupID),
			UserID:   userID,
			Role:     "member",
			JoinedAt: time.Now(),
		}

		if err := db.Create(&member).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to join group"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Successfully joined group"})
	}
}

func LeaveGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupIDStr := c.Param("id")
		groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
			return
		}

		if err := db.Where("group_id = ? AND user_id = ?", groupID, userID).Delete(&models.GroupMember{}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to leave group"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Successfully left group"})
	}
}

// in small_group_handler.go
func CreateGroupEvent(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		groupIDStr := c.Param("id")
		groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
			return
		}

		// Allow church-admins or the group leader only
		var group models.SmallGroup
		if err := db.First(&group, "group_id = ?", groupID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
			return
		}
		var user models.User
		db.First(&user, "user_id = ?", userID)
		if !(user.IsAdmin || group.LeaderID == userID) {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		var ev models.ChurchEvent
		if err := c.ShouldBindJSON(&ev); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		ev.GroupID = uint(groupID)
		ev.ChurchID = group.ChurchID // keep linkage
		ev.CreatedAt = time.Now()
		ev.UpdatedAt = time.Now()

		if err := db.Create(&ev).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusCreated, ev)
	}
}

func DeleteGroupMessage(db *gorm.DB) gin.HandlerFunc {
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

func DeleteGroupEvent(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		eventID := c.Param("eventId")

		var event models.ChurchEvent
		if err := db.First(&event, "event_id = ?", eventID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

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

func DeleteGroupPrayerRequest(db *gorm.DB) gin.HandlerFunc {
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
