package main

import (
	"context"

	"github.com/gin-contrib/logger"
	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"

	"workup-backend/internal/auth"
	"workup-backend/internal/billing"
	"workup-backend/internal/config"
	applog "workup-backend/internal/logger"

	dbpkg "workup-backend/internal/db"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		panic(err)
	}

	log := applog.New(cfg)

	ctx := context.Background()

	pool, err := dbpkg.NewPool(ctx, cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to create Postgres pool")
	}
	defer pool.Close()

	if err := dbpkg.CheckConnection(ctx, pool, log); err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to Postgres on startup")

	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(logger.SetLogger(
		logger.WithLogger(func(_ *gin.Context, _ zerolog.Logger) zerolog.Logger {
			return log // Use *log if applog.New(cfg) returns a pointer (*zerolog.Logger)
		}),
	))

	router.Use(func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		for _, allowed := range cfg.CORSOrigins {
			if origin == allowed {
				c.Header("Access-Control-Allow-Origin", origin)
				c.Header("Access-Control-Allow-Credentials", "true")
				c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
				c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")
				break
			}
		}
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	requireAuth := auth.RequireAuth(cfg, log)

	billingHandler := billing.NewHandler(cfg, log)

	billingGroup := router.Group("/billing")
	billingHandler.RegisterRoutes(billingGroup, requireAuth)

	log.Info().Str("port", cfg.Port).Str("env", cfg.NodeEnv).Msg("WorkUp backend listening")

	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatal().Err(err).Msg("Server failed")
	}
}
