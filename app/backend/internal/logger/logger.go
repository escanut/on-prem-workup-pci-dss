package logger

import (
	"os"
	"workup-backend/internal/config"

	"github.com/rs/zerolog"
)

func New(cfg *config.Config) zerolog.Logger {

	level := zerolog.InfoLevel

	if cfg.NodeEnv != "production" {
		level = zerolog.DebugLevel
	}

	zerolog.SetGlobalLevel(level)
	return zerolog.New(os.Stdout).With().Timestamp().Logger()

}
