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
	UserID              uint      `gorm:"primaryKey" json:"user_id" gofyr:"readonly"`
	Email               string    `gorm:"unique" json:"email" gofyr:"searchable,label:Email Address"`
	Username            string    `json:"username" gofyr:"searchable,label:Username"`
	PasswordHash        string    `json:"-" gofyr:"hidden"`
	PublicProfile       bool      `json:"public_profile" gofyr:"label:Public Profile"`
	PrimaryColor        int       `json:"primary_color" gofyr:"label:Primary Color"`
	HighlightColor      int       `json:"highlight_color" gofyr:"label:Highlight Color"`
	DarkMode            bool      `json:"dark_mode" gofyr:"label:Dark Mode"`
	TranslationId       string    `json:"translation_id" gofyr:"label:Bible Translation ID"`
	TranslationName     string    `json:"translation_name" gofyr:"label:Bible Translation"`
	IsAdmin             bool      `gorm:"default:false" json:"is_admin" gofyr:"label:Is Admin"`
	ForcePasswordChange bool      `gorm:"default:false" json:"force_password_change" gofyr:"label:Force Password Change"`
	ChurchID            uint      `gorm:"index" json:"church_id" gofyr:"label:Church ID"`
	ResetCode           string    `json:"-" gofyr:"hidden"`
	ResetCodeExpiry     time.Time `json:"-" gofyr:"hidden"`
	AvatarURL           string    `json:"avatar_url" gofyr:"type:image,disk:local,folder:avatars,label:Avatar"`
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
