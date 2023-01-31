package main

import (
	"fmt"
	"time"
	"github.com/ashwanthkumar/slack-go-webhook"
	"github.com/cactus/go-statsd-client/v5/statsd"
)

// Get midnight today.
func midnight() time.Time {
	t0 := time.Now()
	return time.Date(t0.Year(), t0.Month(), t0.Day(), 0, 0, 0, 0, t0.Location())
}

// Get midnight last thursday.
func lastThursday() time.Time {
	today := midnight()
	weekday := today.Weekday()
	offset := int(weekday + time.Wednesday) * -1
	return today.AddDate(0, 0, offset)
}

func onReissue(h *Host){
	sendStatsd(fmt.Sprintf("certs.%s.outdated", h.getName()))
    msg := fmt.Sprintf("%s ssl certificate has not been reissued in the last 7 days", h.getName())
	logger.Error(msg)
	postSlack(msg)
}

func onExpiring(h *Host){
    msg := fmt.Sprintf("%s ssl certificate is expiring with the next 30 days", h.getName())
	logger.Error(msg)
	postSlack(msg)
	sendStatsd(fmt.Sprintf("certs.%s.expiring", h.getName()))
}

func onExpired(h *Host){
    msg := fmt.Sprintf("%s ssl certificate has expired", h.getName())
	logger.Error(msg)
	postSlack(msg)
	sendStatsd(fmt.Sprintf("certs.%s.expired", h.getName()))
}

func postSlack(msg string) {
	if webHookUrl != "" {
		payload := slack.Payload {
		Text: msg,
		Username: "robot",
		Channel: "#general",
		}
		err := slack.Send(webHookUrl, "", payload)
		if err != nil {
			logger.Error(err)
		}
	}
}

func sendStatsd(stat string) {
	if statsdServer != "" {
		client, err := statsd.NewClient(statsdServer, "client")
		if err != nil {
			logger.Error(err)
		}
		defer client.Close()

		client.Gauge("stat1", 1, 1.0)
	}
}