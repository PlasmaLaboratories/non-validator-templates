# Plasma Non-Validator Templates

This repository contains comprehensive templates and deployment configurations for setting up Plasma non-validator nodes on both mainnet and testnet networks.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Network Configurations](#network-configurations)
- [Deployment Methods](#deployment-methods)
  - [Docker Compose (Recommended)](#docker-compose-recommended)
  - [Docker Scripts](#docker-scripts)
- [Configuration](#configuration)
- [Network Information](#network-information)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Overview

Plasma non-validator nodes (observers) are essential infrastructure components that:
- Synchronize with the Plasma network without participating in consensus
- Provide read access to blockchain data via RPC endpoints
- Support network decentralization and reliability
- Enable developers to build applications on Plasma

This repository is organized by network (`mainnet`/`testnet`) with multiple deployment options in each directory.

## Prerequisites

### Access Requirements
- GitHub Container Registry access token for Plasma images
- Network connectivity to Plasma bootstrap nodes

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/PlasmaLaboratories/non-validator-templates.git
   cd non-validator-templates
   ```

2. **Authenticate with GitHub Container Registry**:
   ```bash
   export CR_PAT=<your-github-pat>
   echo $CR_PAT | docker login ghcr.io -u token --password-stdin
   ```

3. **Choose your network and deployment method**:
   ```bash
   # For mainnet with docker-compose (recommended)
   cd mainnet/docker-compose
   docker compose up -d

   # For monitoring (optional)
   docker compose -f monitoring.yml up -d

   # For testnet with docker-compose
   cd testnet/docker-compose
   docker compose up -d

   # For monitoring (optional)
   docker compose -f monitoring.yml up -d
   ```

4. **Verify deployment**:
   ```bash
   # Check container status
   docker compose ps

   # View logs
   docker compose logs -f plasma-consensus
   docker compose logs -f plasma-execution
   ```

## Network Configurations

### Mainnet
- **Chain ID**: 9745
- **Consensus Version**: 0.12.4
- **Execution Client**: Reth v1.6.0
- **Bootstrap Nodes**: 10 consensus + 10 execution nodes
- **Location**: `mainnet/` directory

### Testnet
- **Chain ID**: 9745 (testnet)
- **Consensus Version**: 0.12.4
- **Execution Client**: Reth v1.6.0
- **Bootstrap Nodes**: 3 consensus + 3 execution nodes
- **Location**: `testnet/` directory

## Deployment Methods

### Docker Compose (Recommended)

Docker Compose provides the most reliable and maintainable deployment method.

#### Features
- Automated service orchestration
- Persistent data volumes
- Automatic container dependencies
- Easy scaling and updates
- Built-in networking

#### Directory Structure
```
{mainnet|testnet}/docker-compose/
├── docker-compose.yml    # Service definitions
├── .env                 # Environment variables
├── non-validator.toml   # Consensus configuration
├── enodes.txt          # Execution bootstrap nodes
└── readme.md           # Specific instructions
```

#### Usage
```bash
cd {mainnet|testnet}/docker-compose

# Start services in background
docker compose up -d

# For monitoring (optional)
docker compose -f monitoring.yml up -d

# View real-time logs
docker compose logs -f

# Stop services
docker compose down

# For monitoring (optional)
docker compose -f monitoring.yml down

# Clean restart (removes volumes)
docker compose down -v && docker compose up -d
```

### Docker Scripts

Deployment method using shell scripts for direct Docker management.

#### Features
- Direct Docker container control
- Script-based initialization
- Manual volume management
- Custom networking setup

#### Directory Structure
```
{mainnet|testnet}/docker/
├── launch.sh           # Main deployment script
├── non-validator.toml  # Consensus configuration
├── enodes.txt         # Execution bootstrap nodes
├── readme.md          # Specific instructions
└── .gitignore         # Excluded runtime files
```

#### Usage
```bash
cd {mainnet|testnet}/docker

# Make script executable and run
chmod +x launch.sh
./launch.sh

# For more options
./launch.sh --help
```

## Configuration

### Key Configuration Files

#### 1. Environment Variables (`.env`)
```bash
# Docker image configuration
PLASMA_CONSENSUS_IMAGE=ghcr.io/plasmalaboratories/plasma-consensus
PLASMA_CONSENSUS_TAG=0.12.4
PLASMA_EXECUTION_IMAGE=ghcr.io/paradigmxyz/reth
PLASMA_EXECUTION_TAG=v1.7.0
NETWORK=mainnet
```

#### 2. Consensus Configuration (`non-validator.toml`)
```toml
engine_api_url = "http://plasma-execution:8551"
authrpc_jwtsecret = "/jwt/jwt.hex"

[persistence]
data_dir = "/consensus"

[network]
p2p_port = 34070
identity_file_path = "/consensus/ec-secp256k1-non-validator.der"

[api]
enabled = true
host = "0.0.0.0"
port = 35070
```

#### 3. Bootstrap Nodes (`enodes.txt`)
Contains enode URLs for execution client peer discovery. These are automatically loaded by the deployment scripts.

### Shared Resources

Both networks reference shared validator keys and identities:
- `shared/keys/`: BLS12-381 validator public keys
- `shared/identities/`: Validator identity files

These files are mounted read-only into consensus containers for committee validation.

### Port Configuration

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Execution RPC | 8545 | HTTP | JSON-RPC API endpoint |
| Execution Auth | 8551 | HTTP | Engine API (internal) |
| Execution P2P | 30303 | TCP/UDP | Peer-to-peer networking |
| Consensus API | 35070 | HTTP | Consensus Health/API endpoint |
| Consensus P2P | 34070 | TCP | Consensus networking |
| Metrics | 9001 | HTTP | Prometheus metrics |


## Troubleshooting

### Common Issues

#### 1. Container Startup Failures
```bash
# Check container logs
docker compose logs <service-name>

# Verify image availability
docker pull ghcr.io/plasmalaboratories/plasma-consensus:<tag>
```

#### 2. Authentication Errors
```bash
# Re-authenticate with GitHub registry
export CR_PAT=<your-token>
echo $CR_PAT | docker login ghcr.io -u token --password-stdin
```

#### 3. Sync Issues
```bash
# Check execution client sync status
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545

# Check consensus client logs for peer connections
docker compose logs plasma-consensus | grep -i "peer\|sync"
```

#### 4. Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep -E ':(8545|8551|34070|35070)'

# Modify port mappings in docker-compose.yml if needed
```

#### 5. Disk Space Issues
```bash
# Check Docker volume usage
docker system df

# Clean up unused resources
docker system prune -a --volumes
```

### Log Analysis

```bash
# Follow all service logs
docker compose logs -f

# Filter specific service logs
docker compose logs -f plasma-consensus
docker compose logs -f plasma-execution

# Search for specific patterns
docker compose logs plasma-consensus | grep -i error
```

## Support

### Getting Help

1. **Documentation**: Check network-specific readme files in subdirectories
2. **Logs**: Always include relevant log output when reporting issues
3. **System Info**: Provide OS, Docker version, and hardware specifications
4. **Network Status**: Verify bootstrap node connectivity and network health

### Monitoring

Monitor your node's health using:
- Execution RPC: `http://localhost:8545`
- Consensus API: `http://localhost:35070`
- Metrics: `http://localhost:9001/metrics`

### Performance Optimization

- Use SSD storage for optimal I/O performance
- Ensure sufficient RAM to avoid swap usage
- Monitor CPU usage during initial sync
- Consider increasing ulimits for production deployments

---

For network-specific instructions and configurations, see the readme files in the respective `mainnet/` and `testnet/` subdirectories.

