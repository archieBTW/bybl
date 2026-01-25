package models

type UserVerse struct {
	UserVerseID uint `gorm:"primaryKey"`
	VerseID     string
	Content     string
	Verse       string
	UserID      uint
	Note        string
	IsPublished bool `json:"is_published"` // New field added
}

type UserVerseWithMeta struct {
	UserVerseID  uint   `json:"user_verse_id"`
	VerseID      string `json:"verse_id"`
	Content      string `json:"content"`
	Note         string `json:"note"`
	IsPublished  bool   `json:"is_published"`
	UserID       uint   `json:"user_id"`
	LikesCount   int    `json:"likes_count"`
	CommentCount int    `json:"comment_count"`
	Username     string `json:"username"`
}
