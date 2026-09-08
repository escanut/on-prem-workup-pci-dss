package metrics

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "workup_http_request_duration_seconds",
		Help: "Duration of HTTP requests",
	}, []string{"path", "method", "status"})

	authRejections = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "workup_auth_rejections_total",
		Help: "Count of rejected auth attempts, by reason",
	}, []string{"reason"})
)

func Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next() // run the rest of the handlers

		path := c.FullPath()
		if path == "" {
			path = "unmatched"
		}

		httpDuration.WithLabelValues(
			path,
			c.Request.Method,
			strconv.Itoa(c.Writer.Status()),
		).Observe(time.Since(start).Seconds())
	}
}

// called from auth
func RecordAuthRejection(reason string) {
	authRejections.WithLabelValues(reason).Inc()
}

func Handler() gin.HandlerFunc {
	h := promhttp.Handler()
	return func(c *gin.Context) { h.ServeHTTP(c.Writer, c.Request) }
}
