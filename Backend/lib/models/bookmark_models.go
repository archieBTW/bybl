package models

type Bookmark struct {
	BookmarkID      uint   `gorm:"primaryKey" json:"bookmark_id" gofyr:"readonly"`
	UserID          uint   `json:"user_id" gofyr:"label:User ID"`
	ChapterID       string `json:"chapter_id" gofyr:"searchable,label:Chapter ID"`
	BookName        string `json:"book_name" gofyr:"searchable,label:Book Name"`
	ChapterName     string `json:"chapter_name" gofyr:"searchable,label:Chapter Name"`
	TranslationID   string `json:"translation_id" gofyr:"label:Translation ID"`
	TranslationName string `json:"translation_name" gofyr:"label:Translation Name"`
	BookID          string `json:"book_id" gofyr:"label:Book ID"`
}
