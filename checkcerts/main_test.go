package main

import (
	"encoding/json"
	"os"
	"testing"

	_ "github.com/davecgh/go-spew/spew"
	"github.com/stretchr/testify/require"
)

var testIps = &IpsJSON{
	Europa: [](string){
		"10.10.6.104",
		"10.10.6.11",
	},
	Callisto: []string{
		"10.10.8.11",
		"10.10.8.127",
		"10.10.8.128",
	},
}

func TestGetIpsJson(t *testing.T) {
	file, err := os.CreateTemp("", "testjson")
	require.NoError(t, err)
	defer os.Remove(file.Name())

	bytes, err := json.Marshal(testIps)
	require.NoError(t, err)

	_, err = file.Write(bytes)
	require.NoError(t, err)

	err = file.Close()
	require.NoError(t, err)

	ips, err := getIpsJSON(file.Name())

	ips.getList()
	
	require.NoError(t, err)
	require.Equal(t, ips, testIps)
}

func TestGetCerts(t *testing.T) {
	certs, err := getCerts("www.google.com:443")
	require.NoError(t, err)

	require.Equal(t, certs[0].BasicConstraintsValid, true)
}
