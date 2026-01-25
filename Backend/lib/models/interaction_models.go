package models

import (
	"time"
)

type Like struct {
	LikeID      uint `gorm:"primaryKey"`
	UserID      uint
	UserVerseID int
}

type Comment struct {
	CommentID       uint `gorm:"primaryKey"`
	Content         string
	UserID          uint
	Username        string
	UserVerseID     int
	ParentCommentID *uint
}

type Notification struct {
	NotificationID uint      `gorm:"primaryKey"`
	UserID         uint      `gorm:"not null"`
	Content        string    `gorm:"not null"`
	UserVerseID    int       `gorm:"index"`
	CommentID      *uint     `gorm:"index"`
	CreatedAt      time.Time `gorm:"autoCreateTime"`
}
