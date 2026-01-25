package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"theword/Backend/lib/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SearchSavedVerses(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		page := c.DefaultQuery("page", "1")
		pageSize := c.DefaultQuery("pageSize", "10")
		searchQuery := c.DefaultQuery("q", "") // Get the search query parameter

		pageInt, err := strconv.Atoi(page)
		if err != nil {
			pageInt = 1
		}
		pageSizeInt, err := strconv.Atoi(pageSize)
		if err != nil {
			pageSizeInt = 10
		}

		var verses []models.UserVerse
		offset := (pageInt - 1) * pageSizeInt

		// Modify the query to include search conditions for verse_id, content, and note
		query := db.Select("user_verse_id, verse_id, content, note, is_published").
			Where("user_id = ?", userID).
			Offset(offset).Limit(pageSizeInt)

		if searchQuery != "" {
			// Apply the search filter
			searchString := "%" + searchQuery + "%"
			query = query.Where("CAST(verse_id AS CHAR) LIKE ? OR content LIKE ? OR note LIKE ?", searchString, searchString, searchString)
		}

		if err := query.Find(&verses).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, verses)
	}
}

func SearchPublicVerses(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint) // Get current user ID
		searchQuery := c.Query("q")          // Get the search query

		page := c.DefaultQuery("page", "1")
		pageSize := c.DefaultQuery("pageSize", "10")
		pageInt, err := strconv.Atoi(page)
		if err != nil {
			pageInt = 1
		}
		pageSizeInt, err := strconv.Atoi(pageSize)
		if err != nil {
			pageSizeInt = 10
		}

		var verses []struct {
			models.UserVerse
			Username string `json:"username"`
		}

		offset := (pageInt - 1) * pageSizeInt

		// Modify the query to include search conditions for VerseID, Content, and Note
		err = db.Raw(`
		SELECT uv.*, u.username 
		FROM user_verses uv
		JOIN users u ON u.user_id = uv.user_id
		LEFT JOIN friends f ON (
			(f.user_id = u.user_id AND f.friend_id = ?) OR 
			(f.friend_id = u.user_id AND f.user_id = ?)
		)
		WHERE uv.is_published = true AND (
			u.user_id = ? OR 
			u.public_profile = true OR 
			f.status = 'accepted'
		) AND (
			CAST(uv.user_verse_id AS CHAR) LIKE ? OR 
			uv.content LIKE ? OR 
			uv.note LIKE ?
		)
		ORDER BY uv.user_verse_id DESC
		LIMIT ? OFFSET ?
	`, userID, userID, userID, "%"+searchQuery+"%", "%"+searchQuery+"%", "%"+searchQuery+"%", pageSizeInt, offset).Scan(&verses).Error

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to search verses: %v", err)})
			return
		}

		c.JSON(http.StatusOK, verses)
	}
}

// func GetPublicVerses(db *gorm.DB) gin.HandlerFunc {
// 	return func(c *gin.Context) {
// 		userID := c.MustGet("userID").(uint) // Get current user ID
// 		page := c.DefaultQuery("page", "1")
// 		pageSize := c.DefaultQuery("pageSize", "10")
// 		pageInt, err := strconv.Atoi(page)
// 		if err != nil {
// 			pageInt = 1
// 		}
// 		pageSizeInt, err := strconv.Atoi(pageSize)
// 		if err != nil {
// 			pageSizeInt = 10
// 		}

// 		var verses []struct {
// 			models.UserVerseWithMeta
// 			Username string `json:"username"`
// 		}
// 		offset := (pageInt - 1) * pageSizeInt

// 		err = db.Raw(`
// 	SELECT
// 		uv.*,
// 		u.username,
// 		COALESCE(l.likes_count, 0) AS likes_count,
// 		COALESCE(c.comment_count, 0) AS comment_count
// 	FROM user_verses uv
// 	JOIN users u ON u.user_id = uv.user_id
// 	LEFT JOIN (
// 		SELECT user_verse_id, COUNT(*) AS likes_count
// 		FROM likes
// 		GROUP BY user_verse_id
// 	) l ON l.user_verse_id = uv.user_verse_id
// 	LEFT JOIN (
// 		SELECT user_verse_id, COUNT(*) AS comment_count
// 		FROM comments
// 		GROUP BY user_verse_id
// 	) c ON c.user_verse_id = uv.user_verse_id
// 	LEFT JOIN friends f ON (
// 		(f.user_id = u.user_id AND f.friend_id = ?) OR
// 		(f.friend_id = u.user_id AND f.user_id = ?)
// 	)
// 	WHERE uv.is_published = true AND (
// 		u.user_id = ? OR
// 		u.public_profile = true OR
// 		f.status = 'accepted'
// 	)
// 	ORDER BY uv.user_verse_id DESC
// 	LIMIT ? OFFSET ?
// `, userID, userID, userID, pageSizeInt, offset).Scan(&verses).Error

// 		// 	err = db.Raw(`
// 		// 	SELECT uv.*, u.username
// 		// 	FROM user_verses uv
// 		// 	JOIN users u ON u.user_id = uv.user_id
// 		// 	LEFT JOIN friends f ON (
// 		// 		(f.user_id = u.user_id AND f.friend_id = ?) OR
// 		// 		(f.friend_id = u.user_id AND f.user_id = ?)
// 		// 	)
// 		// 	WHERE uv.is_published = true AND (
// 		// 		u.user_id = ? OR
// 		// 		u.public_profile = true OR
// 		// 		f.status = 'accepted'
// 		// 	)
// 		// 	ORDER BY uv.user_verse_id DESC
// 		// 	LIMIT ? OFFSET ?
// 		// `, userID, userID, userID, pageSizeInt, offset).Scan(&verses).Error

// 		if err != nil {
// 			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to retrieve verses: %v", err)})
// 			return
// 		}

// 		c.JSON(http.StatusOK, verses)
// 	}
// }

func PublishVerse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		verseID := c.Param("id")

		var req struct {
			IsPublished bool `json:"is_published"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
			return
		}

		var verse models.UserVerse
		if err := db.First(&verse, "user_verse_id = ? AND user_id = ?", verseID, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Verse not found or you don't have permission to update this verse"})
			return
		}

		verse.IsPublished = req.IsPublished
		if err := db.Save(&verse).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update verse publication status"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Verse publication status updated successfully"})
	}
}

func UnpublishVerse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		verseID := c.Param("id")

		var verse models.UserVerse
		if err := db.First(&verse, "user_verse_id = ? AND user_id = ?", verseID, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Verse not found or you don't have permission to update this verse"})
			return
		}

		verse.IsPublished = false
		if err := db.Save(&verse).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update verse publication status"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Verse unpublished successfully"})
	}
}

func SaveVerse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		var verse models.UserVerse
		if err := c.ShouldBindJSON(&verse); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		verse.UserID = userID

		if err := db.Save(&verse).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":     "Verse saved successfully",
			"userVerseID": verse.UserVerseID,
		})
	}
}

func UpdateVerse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		userVerseID := c.Param("id")

		var req struct {
			Note string `json:"note"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
			return
		}

		var verse models.UserVerse
		if err := db.First(&verse, "user_verse_id = ? AND user_id = ?", userVerseID, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Verse not found or you don't have permission to update this verse"})
			return
		}

		verse.Note = req.Note
		if err := db.Save(&verse).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update verse"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Verse updated successfully", "verse": verse})
	}
}

// func GetSavedVerses(db *gorm.DB) gin.HandlerFunc {
// 	return func(c *gin.Context) {
// 		userID := c.MustGet("userID").(uint)
// 		page := c.DefaultQuery("page", "1")
// 		pageSize := c.DefaultQuery("pageSize", "10")
// 		pageInt, err := strconv.Atoi(page)
// 		if err != nil {
// 			pageInt = 1
// 		}
// 		pageSizeInt, err := strconv.Atoi(pageSize)
// 		if err != nil {
// 			pageSizeInt = 10
// 		}

// 		var verses []models.UserVerseWithMeta
// 		offset := (pageInt - 1) * pageSizeInt

// 		if err := db.Raw(`
// 	SELECT
// 		uv.*,
// 		COALESCE(l.likes_count, 0) AS likes_count,
// 		COALESCE(c.comment_count, 0) AS comment_count
// 	FROM user_verses uv
// 	LEFT JOIN (
// 		SELECT user_verse_id, COUNT(*) AS likes_count
// 		FROM likes
// 		GROUP BY user_verse_id
// 	) l ON l.user_verse_id = uv.user_verse_id
// 	LEFT JOIN (
// 		SELECT user_verse_id, COUNT(*) AS comment_count
// 		FROM comments
// 		GROUP BY user_verse_id
// 	) c ON c.user_verse_id = uv.user_verse_id
// 	WHERE uv.user_id = ?
// 	ORDER BY uv.user_verse_id DESC
// 	LIMIT ? OFFSET ?
// `, userID, pageSizeInt, offset).Scan(&verses).Error; err != nil {
// 			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
// 			return
// 		}

// 		// // if err := db.Select("user_verse_id, verse_id, content, note, is_published"). // Include is_published
// 		// 										// Where("user_id = ?", userID).Offset(offset).Limit(pageSizeInt).Find(&verses).Error; err != nil {
// 		// 	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
// 		// 	return
// 		// }
// 		c.JSON(http.StatusOK, verses)
// 	}
// }

func GetPublicVerses(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		page := c.DefaultQuery("page", "1")
		pageSize := c.DefaultQuery("pageSize", "10")

		pageInt, err := strconv.Atoi(page)
		if err != nil {
			pageInt = 1
		}
		pageSizeInt, err := strconv.Atoi(pageSize)
		if err != nil {
			pageSizeInt = 10
		}

		var verses []models.UserVerseWithMeta
		offset := (pageInt - 1) * pageSizeInt

		err = db.Raw(`
            SELECT 
                uv.user_verse_id,
                uv.verse_id,
                uv.content,
                uv.note,
                uv.is_published,
                uv.user_id,
                u.username,
                COALESCE(l.likes_count, 0) AS likes_count,
                COALESCE(c.comment_count, 0) AS comment_count
            FROM user_verses uv
            JOIN users u ON u.user_id = uv.user_id
            LEFT JOIN (
                SELECT user_verse_id, COUNT(*) AS likes_count
                FROM likes
                GROUP BY user_verse_id
            ) l ON l.user_verse_id = uv.user_verse_id
            LEFT JOIN (
                SELECT user_verse_id, COUNT(*) AS comment_count
                FROM comments
                GROUP BY user_verse_id
            ) c ON c.user_verse_id = uv.user_verse_id
            LEFT JOIN friends f ON (
                (f.user_id = u.user_id AND f.friend_id = ?) OR 
                (f.friend_id = u.user_id AND f.user_id = ?)
            )
            WHERE uv.is_published = true AND (
                u.user_id = ? OR 
                u.public_profile = true OR 
                f.status = 'accepted'
            )
            ORDER BY uv.user_verse_id DESC
            LIMIT ? OFFSET ?
        `, userID, userID, userID, pageSizeInt, offset).Scan(&verses).Error

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to retrieve verses: %v", err)})
			return
		}

		c.JSON(http.StatusOK, verses)
	}
}

func GetSavedVerses(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		page := c.DefaultQuery("page", "1")
		pageSize := c.DefaultQuery("pageSize", "10")

		pageInt, err := strconv.Atoi(page)
		if err != nil {
			pageInt = 1
		}
		pageSizeInt, err := strconv.Atoi(pageSize)
		if err != nil {
			pageSizeInt = 10
		}

		var verses []models.UserVerseWithMeta
		offset := (pageInt - 1) * pageSizeInt

		err = db.Raw(`
            SELECT 
                uv.user_verse_id,
                uv.verse_id,
                uv.content,
                uv.note,
                uv.is_published,
                uv.user_id,
                '' AS username, -- Saved verses are private, no username needed
                COALESCE(l.likes_count, 0) AS likes_count,
                COALESCE(c.comment_count, 0) AS comment_count
            FROM user_verses uv
            LEFT JOIN (
                SELECT user_verse_id, COUNT(*) AS likes_count
                FROM likes
                GROUP BY user_verse_id
            ) l ON l.user_verse_id = uv.user_verse_id
            LEFT JOIN (
                SELECT user_verse_id, COUNT(*) AS comment_count
                FROM comments
                GROUP BY user_verse_id
            ) c ON c.user_verse_id = uv.user_verse_id
            WHERE uv.user_id = ?
            ORDER BY uv.user_verse_id DESC
            LIMIT ? OFFSET ?
        `, userID, pageSizeInt, offset).Scan(&verses).Error

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to retrieve saved verses: %v", err)})
			return
		}

		c.JSON(http.StatusOK, verses)
	}
}

func CreateVerse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		var verse models.UserVerse
		if err := c.ShouldBindJSON(&verse); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		verse.UserID = userID
		db.Create(&verse)
		c.JSON(http.StatusOK, verse)
	}
}

func GetVerse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var verse models.UserVerse
		if err := db.First(&verse, "user_verse_id = ?", c.Param("id")).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Verse not found"})
			return
		}
		c.JSON(http.StatusOK, verse)
	}
}

func DeleteVerse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		verseID := c.Param("id")

		var verse models.UserVerse
		// Check if the verse exists and belongs to the current user
		if err := db.First(&verse, "user_verse_id = ? AND user_id = ?", verseID, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Verse not found or you don't have permission to delete this verse"})
			return
		}

		// Delete the verse
		if err := db.Delete(&verse).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Verse deleted successfully"})
	}
}
