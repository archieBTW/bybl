package models

import "time"

type SmallGroup struct {
	GroupID         uint      `gorm:"primaryKey" json:"group_id" gofyr:"readonly"`
	ChurchID        uint      `gorm:"index" json:"church_id" gofyr:"label:Church ID"`
	Name            string    `json:"name" gofyr:"searchable,label:Group Name"`
	Description     string    `json:"description" gofyr:"type:textarea"`
	MeetingDay      string    `json:"meeting_day" gofyr:"label:Meeting Day"`
	MeetingTime     string    `json:"meeting_time" gofyr:"label:Meeting Time"`
	MeetingLocation string    `json:"meeting_location" gofyr:"label:Meeting Location"`
	LeaderID        uint      `gorm:"index" json:"leader_id" gofyr:"label:Leader ID"`
	MemberCount     int       `json:"member_count" gofyr:"readonly,label:Member Count"`
	AvatarURL       string    `json:"avatar_url" gofyr:"type:image,disk:local,folder:groups,label:Group Avatar"`
	CreatedAt       time.Time `json:"created_at" gofyr:"readonly"`
	UpdatedAt       time.Time `json:"updated_at" gofyr:"readonly"`
}

type GroupMember struct {
	ID       uint      `gorm:"primaryKey" json:"id" gofyr:"readonly"`
	GroupID  uint      `gorm:"index" json:"group_id" gofyr:"label:Group ID"`
	UserID   uint      `gorm:"index" json:"user_id" gofyr:"label:User ID"`
	Role     string    `json:"role" gofyr:"searchable,label:Role"`
	JoinedAt time.Time `json:"joined_at" gofyr:"readonly"`
}
