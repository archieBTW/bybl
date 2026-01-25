package models

import "time"

type Church struct {
	ChurchID    uint      `gorm:"primaryKey" json:"church_id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Address     string    `json:"address"`
	City        string    `json:"city"`
	State       string    `json:"state"`
	Country     string    `json:"country"`
	ZipCode     string    `json:"zip_code"`
	Latitude    float64   `json:"latitude"`
	Longitude   float64   `json:"longitude"`
	Website     string    `json:"website"`
	Phone       string    `json:"phone"`
	Email       string    `json:"email"`
	AvatarURL   string    `json:"avatar_url"` // <- ✅ Add this for church profile picture
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type ChurchEvent struct {
	EventID     uint `gorm:"primaryKey"`
	Title       string
	Description string
	StartTime   time.Time
	EndTime     time.Time
	Location    string
	ChurchID    uint `gorm:"index"`
	GroupID     uint `gorm:"index"`
	GroupName   string
	CreatedBy   uint `gorm:"index"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Message struct {
	MessageID uint `gorm:"primaryKey"`
	Content   string
	Title     string
	ChurchID  uint `gorm:"index"`
	GroupID   uint `gorm:"index"`
	CreatedBy uint `gorm:"index"`
	Username  string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type PrayerRequest struct {
	RequestID   uint `gorm:"primaryKey"`
	Content     string
	IsAnonymous bool
	ChurchID    uint `gorm:"index"`
	GroupID     uint `gorm:"index"`
	CreatedBy   uint `gorm:"index"`
	Username    string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}
