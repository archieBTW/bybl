package handlers

import (
	"net/http"
	"strconv"
	"theword/Backend/lib/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func DeleteCommentNotification(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		notificationID := c.Param("id")

		if err := db.Where("user_id = ? AND notification_id = ?", userID, notificationID).Delete(&models.Notification{}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete comment notification"})
		}

		c.JSON(http.StatusOK, gin.H{"message": "Notification deleted successfully"})
	}
}

func GetCommentCount(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userVerseIDStr := c.Param("id")
		userVerseID, err := strconv.Atoi(userVerseIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid UserVerseID"})
			return
		}

		var commentCount int64
		if err := db.Model(&models.Comment{}).Where("user_verse_id = ?", userVerseID).Count(&commentCount).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve comment count"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"comment_count": commentCount})
	}
}

func GetLikesCount(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userVerseIDStr := c.Param("id")
		userVerseID, err := strconv.Atoi(userVerseIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid UserVerseID"})
			return
		}

		var likesCount int64
		if err := db.Model(&models.Like{}).Where("user_verse_id = ?", userVerseID).Count(&likesCount).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve likes count"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"likes_count": likesCount})
	}
}

func ToggleLike(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		userVerseIDStr := c.Param("id")
		userVerseID, _ := strconv.Atoi(userVerseIDStr)

		var like models.Like
		if err := db.Where("user_id = ? AND user_verse_id = ?", userID, userVerseID).First(&like).Error; err == nil {
			db.Delete(&like)
			c.JSON(http.StatusOK, gin.H{"message": "Like removed"})
		} else {
			like.UserID = userID
			like.UserVerseID = userVerseID
			db.Create(&like)
			c.JSON(http.StatusOK, gin.H{"message": "Verse liked"})
		}
	}
}
func GetCommentRequests(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		var notifications []models.Notification
		if err := db.Where("user_id = ?", userID).Find(&notifications).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve comment requests"})
			return
		}

		c.JSON(http.StatusOK, notifications)
	}
}
func AddComment(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		userVerseIDStr := c.Param("id")
		userVerseID, err := strconv.Atoi(userVerseIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid UserVerse ID"})
			return
		}

		var comment models.Comment
		if err := c.ShouldBindJSON(&comment); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		comment.UserID = userID
		comment.UserVerseID = userVerseID

		parentCommentIDStr := c.Query("parentCommentID")
		if parentCommentIDStr != "" {
			parentCommentID, err := strconv.Atoi(parentCommentIDStr)
			if err == nil {
				parentCommentIDUint := uint(parentCommentID)
				comment.ParentCommentID = &parentCommentIDUint
			}
		}

		var user models.User
		if err := db.First(&user, userID).Error; err == nil {
			comment.Username = user.Username
		}

		if err := db.Create(&comment).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create comment"})
			return
		}

		var notification models.Notification
		if comment.ParentCommentID != nil {
			var parentComment models.Comment
			if err := db.First(&parentComment, *comment.ParentCommentID).Error; err == nil {
				notification = models.Notification{
					UserID:      parentComment.UserID,
					Content:     "You have a new reply on your comment.",
					CommentID:   &comment.CommentID,
					UserVerseID: parentComment.UserVerseID,
				}
			}
		} else {
			var userVerse models.UserVerse
			if err := db.First(&userVerse, userVerseID).Error; err == nil {
				notification = models.Notification{
					UserID:      userVerse.UserID,
					Content:     "You have a new comment on your verse.",
					CommentID:   &comment.CommentID,
					UserVerseID: int(userVerse.UserVerseID),
				}
			}
		}

		if err := db.Create(&notification).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create notification"})
			return
		}

		c.JSON(http.StatusOK, comment)
	}
}

func UpdateComment(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		commentID := c.Param("commentID")

		var existingComment models.Comment
		if err := db.First(&existingComment, "comment_id = ? AND user_id = ?", commentID, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Comment not found"})
			return
		}

		var updatedComment models.Comment
		if err := c.ShouldBindJSON(&updatedComment); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		existingComment.Content = updatedComment.Content
		db.Save(&existingComment)

		c.JSON(http.StatusOK, existingComment)
	}
}

func DeleteComment(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		commentID := c.Param("commentID")

		var existingComment models.Comment
		if err := db.First(&existingComment, "comment_id = ? AND user_id = ?", commentID, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Comment not found"})
			return
		}

		// Anonymize and redact the comment
		existingComment.Username = "redacted"
		existingComment.Content = ""
		existingComment.UserID = 0

		db.Save(&existingComment)
		c.JSON(http.StatusOK, gin.H{"message": "Comment deleted and anonymized"})
	}
}

func GetComments(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userVerseID := c.Param("id")

		var comments []models.Comment

		err := db.Raw(`
		SELECT comments.*, 
		       CASE 
		         WHEN users.user_id IS NULL THEN 'redacted'
		         ELSE users.username 
		       END AS username 
		FROM comments
		LEFT JOIN users ON users.user_id = comments.user_id
		WHERE comments.user_verse_id = ?`, userVerseID).Scan(&comments).Error

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		for i, comment := range comments {
			if comment.UserID == 0 {
				comments[i].Username = "redacted"
			}
		}

		c.JSON(http.StatusOK, comments)
	}
}
