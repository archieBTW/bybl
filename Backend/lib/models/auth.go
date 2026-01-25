package models

import "github.com/golang-jwt/jwt"

type Claims struct {
	UserID uint `json:"user_id"`
	jwt.StandardClaims
}


