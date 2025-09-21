# Plasma Non-Validator Templates

This repository contains templates and examples for setting up a Plasma non-validator node.

The repo is organized by network, with different ways to run the node in each sub folder.

## Files
- `node/identities` contains the Plasma non-validator identity files which are configured in the `node/config.toml`.
- `node/keys` contains the validator bls keys which are configured in the `node/config.toml`.
- `enodes.txt` contains a list of enode URLs for connecting the execution node to the Plasma non-validators
- `non-validator.toml` is a sample configuration file for the Plasma non-validator node.
- `$NETWORK.jsoon` is the genesis file for the specified network.`

## Docker
The Docker example is run using the `launch.sh` script which will start both the execution and consensus clients.

Run `./launch.sh --help` for more information

### Quickstart

## Docker-Compose
The Docker-Compose example can be run by `cd`ing into the `docker-compose` folder and running:

```bash
docker compose up -d

# If you want Prometheus/Grafana run
docker compose -f monitoring.yml up -d
```

To stop the nodes run:

```bash
docker compose down

# Monitoring
docker compose -f monitoring.yml down
```

To clean up the volumes run:

```bash
docker compose down -v

# Monitoring
docker compose -f monitoring.yml down -v
```
