package handlers

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"theword/Backend/lib/models"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// Upload user profile avatar
func UploadUserAvatarHandler(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		handleAvatarUpload(c, db, "avatars", fmt.Sprintf("%d", userID), "users", "user_id", userID)
	}
}

func UploadChurchAvatarHandler(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		churchID := c.Param("id")

		// Fetch user from DB
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		// Only allow admins to upload church avatars
		if !user.IsAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only church leaders can update the church avatar"})
			return
		}

		handleAvatarUpload(c, db, "churches", churchID, "churches", "church_id", churchID)
	}
}

// Upload small group profile avatar
func UploadSmallGroupAvatarHandler(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")
		handleAvatarUpload(c, db, "groups", groupID, "small_groups", "group_id", groupID)
	}
}

func handleAvatarUpload(c *gin.Context, db *gorm.DB, folder, id, table, idColumn string, idValue interface{}) {
	file, header, err := c.Request.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read image"})
		return
	}
	defer file.Close()

	buff := make([]byte, 512)
	_, err = file.Read(buff)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read file header"})
		return
	}
	fileType := http.DetectContentType(buff)
	allowedTypes := []string{"image/jpeg", "image/png", "image/webp"}
	valid := false
	for _, t := range allowedTypes {
		if t == fileType {
			valid = true
			break
		}
	}
	if !valid {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file type"})
		return
	}
	file.Seek(0, 0)

	extension := filepath.Ext(header.Filename)
	newKey := fmt.Sprintf("%s/%s-%d%s", folder, id, time.Now().Unix(), extension)

	sess, err := session.NewSession(&aws.Config{
		Region:           aws.String(os.Getenv("WASABI_REGION")),
		Endpoint:         aws.String(os.Getenv("WASABI_ENDPOINT")),
		S3ForcePathStyle: aws.Bool(true),
		Credentials: credentials.NewStaticCredentials(
			os.Getenv("WASABI_ACCESS_KEY"),
			os.Getenv("WASABI_SECRET_KEY"),
			"",
		),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to Wasabi"})
		return
	}
	svc := s3.New(sess)

	buf := new(bytes.Buffer)
	_, err = buf.ReadFrom(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file buffer"})
		return
	}

	// 1. Upload the new avatar first
	_, err = svc.PutObject(&s3.PutObjectInput{
		Bucket:      aws.String(os.Getenv("WASABI_BUCKET")),
		Key:         aws.String(newKey),
		Body:        bytes.NewReader(buf.Bytes()),
		ContentType: aws.String(fileType),
		ACL:         aws.String("public-read"),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload image to storage"})
		return
	}

	// 2. After successful upload, delete old avatar
	var oldKey string
	db.Table(table).Select("avatar_url").Where(fmt.Sprintf("%s = ?", idColumn), idValue).Scan(&oldKey)
	if oldKey != "" {
		_, _ = svc.DeleteObject(&s3.DeleteObjectInput{
			Bucket: aws.String(os.Getenv("WASABI_BUCKET")),
			Key:    aws.String(oldKey),
		})
		// Optional: Wait for deletion to complete
		_ = svc.WaitUntilObjectNotExists(&s3.HeadObjectInput{
			Bucket: aws.String(os.Getenv("WASABI_BUCKET")),
			Key:    aws.String(oldKey),
		})
	}

	// 3. Update the database with the new key
	if err := db.Table(table).Where(fmt.Sprintf("%s = ?", idColumn), idValue).Update("avatar_url", newKey).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save avatar key to database"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"avatar_key": newKey})
}

// func handleAvatarUpload(c *gin.Context, db *gorm.DB, folder, id, table, idColumn string, idValue interface{}) {
// 	file, header, err := c.Request.FormFile("avatar")
// 	if err != nil {
// 		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read image"})
// 		return
// 	}
// 	defer file.Close()

// 	buff := make([]byte, 512)
// 	_, err = file.Read(buff)
// 	if err != nil {
// 		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read file header"})
// 		return
// 	}
// 	fileType := http.DetectContentType(buff)
// 	allowedTypes := []string{"image/jpeg", "image/png", "image/webp"}
// 	valid := false
// 	for _, t := range allowedTypes {
// 		if t == fileType {
// 			valid = true
// 			break
// 		}
// 	}
// 	if !valid {
// 		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file type"})
// 		return
// 	}

// 	file.Seek(0, 0)
// 	extension := filepath.Ext(header.Filename)
// 	key := fmt.Sprintf("%s/%s%s", folder, id, extension)

// 	sess, err := session.NewSession(&aws.Config{
// 		Region:           aws.String(os.Getenv("WASABI_REGION")),
// 		Endpoint:         aws.String(os.Getenv("WASABI_ENDPOINT")),
// 		S3ForcePathStyle: aws.Bool(true),
// 		Credentials: credentials.NewStaticCredentials(
// 			os.Getenv("WASABI_ACCESS_KEY"),
// 			os.Getenv("WASABI_SECRET_KEY"),
// 			"",
// 		),
// 	})
// 	if err != nil {
// 		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to Wasabi"})
// 		return
// 	}
// 	svc := s3.New(sess)

// 	buf := new(bytes.Buffer)
// 	_, err = buf.ReadFrom(file)
// 	if err != nil {
// 		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file buffer"})
// 		return
// 	}

// 	_, err = svc.PutObject(&s3.PutObjectInput{
// 		Bucket:      aws.String(os.Getenv("WASABI_BUCKET")),
// 		Key:         aws.String(key),
// 		Body:        bytes.NewReader(buf.Bytes()),
// 		ContentType: aws.String(fileType),
// 		ACL:         aws.String("public-read"),
// 	})
// 	if err != nil {
// 		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload image to storage"})
// 		return
// 	}

// 	// Save the key to the correct table
// 	if err := db.Table(table).Where(fmt.Sprintf("%s = ?", idColumn), idValue).Update("avatar_url", key).Error; err != nil {
// 		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save avatar key to database"})
// 		return
// 	}

// 	c.JSON(http.StatusOK, gin.H{"avatar_key": key})
// }

func GetAvatarHandler(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		entityType := c.Query("type")
		entityID := c.Query("id")

		if entityType == "" || entityID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Missing type or id"})
			return
		}

		var key string

		switch entityType {
		case "user":
			var user models.User
			if err := db.First(&user, "user_id = ?", entityID).Error; err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
				return
			}
			key = user.AvatarURL
		case "church":
			var church models.Church
			if err := db.First(&church, "church_id = ?", entityID).Error; err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "Church not found"})
				return
			}
			key = church.AvatarURL
		case "group":
			var group models.SmallGroup
			if err := db.First(&group, "group_id = ?", entityID).Error; err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
				return
			}
			key = group.AvatarURL
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid type"})
			return
		}

		if key == "" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Avatar not set"})
			return
		}

		sess, err := session.NewSession(&aws.Config{
			Region:           aws.String(os.Getenv("WASABI_REGION")),
			Endpoint:         aws.String(os.Getenv("WASABI_ENDPOINT")),
			S3ForcePathStyle: aws.Bool(true),
			Credentials: credentials.NewStaticCredentials(
				os.Getenv("WASABI_ACCESS_KEY"),
				os.Getenv("WASABI_SECRET_KEY"),
				"",
			),
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to Wasabi"})
			return
		}

		svc := s3.New(sess)

		obj, err := svc.GetObject(&s3.GetObjectInput{
			Bucket: aws.String(os.Getenv("WASABI_BUCKET")),
			Key:    aws.String(key),
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch avatar"})
			return
		}
		defer obj.Body.Close()

		c.Header("Content-Type", *obj.ContentType)
		c.Header("Content-Length", fmt.Sprintf("%d", *obj.ContentLength))
		c.Header("Cache-Control", "public, max-age=2592000, immutable") // 30 days
		c.Header("Expires", time.Now().AddDate(0, 0, 30).Format(http.TimeFormat))

		_, _ = io.Copy(c.Writer, obj.Body)
	}
}
