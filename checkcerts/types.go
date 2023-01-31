package main

import (
	"reflect"
	"strings"
)

// ips.json file struct.
type IpsJSON struct {
	Europa   []string `json:"europa"`
	Callisto []string `json:"callisto"`
}

// process json struct to list of type hosts.
func (j *IpsJSON) getList() (hosts []*Host) {
	hosts = []*Host{}

	t := reflect.ValueOf(j).Elem()
    for i := 0; i < t.NumField(); i++ {
		service := t.Type().Field(i).Name
		list, _ := t.Field(i).Interface().([]string)
		for _, ipv4 := range list {
			h := &Host{
				service: service,
				ipv4: ipv4,
			}
			hosts = append(hosts, h)
		}
    }
	return hosts
}

// host type to use to process certs.
type Host struct {
	service string
	ipv4 string
}

// create name from service/ip.
func (j *Host) getName() string {
	return strings.Join([]string{strings.ToLower(j.service), strings.ReplaceAll(j.ipv4, ".", "-")}, "-")
} 

// convenience function to return ipv4
func (j *Host) getIpv4() string {
	return j.ipv4
}

// determine port used from service name
func (j *Host) getPort() string {
	if j.service == "Europa" {
		return "4000"
	}
	return "8000"
}

// string to pass to tcp.dial
func (j *Host) getIpPort() string {
	return strings.Join([]string{j.getIpv4(), j.getPort()}, ":")
} 
