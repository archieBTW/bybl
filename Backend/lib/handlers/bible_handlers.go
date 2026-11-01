package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type bibleCacheEntry struct {
	data      []byte
	expiresAt time.Time
}

var (
	bibleCacheMu   sync.RWMutex
	bibleCacheData = make(map[string]bibleCacheEntry)
	bibleCacheKeys []string
)

const (
	maxBibleCacheEntries = 2000
	bibleCacheTTL        = 24 * time.Hour
)

func getBibleCache(key string) ([]byte, bool) {
	bibleCacheMu.RLock()
	entry, ok := bibleCacheData[key]
	bibleCacheMu.RUnlock()
	if !ok || time.Now().After(entry.expiresAt) {
		return nil, false
	}
	return entry.data, true
}

func setBibleCache(key string, data []byte) {
	bibleCacheMu.Lock()
	defer bibleCacheMu.Unlock()

	if _, exists := bibleCacheData[key]; !exists {
		if len(bibleCacheKeys) >= maxBibleCacheEntries {
			evictKey := bibleCacheKeys[0]
			bibleCacheKeys = bibleCacheKeys[1:]
			delete(bibleCacheData, evictKey)
		}
		bibleCacheKeys = append(bibleCacheKeys, key)
	}

	bibleCacheData[key] = bibleCacheEntry{
		data:      data,
		expiresAt: time.Now().Add(bibleCacheTTL),
	}
}

func GetBibleTranslations(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if apiKey == "" {
			log.Println("Missing BIBLE_KEY")
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Missing BIBLE_KEY"})
			return
		}

		cacheKey := "translations"
		if cached, ok := getBibleCache(cacheKey); ok {
			c.Header("Cache-Control", "public, max-age=86400")
			c.Data(http.StatusOK, "application/json; charset=utf-8", cached)
			return
		}

		req, _ := http.NewRequest("GET", "https://rest.api.bible/v1/bibles", nil)
		req.Header.Set("api-key", apiKey)

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			log.Printf("HTTP request error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reach Scripture API"})
			return
		}
		defer resp.Body.Close()

		body, _ := io.ReadAll(resp.Body)

		if resp.StatusCode != 200 {
			log.Printf("Scripture API returned %d: %s", resp.StatusCode, string(body))
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":   "Failed to fetch translations",
				"details": string(body),
			})
			return
		}

		var result map[string]interface{}
		if err := json.Unmarshal(body, &result); err != nil {
			log.Printf("JSON decode error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse API response"})
			return
		}

		_, ok := result["data"].([]interface{})
		if !ok {
			log.Printf("Unexpected format from Scripture API: %s", string(body))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid response format"})
			return
		}

		setBibleCache(cacheKey, body)
		c.Header("Cache-Control", "public, max-age=86400")
		c.Data(http.StatusOK, "application/json; charset=utf-8", body)
	}
}

func GetBibleBooks(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		bibleId := c.Param("bibleId")
		cacheKey := fmt.Sprintf("books:%s", bibleId)

		if cached, ok := getBibleCache(cacheKey); ok {
			c.Header("Cache-Control", "public, max-age=86400")
			c.Data(http.StatusOK, "application/json; charset=utf-8", cached)
			return
		}

		url := fmt.Sprintf("https://rest.api.bible/v1/bibles/%s/books", bibleId)
		req, _ := http.NewRequest("GET", url, nil)
		req.Header.Set("api-key", apiKey)

		resp, err := http.DefaultClient.Do(req)
		if err != nil || resp.StatusCode != 200 {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch books"})
			return
		}
		defer resp.Body.Close()

		body, _ := io.ReadAll(resp.Body)
		var result map[string]interface{}
		if err := json.Unmarshal(body, &result); err == nil {
			setBibleCache(cacheKey, body)
		}

		c.Header("Cache-Control", "public, max-age=86400")
		c.Data(http.StatusOK, "application/json; charset=utf-8", body)
	}
}

func GetBibleChapters(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		bibleId := c.Param("bibleId")
		bookId := c.Param("bookId")
		cacheKey := fmt.Sprintf("chapters:%s:%s", bibleId, bookId)

		if cached, ok := getBibleCache(cacheKey); ok {
			c.Header("Cache-Control", "public, max-age=86400")
			c.Data(http.StatusOK, "application/json; charset=utf-8", cached)
			return
		}

		url := fmt.Sprintf("https://rest.api.bible/v1/bibles/%s/books/%s/chapters", bibleId, bookId)
		req, _ := http.NewRequest("GET", url, nil)
		req.Header.Set("api-key", apiKey)

		resp, err := http.DefaultClient.Do(req)
		if err != nil || resp.StatusCode != 200 {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch chapters"})
			return
		}
		defer resp.Body.Close()

		body, _ := io.ReadAll(resp.Body)
		var result map[string]interface{}
		if err := json.Unmarshal(body, &result); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse chapters"})
			return
		}

		// Filter out "intro" chapters
		if data, ok := result["data"].([]interface{}); ok {
			filtered := []interface{}{}
			for _, ch := range data {
				if chMap, ok := ch.(map[string]interface{}); ok && chMap["number"] != "intro" {
					filtered = append(filtered, chMap)
				}
			}
			result["data"] = filtered
		}

		encoded, err := json.Marshal(result)
		if err == nil {
			setBibleCache(cacheKey, encoded)
			c.Header("Cache-Control", "public, max-age=86400")
			c.Data(http.StatusOK, "application/json; charset=utf-8", encoded)
			return
		}

		c.JSON(http.StatusOK, result)
	}
}

var esvBookMap = map[string]string{
	"RUT": "Ruth",
	"NAH": "Nahum",
	"NAM": "Nahum",
	// add more only if you discover they fail
}

func normaliseESV(ref string) string {
	parts := strings.Split(ref, ".")  // ["NAH", "1"]
	usfm := strings.ToUpper(parts[0]) // "NAH"
	if full, ok := esvBookMap[usfm]; ok {
		parts[0] = full // "Nahum"
	}
	return strings.Join(parts, " ") // "Nahum 1"
}

func GetBiblePassage(apiKey string, esvKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		translationId := c.Param("translationId")
		reference := c.Query("q")
		cacheKey := fmt.Sprintf("passage:%s:%s", translationId, reference)

		if cached, ok := getBibleCache(cacheKey); ok {
			c.Header("Cache-Control", "public, max-age=86400")
			c.Data(http.StatusOK, "application/json; charset=utf-8", cached)
			return
		}

		if translationId == "ESV" {
			esvRef := normaliseESV(reference)

			req, _ := http.NewRequest(
				"GET",
				"https://api.esv.org/v3/passage/text/?q="+url.QueryEscape(esvRef)+
					"&include-verse-numbers=true&include-footnotes=false&include-footnote-body=false"+
					"&include-headings=false&include-short-copyright=true",
				nil)
			req.Header.Set("Authorization", "Token "+esvKey)

			resp, err := http.DefaultClient.Do(req)
			if err != nil || resp.StatusCode != 200 {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch ESV passage"})
				return
			}
			defer resp.Body.Close()

			body, _ := io.ReadAll(resp.Body)
			var result map[string]interface{}
			json.Unmarshal(body, &result)

			passage := ""
			if passages, ok := result["passages"].([]interface{}); ok && len(passages) > 0 {
				passage = passages[0].(string)
			}

			refDot := strings.ReplaceAll(reference, " ", ".") + "."

			// NEW regex: [12]   (with or without white-space)
			re := regexp.MustCompile(`\[\s*(\d+)\s*]`)
			locs := re.FindAllStringSubmatchIndex(passage, -1)

			var verses []map[string]interface{}
			for i, loc := range locs {
				verseNum := passage[loc[2]:loc[3]] // capture “12”
				startTxt := loc[1]                 // char after “]”
				endTxt := len(passage)
				if i+1 < len(locs) {
					endTxt = locs[i+1][0]
				}

				verseText := strings.TrimSpace(passage[startTxt:endTxt])
				if verseText == "" {
					continue
				}

				verses = append(verses, map[string]interface{}{
					"name": "verse",
					"attrs": map[string]interface{}{
						"sid": fmt.Sprintf("%s%s", refDot, verseNum), // LEV.3.12
					},
					"items": []map[string]interface{}{
						{"type": "text", "text": verseText},
					},
				})
			}

			// wrap like Scripture API
			structured := []map[string]interface{}{
				{"name": "para", "items": verses},
			}

			payload := gin.H{"data": map[string]interface{}{"content": structured}}
			if encoded, err := json.Marshal(payload); err == nil {
				setBibleCache(cacheKey, encoded)
			}
			c.Header("Cache-Control", "public, max-age=86400")
			c.JSON(http.StatusOK, payload)
			return
		}

		// Non-ESV (scripture.api.bible)
		url := fmt.Sprintf("https://rest.api.bible/v1/bibles/%s/chapters/%s?content-type=json&include-notes=false&include-titles=false&include-chapter-numbers=false&include-verse-numbers=true", translationId, reference)
		req, _ := http.NewRequest("GET", url, nil)
		req.Header.Set("api-key", apiKey)

		resp, err := http.DefaultClient.Do(req)
		if err != nil || resp.StatusCode != 200 {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch structured chapter"})
			return
		}
		defer resp.Body.Close()

		body, _ := io.ReadAll(resp.Body)
		var result map[string]interface{}
		if err := json.Unmarshal(body, &result); err != nil {
			log.Printf("Error parsing Scripture JSON: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse JSON"})
			return
		}

		setBibleCache(cacheKey, body)
		c.Header("Cache-Control", "public, max-age=86400")
		c.Data(http.StatusOK, "application/json; charset=utf-8", body)
	}
}
