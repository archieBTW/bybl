package handlers

import (
	"net/http"
	"strconv"
	"theword/Backend/lib/models"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/lib/pq"
	"gorm.io/gorm"
)

func AddFriend(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		friendIDStr := c.Param("id")
		friendID, err := strconv.Atoi(friendIDStr)
		if err != nil || userID == uint(friendID) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid friend ID"})
			return
		}

		var existingFriend models.Friend
		// Check if any friend relationship or request already exists
		if err := db.Where("(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)", userID, friendID, friendID, userID).
			First(&existingFriend).Error; err == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Friend request or relationship already exists"})
			return
		}

		// Create a new friend request
		newFriendRequest := models.Friend{
			UserID:    userID,
			FriendID:  uint(friendID),
			Status:    "requested",
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}
		if err := db.Create(&newFriendRequest).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send friend request"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Friend request sent"})
	}
}

func RemoveFriend(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		friendIDStr := c.Param("id")
		friendID, err := strconv.Atoi(friendIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid friend ID"})
			return
		}

		var friend models.Friend
		// Check for any existing friendship or friend request in both directions
		if err := db.Where("(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)", userID, friendID, friendID, userID).
			First(&friend).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Friendship not found"})
			return
		}

		// Remove the friendship or friend request
		if err := db.Delete(&friend).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove friend"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Friend removed successfully"})
	}
}

func SearchFriends(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, exists := c.Get("userID")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found"})
			return
		}
		userIDUint := userID.(uint)

		// Get the search query parameter
		searchQuery := c.DefaultQuery("q", "")

		var excludedUserIDs []uint

		// Retrieve all related user IDs to exclude (accepted, requested, or rejected)
		db.Raw(`
        SELECT DISTINCT user_id 
        FROM (
            SELECT friend_id AS user_id 
            FROM friends 
            WHERE user_id = ? AND status IN ('accepted', 'requested', 'rejected')
            UNION
            SELECT user_id 
            FROM friends 
            WHERE friend_id = ? AND status IN ('accepted', 'requested', 'rejected')
        ) AS related_users
    `, userIDUint, userIDUint).Scan(&excludedUserIDs)

		// Add the current user ID to the exclusion list
		excludedUserIDs = append(excludedUserIDs, userIDUint)

		var friends []struct {
			UserID          uint   `json:"user_id"`
			Username        string `json:"username"`
			PublicProfile   bool   `json:"public_profile"`
			PrimaryColor    int    `json:"primary_color"`
			HighlightColor  int    `json:"highlight_color"`
			DarkMode        bool   `json:"dark_mode"`
			TranslationId   string `json:"translation_id"`
			TranslationName string `json:"translation_name"`
		}

		// Modify the query to include search conditions and exclude specific users
		db.Raw(`
        SELECT 
            u.user_id, 
            u.username, 
            u.public_profile, 
            u.primary_color, 
            u.highlight_color, 
            u.dark_mode, 
            u.translation_id, 
            u.translation_name
        FROM users u
        WHERE (
            u.username ILIKE ? OR 
            CAST(u.user_id AS TEXT) ILIKE ?
        ) AND u.user_id NOT IN (
            SELECT unnest(?::int[])
        )
    `, "%"+searchQuery+"%", "%"+searchQuery+"%", pq.Array(excludedUserIDs)).Scan(&friends)

		c.JSON(http.StatusOK, friends)
	}
}

func RespondFriendRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		friendIDStr := c.Param("id")
		friendID, err := strconv.Atoi(friendIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid friend ID"})
			return
		}

		var req struct {
			Accept bool `json:"accept"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var friend models.Friend
		if err := db.Where("user_id = ? AND friend_id = ? AND status = ?", friendID, userID, "requested").First(&friend).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Friend request not found"})
			return
		}

		if req.Accept {
			friend.Status = "accepted"
			db.Save(&friend)
			c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted"})
		} else {
			friend.Status = "rejected"
			db.Save(&friend)
			c.JSON(http.StatusOK, gin.H{"message": "Friend request declined"})
		}
	}
}

func ListFriends(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		var friends []struct {
			UserID          uint   `json:"user_id"`
			Username        string `json:"username"`
			AvatarURL       string `json:"avatar_url"`
			PublicProfile   bool   `json:"public_profile"`
			PrimaryColor    int    `json:"primary_color"`
			HighlightColor  int    `json:"highlight_color"`
			DarkMode        bool   `json:"dark_mode"`
			TranslationId   string `json:"translation_id"`
			TranslationName string `json:"translation_name"`
			MutualFriends   int    `json:"mutual_friends"`
			TotalLikeCount  int    `json:"total_like_count"`
		}

		db.Raw(`
        SELECT 
            u.user_id, 
            u.username, 
            u.avatar_url,
            u.public_profile, 
            u.primary_color, 
            u.highlight_color, 
            u.dark_mode, 
            u.translation_id, 
            u.translation_name,
            (
                SELECT COUNT(DISTINCT mutual_friend_id)
                FROM (
                    SELECT f1.friend_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted' 
                    AND f1.user_id = u.user_id 
                    AND f1.friend_id IN (
                        SELECT f2.friend_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.user_id = ?
                    )
                    
                    UNION
                    
                    SELECT f1.user_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted' 
                    AND f1.friend_id = u.user_id 
                    AND f1.user_id IN (
                        SELECT f2.friend_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.user_id = ?
                    )
                    
                    UNION
                    
                    SELECT f1.friend_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted'
                    AND f1.user_id = u.user_id 
                    AND f1.friend_id IN (
                        SELECT f2.user_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.friend_id = ?
                    )
                    
                    UNION
                    
                    SELECT f1.user_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted'
                    AND f1.friend_id = u.user_id 
                    AND f1.user_id IN (
                        SELECT f2.user_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.friend_id = ?
                    )
                ) AS mutual_friends
            ) AS mutual_friends,
            (
                SELECT COUNT(*)
                FROM likes
                WHERE likes.user_id = u.user_id
            ) AS total_like_count
        FROM users u
        INNER JOIN friends f ON (
            (f.friend_id = u.user_id AND f.user_id = ? AND f.status = 'accepted')
            OR
            (f.user_id = u.user_id AND f.friend_id = ? AND f.status = 'accepted')
        )
    `, userID, userID, userID, userID, userID, userID).Scan(&friends)

		c.JSON(http.StatusOK, friends)
	}
}

func ListSuggestedFriends(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, exists := c.Get("userID")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found"})
			return
		}
		userIDUint := userID.(uint)

		var excludedUserIDs []uint

		db.Raw(`
        SELECT DISTINCT user_id 
        FROM (
            SELECT friend_id AS user_id 
            FROM friends 
            WHERE user_id = $1 AND status IN ('accepted', 'requested', 'rejected')
            UNION
            SELECT user_id 
            FROM friends 
            WHERE friend_id = $1 AND status IN ('accepted', 'requested', 'rejected')
        ) AS related_users
    `, userIDUint).Scan(&excludedUserIDs)

		excludedUserIDs = append(excludedUserIDs, userIDUint)

		var suggestedFriends []struct {
			UserID          uint   `json:"user_id"`
			Username        string `json:"username"`
			AvatarURL       string `json:"avatar_url"`
			MutualFriends   int    `json:"mutual_friends"`
			TotalLikeCount  int    `json:"total_like_count"`
			PublicProfile   bool   `json:"public_profile"`
			PrimaryColor    int    `json:"primary_color"`
			HighlightColor  int    `json:"highlight_color"`
			DarkMode        bool   `json:"dark_mode"`
			TranslationId   string `json:"translation_id"`
			TranslationName string `json:"translation_name"`
		}

		db.Raw(`
        SELECT 
            u.user_id, 
            u.username,
            u.avatar_url,
            u.public_profile, 
            u.primary_color, 
            u.highlight_color, 
            u.dark_mode, 
            u.translation_id, 
            u.translation_name,
            (
                SELECT COUNT(DISTINCT mutual_friend_id)
                FROM (
                    SELECT f1.friend_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted' 
                    AND f1.user_id = u.user_id 
                    AND f1.friend_id IN (
                        SELECT f2.friend_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.user_id = $1
                    )
                    
                    UNION
                    
                    SELECT f1.user_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted' 
                    AND f1.friend_id = u.user_id 
                    AND f1.user_id IN (
                        SELECT f2.friend_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.user_id = $1
                    )
                    
                    UNION
                    
                    SELECT f1.friend_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted'
                    AND f1.user_id = u.user_id 
                    AND f1.friend_id IN (
                        SELECT f2.user_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.friend_id = $1
                    )
                    
                    UNION
                    
                    SELECT f1.user_id AS mutual_friend_id
                    FROM friends f1
                    WHERE f1.status = 'accepted'
                    AND f1.friend_id = u.user_id 
                    AND f1.user_id IN (
                        SELECT f2.user_id 
                        FROM friends f2
                        WHERE f2.status = 'accepted'
                        AND f2.friend_id = $1
                    )
                ) AS mutual_friends
            ) AS mutual_friends,
            (
                SELECT COUNT(*)
                FROM likes
                WHERE likes.user_id = u.user_id
            ) AS total_like_count
        FROM users u
        WHERE u.public_profile = true 
            AND u.user_id NOT IN (
                SELECT unnest($2::int[])
            )
    `, userIDUint, pq.Array(excludedUserIDs)).Scan(&suggestedFriends)

		c.JSON(http.StatusOK, suggestedFriends)
	}
}

func ListFriendRequests(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		var friendRequests []struct {
			UserID    uint   `json:"user_id"`
			Username  string `json:"username"`
			AvatarURL string `json:"avatar_url"`
		}

		err := db.Raw(`
		SELECT 
			u.user_id, 
			u.username,
			u.avatar_url
		FROM users u
		JOIN friends f ON (
			(f.friend_id = u.user_id AND f.user_id = ?) OR 
			(f.user_id = u.user_id AND f.friend_id = ?)
		)
		WHERE 
			(f.friend_id = ? AND f.status = 'requested')
	`, userID, userID, userID).Scan(&friendRequests).Error

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve friend requests"})
			return
		}

		c.JSON(http.StatusOK, friendRequests)
	}
}
