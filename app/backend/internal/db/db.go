package db

import (
	"context"
	"fmt"
	"time"
	"workup-backend/internal/config"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
)

func NewPool(ctx context.Context, cfg *config.Config) (*pgxpool.Pool, error) {
	connString := fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s",
		cfg.DB.Host, cfg.DB.Port, cfg.DB.Name, cfg.DB.User, cfg.DB.Password,
	)

	poolCfg, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("parsing db config: %w", err)
	}

	poolCfg.MaxConns = 10
	poolCfg.MaxConnIdleTime = 30 * time.Second

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("creating pool: %w", err)
	}

	return pool, nil

}

func CheckConnection(ctx context.Context, pool *pgxpool.Pool, log zerolog.Logger) error {
	var serverTime time.Time

	err := pool.QueryRow(ctx, "SELECT NOW()").Scan(&serverTime)
	if err != nil {
		return fmt.Errorf("querying postgres: %w", err)
	}

	log.Info().Time("serverTime", serverTime).Msg("Postgres connected")
	return nil
}
