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
	Slug               string         `json:"id" gorm:"uniqueIndex" gofyr:"searchable,label:Slug"`
	Title              string         `json:"title" gofyr:"searchable,label:POI Title"`
	Description        string         `json:"description" gofyr:"type:textarea"`
	ImageURL           string         `json:"imageUrl" gofyr:"type:image,disk:local,folder:pois,label:POI Image"`
	Latitude           float64        `json:"latitude" gofyr:"label:Latitude"`
	Longitude          float64        `json:"longitude" gofyr:"label:Longitude"`
	RequiredChapterIDs pq.StringArray `json:"requiredChapterIds" gorm:"type:text[]" gofyr:"label:Required Chapter IDs"`
	UnlockedChapterID  string         `json:"unlockedChapterId" gofyr:"searchable,label:Unlocked Chapter ID"`
	PathPointIndex     int            `json:"pathPointIndex" gofyr:"label:Path Point Index"`
	BibleMapPathID     uint           `json:"bibleMapPathId" gofyr:"label:Path ID"` // Foreign key
}

type BibleMapPath struct {
	gorm.Model
	Slug        string    `json:"id" gorm:"uniqueIndex" gofyr:"searchable,label:Slug"`
	Name        string    `json:"name" gofyr:"searchable,label:Path Name"`
	Description string    `json:"description" gofyr:"type:textarea"`
	Points      PointList `json:"points" gorm:"type:jsonb" gofyr:"type:json,label:Points"`
	POIs        []MapPOI  `json:"pois" gorm:"foreignKey:BibleMapPathID" gofyr:"hidden"`
}
