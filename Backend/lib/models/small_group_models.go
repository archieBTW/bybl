package models

import "time"

type SmallGroup struct {
	GroupID         uint      `gorm:"primaryKey" json:"group_id"`
	ChurchID        uint      `gorm:"index" json:"church_id"`
	Name            string    `json:"name"`
	Description     string    `json:"description"`
	MeetingDay      string    `json:"meeting_day"`
	MeetingTime     string    `json:"meeting_time"`
	MeetingLocation string    `json:"meeting_location"`
	LeaderID        uint      `gorm:"index" json:"leader_id"`
	MemberCount     int       `json:"member_count"`
	AvatarURL       string    `json:"avatar_url"` // 🆕 <- ADD THIS
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type GroupMember struct {
	ID       uint      `gorm:"primaryKey" json:"id"`
	GroupID  uint      `gorm:"index" json:"group_id"`
	UserID   uint      `gorm:"index" json:"user_id"`
	Role     string    `json:"role"` // e.g., "member", "leader"
	JoinedAt time.Time `json:"joined_at"`
}
