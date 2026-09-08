package auth

import (
	"context"
	"net/http"
	"strings"

	"workup-backend/internal/metrics"

	"github.com/golang-jwt/jwt/v5"

	"github.com/MicahParks/keyfunc/v3"

	"workup-backend/internal/config"

	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"
)

func RequireAuth(cfg *config.Config, log zerolog.Logger) gin.HandlerFunc {
	k, err := keyfunc.NewDefaultCtx(
		context.Background(),
		[]string{cfg.Keycloak.IssuerURL + "/protocol/openid-connect/certs"},
	)

	if err != nil {
		log.Fatal().Err(err).Msg("Failed to initialize JWKS client")
	}

	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")

		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {

			log.Warn().
				Str("path", c.Request.URL.Path).
				Str("ip", c.ClientIP()).
				Msg("Auth rejected: missing or malformed Authorization header")

			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Missing or malformed Authorization header",
			})
			metrics.RecordAuthRejection("missing_header")
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		token, err := jwt.Parse(
			tokenString,
			k.Keyfunc,
			jwt.WithIssuer(cfg.Keycloak.IssuerURL),
			jwt.WithAudience(cfg.Keycloak.Audience),
			jwt.WithValidMethods([]string{"RS256"}),
		)

		if err != nil || !token.Valid {
			log.Warn().
				Str("path", c.Request.URL.Path).
				Str("ip", c.ClientIP()).
				AnErr("reason", err).
				Msg("Auth rejected: invalid or expired token")

			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid or expired token",
			})
			metrics.RecordAuthRejection("invalid_token")
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid token claims",
			})
			return
			metrics.RecordAuthRejection("invalid_token claims")
		}

		c.Set("userSub", claims["sub"])
		c.Set("userEmail", claims["email"])

		c.Next()

	}

}
