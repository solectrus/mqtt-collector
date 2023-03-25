# MQTT-collector for Solectrus
Collect data from MQTT topics and push it to InfluxDB 2

Tested with MQTT broker on ioBroker and Solectrus.

## Prerequisites
1. MQTT broker publishing solar data
2. Linux system running docker

## How-to use
1. Make sure your solar data is published via MQTT
2. Make sure your InfluxDB2 database is ready (not subject of this README)
3. Prepare an `.env` file (see `.env.example`) 
4. Run the docker container

# Credits
Inspired by https://github.com/solectrus/senec-collector

# License
Copyright (c) 2023 Sebastian Löb, released under the MIT License