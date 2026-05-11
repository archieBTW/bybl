package handlers

import (
	"fmt"
	"net/http"
	"path/filepath"
	"theword/Backend/lib/models"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// GetMapData retrieves all paths and their POIs
func GetMapData(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var paths []models.BibleMapPath
		// Preload POIs
		if err := db.Preload("POIs").Find(&paths).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch map data"})
			return
		}
		c.JSON(http.StatusOK, paths)
	}
}

// CreatePOI adds a new POI
func CreatePOI(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var input models.MapPOI
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if err := db.Create(&input).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create POI"})
			return
		}

		c.JSON(http.StatusCreated, input)
	}
}

// UpdatePOI updates an existing POI
func UpdatePOI(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		var poi models.MapPOI

		if err := db.First(&poi, id).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "POI not found"})
			return
		}

		var input models.MapPOI
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Update fields
		poi.Title = input.Title
		poi.Description = input.Description
		poi.Latitude = input.Latitude
		poi.Longitude = input.Longitude
		poi.ImageURL = input.ImageURL
		poi.RequiredChapterIDs = input.RequiredChapterIDs
		poi.UnlockedChapterID = input.UnlockedChapterID
		poi.PathPointIndex = input.PathPointIndex
		poi.BibleMapPathID = input.BibleMapPathID

		if err := db.Save(&poi).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update POI"})
			return
		}

		c.JSON(http.StatusOK, poi)
	}
}

// DeletePOI deletes a POI
func DeletePOI(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		if err := db.Delete(&models.MapPOI{}, id).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete POI"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "POI deleted successfully"})
	}
}

// UploadPOIImage handles image uploads for POIs
func UploadPOIImage(c *gin.Context) {
	file, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}

	// Create a unique filename
	filename := fmt.Sprintf("%d_%s", time.Now().Unix(), filepath.Base(file.Filename))
	dst := filepath.Join("uploads", "pois", filename)

	// Save the file
	if err := c.SaveUploadedFile(file, dst); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file"})
		return
	}

	// Return the URL
	url := fmt.Sprintf("/uploads/pois/%s", filename)
	c.JSON(http.StatusOK, gin.H{"url": url})
}

// CreatePath creates a new map path
func CreatePath(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var input models.BibleMapPath
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if err := db.Create(&input).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create path"})
			return
		}

		c.JSON(http.StatusCreated, input)
	}
}

// UpdatePath updates an existing path
func UpdatePath(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		var path models.BibleMapPath

		if err := db.First(&path, id).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Path not found"})
			return
		}

		var input models.BibleMapPath
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		path.Name = input.Name
		path.Description = input.Description
		path.Points = input.Points
		path.Slug = input.Slug

		if err := db.Save(&path).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update path"})
			return
		}

		c.JSON(http.StatusOK, path)
	}
}

// DeletePath deletes a path
func DeletePath(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		if err := db.Delete(&models.BibleMapPath{}, id).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete path"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Path deleted successfully"})
	}
}

// ServeAdminPanel serves the admin HTML file
func ServeAdminPanel(c *gin.Context) {
	c.File("lib/templates/admin_map.html")
}
