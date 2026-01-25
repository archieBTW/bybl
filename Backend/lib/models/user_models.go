package models

import "time"

type UserResponse struct {
	UserID          uint   `json:"user_id"`
	Username        string `json:"username"`
	PublicProfile   bool   `json:"public_profile"`
	PrimaryColor    int    `json:"primary_color"`
	HighlightColor  int    `json:"highlight_color"`
	DarkMode        bool   `json:"dark_mode"`
	TranslationId   string `json:"translation_id"`
	TranslationName string `json:"translation_name"`
	ChurchID        uint   `json:"church_id"`
}

type User struct {
	UserID          uint   `gorm:"primaryKey"`
	Email           string `gorm:"unique"`
	Username        string
	PasswordHash    string
	PublicProfile   bool
	PrimaryColor    int
	HighlightColor  int
	DarkMode        bool
	TranslationId   string
	TranslationName string
	IsAdmin         bool `gorm:"default:false"`
	ChurchID        uint `gorm:"index"`
	ResetCode       string
	ResetCodeExpiry time.Time
	AvatarURL       string
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type RegistrationRequest struct {
	Email    string `json:"email"`
	Username string `json:"username"`
	Password string `json:"password"`
}
