package handlers

import (
	"net/http"
	"theword/Backend/lib/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func CreateBookmark(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		var bookmark models.Bookmark

		if err := c.ShouldBindJSON(&bookmark); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
			return
		}

		bookmark.UserID = userID
		if err := db.Create(&bookmark).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create bookmark"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Bookmark created successfully", "bookmark": bookmark})
	}
}

func GetBookmarks(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		var bookmarks []models.Bookmark

		if err := db.Where("user_id = ?", userID).Find(&bookmarks).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve bookmarks"})
			return
		}

		c.JSON(http.StatusOK, bookmarks)
	}
}

func DeleteBookmark(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		bookmarkID := c.Param("id")

		var bookmark models.Bookmark
		if err := db.First(&bookmark, "bookmark_id = ? AND user_id = ?", bookmarkID, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Bookmark not found or you don't have permission to delete it"})
			return
		}

		if err := db.Delete(&bookmark).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete bookmark"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Bookmark deleted successfully"})
	}
}
