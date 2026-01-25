package models

import "time"

type Friend struct {
	ID        uint   `gorm:"primaryKey"` // Primary key for the record
	UserID    uint   `gorm:"index"`      // ID of the user who initiated the friend request
	FriendID  uint   `gorm:"index"`      // ID of the friend
	Status    string // e.g., "requested", "accepted", "rejected", ""
	CreatedAt time.Time
	UpdatedAt time.Time
}

type FriendRequestResponse struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
}