package config

import (
	"fmt"
	"os"
	"strings"
)

type Config struct {
	Port        string
	NodeEnv     string
	Keycloak    KeycLoakConfig
	Stripe      StripeConfig
	DB          DBConfig
	CORSOrigins []string
}

type KeycLoakConfig struct {
	IssuerURL string
	Audience  string
}

type StripeConfig struct {
	SecretKey     string
	WebhookSecret string
	PriceID       string
}

type DBConfig struct {
	Host     string
	Port     string
	Name     string
	User     string
	Password string
}

func Load() (*Config, error) {
	cfg := &Config{
		Port:    getEnvOrDefault("PORT", "8080"),
		NodeEnv: getEnvOrDefault("NODE_ENV", "development"),

		Keycloak: KeycLoakConfig{
			IssuerURL: os.Getenv("KEYCLOAK_ISSUER_URL"),
			Audience:  getEnvOrDefault("KEYCLOAK_CLIENT_ID", "workup-frontend"),
		},

		Stripe: StripeConfig{
			SecretKey:     os.Getenv("STRIPE_SECRET_KEY"),
			WebhookSecret: os.Getenv("STRIPE_WEBHOOK_SECRET"),
			PriceID:       os.Getenv("STRIPE_PRICE_ID"),
		},

		DB: DBConfig{
			Host:     getEnvOrDefault("DB_HOST", "postgres"),
			Port:     getEnvOrDefault("DB_PORT", "5432"),
			Name:     getEnvOrDefault("DB_NAME", "workup"),
			User:     os.Getenv("DB_USERNAME"),
			Password: os.Getenv("DB_PASSWORD"),
		},

		CORSOrigins: strings.Split(
			getEnvOrDefault("CORS_ORIGINS", "https://www.victorojeje.xyz"),
			",",
		),
	}

	if cfg.Keycloak.IssuerURL == "" {
		return nil, fmt.Errorf("KEYCLOAK_ISSUER_URL is required")
	}

	if cfg.DB.User == "" || cfg.DB.Password == "" {
		return nil, fmt.Errorf("DB_USER and DB_PASSWORD are required")
	}

	return cfg, nil
}

func getEnvOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
