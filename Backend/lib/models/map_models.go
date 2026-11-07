package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"strings"

	"gorm.io/gorm"
)

type Point struct {
	Lat float64 `json:"latitude"`
	Lng float64 `json:"longitude"`
}

type PointList []Point

func (p PointList) Value() (driver.Value, error) {
	if p == nil {
		return "[]", nil
	}
	b, err := json.Marshal(p)
	if err != nil {
		return nil, err
	}
	return string(b), nil
}

func (p *PointList) Scan(value interface{}) error {
	if value == nil {
		*p = PointList{}
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return fmt.Errorf("PointList.Scan: unsupported type %T", value)
	}
	trimmed := strings.TrimSpace(string(bytes))
	if trimmed == "" || trimmed == "null" {
		*p = PointList{}
		return nil
	}
	return json.Unmarshal([]byte(trimmed), p)
}

// StringList stores a slice of strings as JSON text in both SQLite and PostgreSQL,
// while also accepting legacy Postgres array literals (e.g. {"EXO.12","EXO.13"})
// or comma-separated strings if edited manually in gofyrAdmin.
type StringList []string

func (s StringList) Value() (driver.Value, error) {
	if s == nil {
		return "[]", nil
	}
	b, err := json.Marshal(s)
	if err != nil {
		return nil, err
	}
	return string(b), nil
}

func (s *StringList) Scan(value interface{}) error {
	if value == nil {
		*s = StringList{}
		return nil
	}
	var raw string
	switch v := value.(type) {
	case []byte:
		raw = string(v)
	case string:
		raw = v
	default:
		return fmt.Errorf("StringList.Scan: unsupported type %T", value)
	}

	trimmed := strings.TrimSpace(raw)
	if trimmed == "" || trimmed == "null" || trimmed == "{}" || trimmed == "[]" {
		*s = StringList{}
		return nil
	}

	// 1. Standard JSON array: ["EXO.12", "EXO.13"]
	if strings.HasPrefix(trimmed, "[") {
		var parsed []string
		if err := json.Unmarshal([]byte(trimmed), &parsed); err == nil {
			*s = parsed
			return nil
		}
	}

	// 2. Legacy Postgres array literal: {"EXO.12","EXO.13"}
	if strings.HasPrefix(trimmed, "{") && strings.HasSuffix(trimmed, "}") {
		inner := strings.TrimSuffix(strings.TrimPrefix(trimmed, "{"), "}")
		if strings.TrimSpace(inner) == "" {
			*s = StringList{}
			return nil
		}
		parts := strings.Split(inner, ",")
		out := make([]string, 0, len(parts))
		for _, part := range parts {
			clean := strings.Trim(strings.TrimSpace(part), `"`)
			if clean != "" {
				out = append(out, clean)
			}
		}
		*s = out
		return nil
	}

	// 3. Fallback: comma-separated string: "EXO.12, EXO.13"
	parts := strings.Split(trimmed, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		clean := strings.TrimSpace(part)
		if clean != "" {
			out = append(out, clean)
		}
	}
	*s = out
	return nil
}

type MapPOI struct {
	gorm.Model
	Slug               string     `json:"id" gorm:"uniqueIndex" gofyr:"searchable,label:Slug"`
	Title              string     `json:"title" gofyr:"searchable,label:POI Title"`
	Description        string     `json:"description" gofyr:"type:textarea,label:Description"`
	ImageURL           string     `json:"imageUrl" gofyr:"type:image,disk:local,folder:pois,label:POI Image"`
	Latitude           float64    `json:"latitude" gofyr:"label:Latitude"`
	Longitude          float64    `json:"longitude" gofyr:"label:Longitude"`
	RequiredChapterIDs StringList `json:"requiredChapterIds" gorm:"type:text" gofyr:"type:json,label:Required Chapter IDs"`
	UnlockedChapterID  string     `json:"unlockedChapterId" gofyr:"searchable,label:Unlocked Chapter ID"`
	PathPointIndex     int        `json:"pathPointIndex" gofyr:"label:Path Point Index"`
	BibleMapPathID     uint       `json:"bibleMapPathId" gofyr:"label:Path ID"` // Foreign key
}

type BibleMapPath struct {
	gorm.Model
	Slug        string    `json:"id" gorm:"uniqueIndex" gofyr:"searchable,label:Slug"`
	Name        string    `json:"name" gofyr:"searchable,label:Path Name"`
	Description string    `json:"description" gofyr:"type:textarea,label:Description"`
	Points      PointList `json:"points" gorm:"type:text" gofyr:"type:json,label:Points"`
	POIs        []MapPOI  `json:"pois" gorm:"foreignKey:BibleMapPathID" gofyr:"hidden"`
}
