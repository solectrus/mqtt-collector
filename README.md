[![Continuous integration](https://github.com/solectrus/mqtt-collector/actions/workflows/push.yml/badge.svg)](https://github.com/solectrus/mqtt-collector/actions/workflows/push.yml)
[![Maintainability](https://qlty.sh/gh/solectrus/projects/mqtt-collector/maintainability.svg)](https://qlty.sh/gh/solectrus/projects/mqtt-collector)
[![wakatime](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/233968fc-9ac5-4c50-952f-ec1a37b3df85.svg)](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/233968fc-9ac5-4c50-952f-ec1a37b3df85)
[![Code Coverage](https://qlty.sh/gh/solectrus/projects/mqtt-collector/coverage.svg)](https://qlty.sh/gh/solectrus/projects/mqtt-collector)

# MQTT collector

Collect data from MQTT broker and push it to InfluxDB 2. The mappings of MQTT topics to InfluxDB fields and measurements is customizable.

The main use case is to collect data for SOLECTRUS, but it can be used for other purposes as well, where you want to collect data from MQTT and store it in InfluxDB.

It has been tested in the following setups:

- [ioBroker](https://www.iobroker.net/) with the integrated MQTT broker and the [SENEC Home 2.1 adapter](https://github.com/nobl/ioBroker.senec)
- [evcc](https://evcc.io/) with the [senec-home template](https://github.com/evcc-io/evcc/blob/master/templates/definition/meter/senec-home.yaml) and the [HiveMQ MQTT Broker](https://www.hivemq.com/public-mqtt-broker/)

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

The Docker image supports multiple platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

## Resilience against InfluxDB outages

On startup, the collector waits (up to 12 seconds) for InfluxDB to become reachable before it starts subscribing to MQTT.

While running, incoming MQTT messages are always received and converted immediately - they're never blocked by a slow or unreachable InfluxDB. Instead, they're queued in memory and written by a separate background process. If a write fails (e.g. because InfluxDB is temporarily unreachable), the batch stays queued and is retried automatically every 5 seconds, keeping its original measurement time - so once InfluxDB is reachable again, the backlog is delivered with the timestamps of when the values actually arrived, not when they were finally written.

A batch that InfluxDB refuses outright is dropped instead of retried, because sending it again would produce the same answer. This applies to a broken line protocol (HTTP 400) and to a field that doesn't match the type it already has in InfluxDB (HTTP 422). Both are named in the log.

The queue holds at most 100,000 batches - more than a day at one message per second. Beyond that, the oldest batch makes room for the newest one, so a very long outage costs the beginning of the backlog instead of the whole container.

On shutdown (`docker stop` or Ctrl-C), the collector stops receiving MQTT messages first and then gives the queue up to 5 seconds to reach InfluxDB. That limit stays below the 10 seconds Docker allows before it kills the container. If InfluxDB is still unreachable when the time is up, the log says how many batches were lost.

Note: this in-memory queue is lost if the container is restarted while InfluxDB is still unreachable.

## Development

For development you need a recent Ruby setup. On a Mac, I recommend [rbenv](https://github.com/rbenv/rbenv).

### Run the app

```bash
bundle exec app.rb
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

Copyright (c) 2023-2026 Georg Ledermann <georg@ledermann.dev> and contributors.\
Inspired by code provided by Sebastian Löb (@loebse) and Michael Heß (@GrimmiMeloni)
