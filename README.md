# Cert Check Exercise

This repo provides a working example of checking the expiration of SSL certificates.

## Basic Usage
The entire environment can be created and torn down via terrraform.

```bash
cd terraform
terraform init
terraform apply
```

This will create a mock environment using docker containers with 1 bastion host, 1 statsd host and 43 servers running a minimal express.js web server. A unique locally signed tls/ssl certificate is generated for each web server and they are assigned expirations as follows:

- (0-10) web servers with ip addresses ending in a number less than 10 certificates will be set with a validity period of 0 hours.
- (11-168) web servers with ip addresses ending in a number between 11 and 168 will use that number as the number of hours the certificate is valid for.
- (168-254) web servers with ip addresses ending in a number between 168 and 254 will be assigned 24 * 365 hours as the validity period.

The bastion host is set up to run cron as PID 1 which executes the checkcerts.sh bash script found in the docker/bastion folder once per minute.  The script will retrieve the ssl certificate from each of the aforementioned web servers and check its end date against these criteria:

1. Was the script able to retrieve the certificate successfully?
2. Is the certificate expired?
3. Is the certificate going to expire in the next 30 days?
4. Is the certificate going to expire before 365 days from the preceeding thursday at midnight (assuming new certs are generated every thusday and are valid for a year, an expiration before this time indicates it was not renewed on schedule).

The script can be observed via the log file of the bastion container.  Additonally the bastion will update the statsd server with the status and send a notification via a slack webhook url.

## Tear Down

To remove all containers and asssociated configuration
```
terraform destroy
```