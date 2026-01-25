package models

type Bookmark struct {
	BookmarkID      uint   `gorm:"primaryKey" json:"bookmark_id"`
	UserID          uint   `json:"user_id"`
	ChapterID       string `json:"chapter_id"`
	BookName        string `json:"book_name"`
	ChapterName     string `json:"chapter_name"`
	TranslationID   string `json:"translation_id"`
	TranslationName string `json:"translation_name"`
	BookID          string `json:"book_id"`
}
