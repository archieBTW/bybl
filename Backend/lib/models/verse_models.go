package models

type UserVerse struct {
	UserVerseID uint   `gorm:"primaryKey" json:"user_verse_id" gofyr:"readonly"`
	VerseID     string `json:"verse_id" gofyr:"searchable,label:Verse Ref"`
	Content     string `json:"content" gofyr:"type:textarea,searchable"`
	Verse       string `json:"verse" gofyr:"searchable,label:Verse Text"`
	UserID      uint   `json:"user_id" gofyr:"label:User ID"`
	Note        string `json:"note" gofyr:"type:textarea"`
	IsPublished bool   `json:"is_published" gofyr:"label:Published"`
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
