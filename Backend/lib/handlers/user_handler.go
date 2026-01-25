package handlers

import (
	"fmt"

	"log"
	"math/rand"
	"net/http"
	"os"

	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt"
	"github.com/resend/resend-go/v2"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"theword/Backend/lib/models"
	"theword/Backend/lib/secrets"
)

func RegisterUser(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req models.RegistrationRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		passwordHash, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		user := models.User{
			Email:           req.Email,
			Username:        req.Username,
			PasswordHash:    string(passwordHash),
			PublicProfile:   false,
			PrimaryColor:    4284955319, // ARGB for white
			HighlightColor:  4294961979,
			DarkMode:        true,
			TranslationId:   "ESV",
			TranslationName: "English Standard Version",
		}

		if err := db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "User registered successfully"})
	}
}
func LoginUser(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req models.LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var user models.User
		// Convert the email to lowercase for case-insensitive comparison
		emailLower := strings.ToLower(req.Email)
		if err := db.First(&user, "LOWER(email) = ?", emailLower).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		}

		expirationTime := time.Now().Add(30 * 24 * time.Hour)
		claims := &models.Claims{
			UserID: user.UserID,
			StandardClaims: jwt.StandardClaims{
				ExpiresAt: expirationTime.Unix(),
			},
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString(secrets.JwtKey)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not generate token"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"token": tokenString})
	}
}

func GetUserSettings(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"user_id":          user.UserID,
			"primary_color":    user.PrimaryColor,
			"highlight_color":  user.HighlightColor,
			"dark_mode":        user.DarkMode,
			"public_profile":   user.PublicProfile,
			"translation_id":   user.TranslationId,
			"translation_name": user.TranslationName,
			"avatar_url":       user.AvatarURL,
		})
	}
}
func UpdateUserSettingsHandler(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		var req struct {
			PrimaryColor    int    `json:"primary_color"`
			HighlightColor  int    `json:"highlight_color"`
			DarkMode        bool   `json:"dark_mode"`
			PublicProfile   bool   `json:"public_profile"`
			TranslationId   string `json:"translation_id"`
			TranslationName string `json:"translation_name"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		updates := map[string]interface{}{
			"primary_color":    req.PrimaryColor,
			"highlight_color":  req.HighlightColor,
			"dark_mode":        req.DarkMode,
			"public_profile":   req.PublicProfile,
			"translation_id":   req.TranslationId,
			"translation_name": req.TranslationName,
		}

		if err := db.Model(&models.User{}).Where("user_id = ?", userID).Updates(updates).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Settings updated successfully"})
	}
}

func CreateAdminUser(db *gorm.DB) {
	var user models.User
	if err := db.First(&user, "email = ?", "admin@example.com").Error; err == nil {
		return
	}

	passwordHash, _ := bcrypt.GenerateFromPassword([]byte("hackerman"), bcrypt.DefaultCost)
	admin := models.User{
		Email:           "admin@example.com",
		Username:        "Tom",
		PasswordHash:    string(passwordHash),
		PublicProfile:   true,
		PrimaryColor:    0xFF000000, // ARGB for black
		HighlightColor:  0xFFFF0000, // ARGB for red
		DarkMode:        true,
		TranslationId:   "ESV",
		TranslationName: "English Standard Version",
	}
	db.Create(&admin)
	log.Println("Admin user created or already exists.")
}

func GetUser(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)
		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		c.JSON(http.StatusOK, user)
	}
}

func DeleteUser(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		tx := db.Begin()

		// Step 1: Delete all related content
		if err := tx.Where("user_id = ?", userID).Delete(&models.UserVerse{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user verses"})
			return
		}
		if err := tx.Where("user_id = ?", userID).Delete(&models.Like{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete likes"})
			return
		}
		if err := tx.Where("user_id = ?", userID).Delete(&models.Comment{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete comments"})
			return
		}
		if err := tx.Where("user_id = ? OR friend_id = ?", userID, userID).Delete(&models.Friend{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete friends"})
			return
		}
		if err := tx.Where("user_id = ?", userID).Delete(&models.Notification{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete notifications"})
			return
		}
		if err := tx.Where("created_by = ?", userID).Delete(&models.Message{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete messages"})
			return
		}
		if err := tx.Where("created_by = ?", userID).Delete(&models.ChurchEvent{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete events"})
			return
		}
		if err := tx.Where("created_by = ?", userID).Delete(&models.PrayerRequest{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete prayer requests"})
			return
		}
		if err := tx.Where("user_id = ?", userID).Delete(&models.GroupMember{}).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete group memberships"})
			return
		}

		// Step 2: Delete the user
		if err := tx.Delete(&models.User{}, "user_id = ?", userID).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user"})
			return
		}

		tx.Commit()
		c.JSON(http.StatusOK, gin.H{"message": "User deleted successfully"})
	}
}

// Helper: Generate random 6-digit reset code
func generateResetCode() string {
	return fmt.Sprintf("%06d", rand.Intn(1000000))
}

func sendResetEmail(toEmail, resetCode string) error {
	fmt.Println("Sending email...")
	fmt.Println("From address:", os.Getenv("EMAIL_ADDRESS"))
	fmt.Println("To address:", toEmail)
	fmt.Println("Reset Code:", resetCode)

	client := resend.NewClient(os.Getenv("RESEND_API_KEY"))

	params := &resend.SendEmailRequest{
		From:    os.Getenv("EMAIL_ADDRESS"),
		To:      []string{toEmail},
		Subject: "Password Reset Code",
		Html:    fmt.Sprintf("<p>Your password reset code is: <strong>%s</strong></p>", resetCode),
		Text:    fmt.Sprintf("Your password reset code is: %s", resetCode),
	}

	sent, err := client.Emails.Send(params)
	if err != nil {
		fmt.Println("Error sending email:", err)
		return err
	}

	fmt.Println("Email sent ID:", sent.Id)
	return nil
}

// Handler: User requests password reset (sends email)
func RequestPasswordReset(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Email string `json:"email"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var user models.User
		if err := db.First(&user, "LOWER(email) = ?", strings.ToLower(req.Email)).Error; err != nil {
			// Don't leak whether email exists
			c.JSON(http.StatusOK, gin.H{"message": "If the email exists, a reset code has been sent."})
			return
		}

		resetCode := generateResetCode()
		user.ResetCode = resetCode
		user.ResetCodeExpiry = time.Now().Add(15 * time.Minute)

		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not save reset code"})
			return
		}

		if err := sendResetEmail(user.Email, resetCode); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not send reset email"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "If the email exists, a reset code has been sent."})
	}
}

// Handler: User verifies reset code and resets password
func VerifyResetCode(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			Email       string `json:"email"`
			ResetCode   string `json:"reset_code"`
			NewPassword string `json:"new_password"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var user models.User
		if err := db.First(&user, "LOWER(email) = ?", strings.ToLower(req.Email)).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid reset attempt"})
			return
		}

		if user.ResetCode != req.ResetCode || time.Now().After(user.ResetCodeExpiry) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired reset code"})
			return
		}

		passwordHash, _ := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		user.PasswordHash = string(passwordHash)
		user.ResetCode = ""
		user.ResetCodeExpiry = time.Time{}

		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset password"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Password reset successfully"})
	}
}

// (Optional bonus) Handler: Logged-in user changes password
func ChangePassword(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("userID").(uint)

		var req struct {
			OldPassword string `json:"old_password"`
			NewPassword string `json:"new_password"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var user models.User
		if err := db.First(&user, "user_id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.OldPassword)); err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Old password incorrect"})
			return
		}

		passwordHash, _ := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		user.PasswordHash = string(passwordHash)

		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to change password"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Password changed successfully"})
	}
}

func GetUserByID(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		requestingUserID := c.MustGet("userID").(uint)
		idParam := c.Param("id")

		var targetUser models.User
		if err := db.First(&targetUser, "user_id = ?", idParam).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// If not public, check if they are friends
		if !targetUser.PublicProfile {
			var friend models.Friend
			if err := db.Where(
				"(user_id = ? AND friend_id = ? AND status = 'accepted') OR (user_id = ? AND friend_id = ? AND status = 'accepted')",
				requestingUserID, targetUser.UserID,
				targetUser.UserID, requestingUserID,
			).First(&friend).Error; err != nil {
				// Not friends either
				c.JSON(http.StatusForbidden, gin.H{"error": "User profile is private"})
				return
			}
		}

		c.JSON(http.StatusOK, gin.H{
			"user_id":          targetUser.UserID,
			"username":         targetUser.Username,
			"public_profile":   targetUser.PublicProfile,
			"primary_color":    targetUser.PrimaryColor,
			"highlight_color":  targetUser.HighlightColor,
			"dark_mode":        targetUser.DarkMode,
			"translation_id":   targetUser.TranslationId,
			"translation_name": targetUser.TranslationName,
			"avatar_url":       targetUser.AvatarURL,
			"church_id":        targetUser.ChurchID,
		})
	}
}
