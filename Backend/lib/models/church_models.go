package models

import "time"

type Church struct {
	ChurchID    uint      `gorm:"primaryKey" json:"church_id" gofyr:"readonly"`
	Name        string    `json:"name" gofyr:"searchable,label:Church Name"`
	Description string    `json:"description" gofyr:"type:textarea"`
	Address     string    `json:"address" gofyr:"searchable"`
	City        string    `json:"city" gofyr:"searchable"`
	State       string    `json:"state" gofyr:"searchable"`
	Country     string    `json:"country"`
	ZipCode     string    `json:"zip_code"`
	Latitude    float64   `json:"latitude"`
	Longitude   float64   `json:"longitude"`
	Website     string    `json:"website"`
	Phone       string    `json:"phone"`
	Email       string    `json:"email" gofyr:"searchable"`
	AvatarURL   string    `json:"avatar_url" gofyr:"type:image,disk:local,folder:churches,label:Church Avatar"`
	CreatedAt   time.Time `json:"created_at" gofyr:"readonly"`
	UpdatedAt   time.Time `json:"updated_at" gofyr:"readonly"`
}

type ChurchEvent struct {
	EventID     uint      `gorm:"primaryKey" json:"event_id" gofyr:"readonly"`
	Title       string    `json:"title" gofyr:"searchable,label:Event Title"`
	Description string    `json:"description" gofyr:"type:textarea"`
	StartTime   time.Time `json:"start_time" gofyr:"type:datetime,label:Start Time"`
	EndTime     time.Time `json:"end_time" gofyr:"type:datetime,label:End Time"`
	Location    string    `json:"location" gofyr:"searchable"`
	ChurchID    uint      `gorm:"index" json:"church_id"`
	GroupID     uint      `gorm:"index" json:"group_id"`
	GroupName   string    `json:"group_name"`
	CreatedBy   uint      `gorm:"index" json:"created_by"`
	CreatedAt   time.Time `json:"created_at" gofyr:"readonly"`
	UpdatedAt   time.Time `json:"updated_at" gofyr:"readonly"`
}

type Message struct {
	MessageID uint      `gorm:"primaryKey" json:"message_id" gofyr:"readonly"`
	Content   string    `json:"content" gofyr:"type:textarea,searchable"`
	Title     string    `json:"title" gofyr:"searchable"`
	ChurchID  uint      `gorm:"index" json:"church_id"`
	GroupID   uint      `gorm:"index" json:"group_id"`
	CreatedBy uint      `gorm:"index" json:"created_by"`
	Username  string    `json:"username" gofyr:"searchable"`
	CreatedAt time.Time `json:"created_at" gofyr:"readonly"`
	UpdatedAt time.Time `json:"updated_at" gofyr:"readonly"`
}

type PrayerRequest struct {
	RequestID   uint      `gorm:"primaryKey" json:"request_id" gofyr:"readonly"`
	Content     string    `json:"content" gofyr:"type:textarea,searchable"`
	IsAnonymous bool      `json:"is_anonymous" gofyr:"label:Anonymous"`
	ChurchID    uint      `gorm:"index" json:"church_id"`
	GroupID     uint      `gorm:"index" json:"group_id"`
	CreatedBy   uint      `gorm:"index" json:"created_by"`
	Username    string    `json:"username" gofyr:"searchable"`
	CreatedAt   time.Time `json:"created_at" gofyr:"readonly"`
	UpdatedAt   time.Time `json:"updated_at" gofyr:"readonly"`
}
