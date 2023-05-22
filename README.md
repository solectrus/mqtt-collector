[![Continuous integration](https://github.com/solectrus/mqtt-collector/actions/workflows/push.yml/badge.svg)](https://github.com/solectrus/mqtt-collector/actions/workflows/push.yml)
[![wakatime](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/b31336e5-23f0-408c-ae20-e6bc96b846c9.svg)](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/b31336e5-23f0-408c-ae20-e6bc96b846c9)

# MQTT collector

Collect data from MQTT broker and push it to InfluxDB 2 for use with SOLECTRUS.

**BEWARE:** This project has just started and should be considered experimental. If you encounter any problems, please [open an issue](https://github.com/solectrus/mqtt-collector/issues).

It has been roughly tested in the following setups:

- [ioBroker](https://www.iobroker.net/) with the integrated MQTT broker and the [SENEC Home 2.1 adapter](https://github.com/nobl/ioBroker.senec)
- [evcc](https://evcc.io/) with the [senec-home template](https://github.com/evcc-io/evcc/blob/master/templates/definition/meter/senec-home.yaml) and the [HiveMQ MQTT Broker](https://www.hivemq.com/public-mqtt-broker/)

I'm **very interested** in your feedback, especially if you are using other devices or MQTT brokers. Please [open an issue](https://github.com/solectrus/mqtt-collector/issues) or use the [forum](https://github.com/orgs/solectrus/discussions).

Note: For a SENEC device there is a dedicated [senec-collector](https://github.com/solectrus/senec-collector) available which communicates directly with the SENEC device via its API and does not require a MQTT broker. Also, it is able to collect additional and more accurate data from the SENEC device.

## Requirements

- InfluxDB 2
- MQTT broker
- Linux machine with Docker installed

## Getting started

1. Make sure that your MQTT broker and InfluxDB2 database are ready (not subject of this README)

2. Prepare an `.env` file (see `.env.example`)

3. Run the Docker container on your Linux box:

   ```bash
   docker compose up
   ```

The Docker image support multiple platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

## Build Docker image by yourself

Example for Raspberry Pi:

```bash
docker buildx build --platform linux/arm/v7 -t mqtt-collector .
```

## Development

For development you need a recent Ruby setup. On a Mac, I recommend [rbenv](https://github.com/rbenv/rbenv).

### Run the app

```bash
bundle exec app/main.rb
```

### Run tests

```bash
bundle exec rake
```

### Run linter

```bash
bundle exec rubocop
```

## License

Copyright (c) 2023 Sebastian Löb, released under the MIT License
