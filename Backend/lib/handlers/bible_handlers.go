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

	"github.com/gin-gonic/gin"
)

func GetBibleTranslations(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if apiKey == "" {
			log.Println("Missing BIBLE_KEY")
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Missing BIBLE_KEY"})
			return
		}

		req, _ := http.NewRequest("GET", "https://api.scripture.api.bible/v1/bibles", nil)
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

		dataRaw, ok := result["data"].([]interface{})
		if !ok {
			log.Printf("Unexpected format from Scripture API: %s", string(body))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid response format"})
			return
		}

		dataRaw = append(dataRaw, map[string]interface{}{
			"id":   "ESV",
			"name": "English Standard Version",
		})
		result["data"] = dataRaw

		c.JSON(http.StatusOK, result)
	}
}

func GetBibleBooks(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		bibleId := c.Param("bibleId")

		url := fmt.Sprintf("https://api.scripture.api.bible/v1/bibles/%s/books", bibleId)
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
		json.Unmarshal(body, &result)

		c.JSON(http.StatusOK, result)
	}
}

func GetBibleChapters(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		bibleId := c.Param("bibleId")
		bookId := c.Param("bookId")

		url := fmt.Sprintf("https://api.scripture.api.bible/v1/bibles/%s/books/%s/chapters", bibleId, bookId)
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
		json.Unmarshal(body, &result)

		// Filter out "intro" chapters
		data := result["data"].([]interface{})
		filtered := []interface{}{}
		for _, ch := range data {
			chMap := ch.(map[string]interface{})
			if chMap["number"] != "intro" {
				filtered = append(filtered, chMap)
			}
		}
		result["data"] = filtered

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

			c.JSON(http.StatusOK, gin.H{"data": map[string]interface{}{"content": structured}})
			return
		}

		// Non-ESV (scripture.api.bible)
		url := fmt.Sprintf("https://api.scripture.api.bible/v1/bibles/%s/chapters/%s?content-type=json&include-notes=false&include-titles=false&include-chapter-numbers=false&include-verse-numbers=true", translationId, reference)
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

		// Just forward it exactly as-is
		c.JSON(http.StatusOK, result)
	}
}
