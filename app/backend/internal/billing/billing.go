package billing

import (
	"encoding/json"
	"io"
	"net/http"

	"workup-backend/internal/config"

	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"
	"github.com/stripe/stripe-go/v82"
	"github.com/stripe/stripe-go/v82/checkout/session"
	"github.com/stripe/stripe-go/v82/webhook"
)

type Handler struct {
	cfg *config.Config
	log zerolog.Logger
}

func NewHandler(cfg *config.Config, log zerolog.Logger) *Handler {

	stripe.Key = cfg.Stripe.SecretKey

	return &Handler{cfg: cfg, log: log}
}

func (h *Handler) RegisterRoutes(rg *gin.RouterGroup, requireAuth gin.HandlerFunc) {
	rg.POST("/create-checkout-session", requireAuth, h.createCheckoutSession)
	rg.POST("/webhook", h.handleWebhook)
}

func (h *Handler) createCheckoutSession(c *gin.Context) {
	userSub, _ := c.Get("userSub")
	userEmail, _ := c.Get("userEmail")

	userID, _ := userSub.(string)
	email, _ := userEmail.(string)

	params := &stripe.CheckoutSessionParams{

		UIMode: stripe.String(string(stripe.CheckoutSessionUIModeEmbedded)),
		Mode:   stripe.String(string(stripe.CheckoutSessionModeSubscription)),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				Price:    stripe.String(h.cfg.Stripe.PriceID),
				Quantity: stripe.Int64(1),
			},
		},
		ClientReferenceID: stripe.String(userID),
		CustomerEmail:     stripe.String(email),
		ReturnURL: stripe.String(
			c.Request.Header.Get("Origin") + "/dashboard.html?session_id={CHECKOUT_SESSION_ID}",
		),
	}

	sess, err := session.New(params)
	if err != nil {
		h.log.Error().Err(err).Str("userId", userID).Msg("Failed to create checkout session")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not create checkout session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"clientSecret": sess.ClientSecret})
}

func (h *Handler) handleWebhook(c *gin.Context) {

	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Could not read request body"})
		return
	}

	signature := c.GetHeader("Stripe-Signature")

	event, err := webhook.ConstructEvent(payload, signature, h.cfg.Stripe.WebhookSecret)
	if err != nil {
		h.log.Warn().Err(err).Msg("Webhook signature verification failed")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid signature"})
		return
	}

	switch event.Type {
	case "checkout.session.completed":
		var sess stripe.CheckoutSession
		if err := json.Unmarshal(event.Data.Raw, &sess); err != nil {
			h.log.Error().Err(err).Msg("Failed to parse checkout.session.completed payload")
			break
		}
		h.log.Info().Str("userId", sess.ClientReferenceID).Msg("Checkout completed")

	case "customer.subscription.deleted":
		var sub stripe.Subscription
		if err := json.Unmarshal(event.Data.Raw, &sub); err != nil {
			h.log.Error().Err(err).Msg("Failed to parse customer.subscription.deleted payload")
			break
		}
		h.log.Info().Str("subscriptionId", sub.ID).Msg("Subscription cancelled")

	default:
		h.log.Debug().Str("eventType", string(event.Type)).Msg("Unhandled Stripe event type")
	}

	c.JSON(http.StatusOK, gin.H{"received": true})
}
