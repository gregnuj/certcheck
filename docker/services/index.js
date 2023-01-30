const https = require("https");
const fs = require("fs");
const express = require("express");

// read keys
const key = fs.readFileSync(".ssl/default.key");
const cert = fs.readFileSync(".ssl/default.crt");

// create express app
const app = express();

// create a HTTPS server
const server = https.createServer({ key, cert }, app);

// add test route
app.get("/", (req, res) => {
  res.send("This is a secure server");
});

// get port from env
var port = process.env.HTTPS_PORT || 3000;

// start server on port defined
server.listen(port, () => {
  console.log("listening on " + port);
});