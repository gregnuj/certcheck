package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"time"
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/sirupsen/logrus"
)

var (
	logger *logrus.Logger
	webHookUrl string
	statsdServer string
)

const (
	flagIpsJSONFile = "ips"
	flagSlackWebhook = "slack"
	flagStatsdServer = "statsd"
)

//nolint:gochecknoinits
func init() {
	logger = logrus.New()
	Formatter := new(logrus.TextFormatter)
	Formatter.TimestampFormat = "2006-01-02 15:04:05"
	Formatter.FullTimestamp = true
	Formatter.ForceColors = true
	logger.SetFormatter(Formatter)
	logger.SetLevel(logrus.InfoLevel)
}

func main() {
	ctx := context.Background()

	err := New().ExecuteContext(ctx)

	if ctx.Err() == context.Canceled || err == context.Canceled {
		fmt.Println("aborted")
		return
	}

	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

// Cobra root command.
func New() *cobra.Command {
	cobra.EnableCommandSorting = false

	c := &cobra.Command{
		Use:   "checkcerts",
		Short: "checkcerts checks the validity of ssl certificates",
		RunE:  CertCheckHandler,
	}
	c.Flags().StringP(flagIpsJSONFile, "i", "", "json file with ip list")
	c.Flags().StringVarP(&webHookUrl, flagSlackWebhook, "w", "", "slack webhook url")
	c.Flags().StringVarP(&statsdServer, flagStatsdServer, "s", "", "statsd server")
	c.MarkFlagRequired(flagIpsJSONFile)

	return c
}

// Primary app logic here.
func CertCheckHandler(cmd *cobra.Command, args []string) error {
	ipsJSONFile, err := cmd.Flags().GetString(flagIpsJSONFile)
	if err != nil {
		return err
	}

	ips, err := getIpsJSON(ipsJSONFile)
	if err != nil {
		return err
	}

	for _, h := range ips.getList() {
		err := processHost(h)
		if err != nil {
			return err
		}
	}

	return nil

}

// Process an individual host.
func processHost(h *Host) error {
	certs, err := getCerts(h.getIpPort())
	if err != nil {
		return err
	}
	for _, cert := range certs {
		err = processCert(h, cert)
		if err != nil {
			return err
		}
	}
	return nil
}

// Process an individual cert.
func processCert(h *Host, cert *x509.Certificate) error {
	switch {
	case cert.NotAfter.Before(time.Now()):
		onExpired(h)
	case cert.NotAfter.Before(time.Now().AddDate(0,0,30)):
		onExpiring(h)
	case cert.NotAfter.Before(lastThursday().AddDate(1,0,0)):
		onReissue(h)
	default:
		logger.Infof("%s: cert is okay\n", h.getName())
	}
	return nil
}

// Retrieve certificate(s) for specific ip/port combo.
func getCerts(ipPort string) (certs []*x509.Certificate, er error) {
    conf := &tls.Config{
        InsecureSkipVerify: true,
    }

	conn, err := tls.Dial("tcp", ipPort, conf)
	if err != nil {
		return certs, err
	}
	defer conn.Close()

	certs = conn.ConnectionState().PeerCertificates

	return certs, nil
}

// Parse file to ipsJSON struct.
func getIpsJSON(ipsJSONFile string) (ips *IpsJSON, err error) {
	fileBytes, err := os.ReadFile(ipsJSONFile)
	if errors.Is(err, os.ErrNotExist) {
		logger.Errorf("%s is not a file or does not exist", ipsJSONFile)
		return ips, err
	} else if err != nil {
		return ips, err
	}
	ips = &IpsJSON{}

	err = json.Unmarshal(fileBytes, ips)
	if err != nil {
		return ips, err
	}

	return ips, err
}