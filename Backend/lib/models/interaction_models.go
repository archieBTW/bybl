package models

import (
	"time"
)

type Like struct {
	LikeID      uint `gorm:"primaryKey" json:"like_id" gofyr:"readonly"`
	UserID      uint `json:"user_id" gofyr:"label:User ID"`
	UserVerseID int  `json:"user_verse_id" gofyr:"label:User Verse ID"`
}

type Comment struct {
	CommentID       uint   `gorm:"primaryKey" json:"comment_id" gofyr:"readonly"`
	Content         string `json:"content" gofyr:"type:textarea,searchable"`
	UserID          uint   `json:"user_id" gofyr:"label:User ID"`
	Username        string `json:"username" gofyr:"searchable,label:Username"`
	UserVerseID     int    `json:"user_verse_id" gofyr:"label:User Verse ID"`
	ParentCommentID *uint  `json:"parent_comment_id" gofyr:"label:Parent Comment ID"`
}

type Notification struct {
	NotificationID uint      `gorm:"primaryKey" json:"notification_id" gofyr:"readonly"`
	UserID         uint      `gorm:"not null" json:"user_id" gofyr:"label:User ID"`
	Content        string    `gorm:"not null" json:"content" gofyr:"searchable"`
	UserVerseID    int       `gorm:"index" json:"user_verse_id" gofyr:"label:User Verse ID"`
	CommentID      *uint     `gorm:"index" json:"comment_id" gofyr:"label:Comment ID"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"created_at" gofyr:"readonly"`
}
