package models

import "time"

type Friend struct {
	ID        uint      `gorm:"primaryKey" json:"id" gofyr:"readonly"` // Primary key for the record
	UserID    uint      `gorm:"index" json:"user_id" gofyr:"label:User ID"`
	FriendID  uint      `gorm:"index" json:"friend_id" gofyr:"label:Friend ID"`
	Status    string    `json:"status" gofyr:"searchable,label:Status"` // e.g., "requested", "accepted", "rejected", ""
	CreatedAt time.Time `json:"created_at" gofyr:"readonly"`
	UpdatedAt time.Time `json:"updated_at" gofyr:"readonly"`
}

type FriendRequestResponse struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
}