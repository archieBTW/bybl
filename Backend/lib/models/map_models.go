package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"

	"github.com/lib/pq"
	"gorm.io/gorm"
)

type Point struct {
	Lat float64 `json:"latitude"`
	Lng float64 `json:"longitude"`
}

type PointList []Point

func (p PointList) Value() (driver.Value, error) {
	return json.Marshal(p)
}

func (p *PointList) Scan(value interface{}) error {
	b, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}
	return json.Unmarshal(b, &p)
}

type MapPOI struct {
	gorm.Model
	Slug               string         `json:"id" gorm:"uniqueIndex"`
	Title              string         `json:"title"`
	Description        string         `json:"description"`
	ImageURL           string         `json:"imageUrl"`
	Latitude           float64        `json:"latitude"`
	Longitude          float64        `json:"longitude"`
	RequiredChapterIDs pq.StringArray `json:"requiredChapterIds" gorm:"type:text[]"`
	UnlockedChapterID  string         `json:"unlockedChapterId"`
	PathPointIndex     int            `json:"pathPointIndex"`
	BibleMapPathID     uint           `json:"bibleMapPathId"` // Foreign key
}

type BibleMapPath struct {
	gorm.Model
	Slug        string    `json:"id" gorm:"uniqueIndex"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Points      PointList `json:"points" gorm:"type:jsonb"`
	POIs        []MapPOI  `json:"pois" gorm:"foreignKey:BibleMapPathID"`
}
