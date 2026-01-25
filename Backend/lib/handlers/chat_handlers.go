package handlers

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatRequest struct {
	Messages []ChatMessage `json:"messages"`
}

// Non-streaming Chat Response
func ChatResponse(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req ChatRequest
		if err := c.ShouldBindJSON(&req); err != nil || len(req.Messages) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Missing or invalid messages"})
			return
		}

		if apiKey == "" {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Missing OpenAI API key"})
			return
		}

		payload := map[string]interface{}{
			"model":       "gpt-4o-mini",
			"messages":    req.Messages,
			"temperature": 0.8,
		}

		body, _ := json.Marshal(payload)
		request, _ := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(body))
		request.Header.Set("Authorization", "Bearer "+apiKey)
		request.Header.Set("Content-Type", "application/json")

		resp, err := http.DefaultClient.Do(request)
		if err != nil || resp.StatusCode != 200 {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "OpenAI request failed"})
			return
		}
		defer resp.Body.Close()

		var result map[string]interface{}
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode OpenAI response"})
			return
		}

		content := result["choices"].([]interface{})[0].(map[string]interface{})["message"].(map[string]interface{})["content"].(string)
		c.JSON(http.StatusOK, gin.H{"response": content})
	}
}

// handlers/chat.go  (only the StreamChatResponse function shown)

func StreamChatResponse(apiKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req ChatRequest
		if err := c.ShouldBindJSON(&req); err != nil || len(req.Messages) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Missing or invalid messages"})
			return
		}

		if apiKey == "" {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Missing OpenAI API key"})
			return
		}

		payload := map[string]interface{}{
			"model":       "gpt-4o-mini",
			"messages":    req.Messages,
			"stream":      true,
			"temperature": 0.8,
		}

		body, _ := json.Marshal(payload)
		request, _ := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(body))
		request.Header.Set("Authorization", "Bearer "+apiKey)
		request.Header.Set("Content-Type", "application/json")

		resp, err := http.DefaultClient.Do(request)
		if err != nil || resp.StatusCode != 200 {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to stream from OpenAI"})
			return
		}
		defer resp.Body.Close()

		// ── SSE headers ────────────────────────────────
		c.Writer.Header().Set("Content-Type", "text/event-stream")
		c.Writer.Header().Set("Cache-Control", "no-cache")
		c.Writer.Header().Set("Connection", "keep-alive")
		c.Writer.Flush()

		scanner := bufio.NewScanner(resp.Body)
		for scanner.Scan() {
			line := scanner.Text()
			if !strings.HasPrefix(line, "data: ") {
				continue
			}

			payload := line[6:]
			if payload == "[DONE]" {
				break
			}

			var part struct {
				Choices []struct {
					Delta struct {
						Content string `json:"content"`
					} `json:"delta"`
				} `json:"choices"`
			}
			if err := json.Unmarshal([]byte(payload), &part); err != nil {
				continue
			}
			chunk := part.Choices[0].Delta.Content
			if chunk != "" {
				// send straight text down to Flutter
				fmt.Fprintf(c.Writer, "data: %s\n\n", chunk)
				c.Writer.Flush()
			}
		}
	}
}
