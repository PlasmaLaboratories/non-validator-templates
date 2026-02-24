# Plasma Non-Validator Templates

Templates and deployment configurations for running Plasma non-validator (observer) nodes.

## Networks

| Network | Chain ID | Consensus Image | Consensus Version | Execution Version | Bootstrap Nodes | GHCR Auth Required |
|---------|----------|-----------------|-------------------|-------------------|-----------------|--------------------|
| mainnet | 9745 | `plasma-consensus` | 0.14.1 | Reth v1.8.3 | 16 consensus + 16 execution | Yes |
| testnet | 9746 | `plasma-consensus-public` | 0.15.0 | Reth v1.8.3 | 16 consensus + 16 execution | No |
| devnet | 9747 | `plasma-consensus` | 0.14.1 | Reth v1.8.3 | 3 consensus + 3 execution | Yes |

## Quick Start

```bash
# Clone
git clone https://github.com/PlasmaLaboratories/non-validator-templates.git
cd non-validator-templates

# Authenticate with GHCR (not required for `plasma-consensus-public`)
export CR_PAT=<your-github-pat>
echo $CR_PAT | docker login ghcr.io -u token --password-stdin

# Start a node (replace {network} with mainnet, testnet, or devnet)
cd {network}/docker-compose
docker compose up -d

# Optional: start monitoring (Prometheus + Grafana)
docker compose -f monitoring.yml up -d

# Verify
docker compose ps
docker compose logs -f plasma-consensus
```

## Directory Structure

```
{network}/
├── docker-compose/
│   ├── docker-compose.yml        # Service definitions
│   ├── .env                      # Image versions and tags (source of truth)
│   ├── non-validator.toml        # Consensus configuration
│   ├── enodes.txt                # Execution bootstrap nodes
│   ├── monitoring.yml            # Monitoring stack
│   └── monitoring/               # Prometheus & Grafana configs
└── shared/                       # Validator keys & identities (read-only)
    ├── keys/                     # BLS12-381 validator public keys
    └── identities/               # Validator identity files
```

## Configuration

All version numbers and image tags are defined in each network's `.env` file — that is the single source of truth. See `{network}/.env` for current values.

### Consensus Configuration (`non-validator.toml`)

Each network's `non-validator.toml` configures the consensus client. Key sections:

| Section | Fields | Description |
|---------|--------|-------------|
| *(top-level)* | `engine_api_url`, `consensus_api_host`, `authrpc_jwtsecret` | Execution engine connection |
| `[persistence]` | `data_dir` | Consensus data storage path |
| `[network]` | `p2p_port`, `interval`, `timeout`, `identity_file_path` | P2P networking |
| `[metrics]` | `enabled`, `host`, `port` | Prometheus metrics endpoint |
| `[api]` | `enabled`, `host`, `port` | Consensus API endpoint |
| `[committee_bls_pub_keys.*]` | `validator_keystore_pk_file_path`, `identity_file_path` | Validator committee |
| `[bootstrap_nodes.*]` | `api_host`, `p2p_port`, `peer_id` | Consensus peer discovery |

### Peer Discovery

For networks using `plasma-consensus-public:0.15.0` and higher, external addresses can be configured for nodes behind NAT:

```toml
[network]
external_address = "node.example.com:34070"
```

Or via CLI:
```
--p2p.external-address node.example.com:34070
```

The port defaults to `p2p_port` if not provided.

### Ports

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Execution RPC | 8545 | HTTP | JSON-RPC API endpoint |
| Execution Auth | 8551 | HTTP | Engine API (internal) |
| Execution P2P | 30303 | TCP/UDP | Peer-to-peer networking |
| Consensus API | 35070 | HTTP | Consensus Health/API endpoint |
| Consensus P2P | 34070 | TCP | Consensus networking |
| Metrics | 9001 | HTTP | Prometheus metrics |

## Usage

```bash
cd {network}/docker-compose

docker compose up -d                              # Start
docker compose -f monitoring.yml up -d            # Start monitoring
docker compose logs -f                            # Logs
docker compose down                               # Stop
docker compose -f monitoring.yml down             # Stop monitoring
docker compose down -v && docker compose up -d    # Clean restart
```

## Troubleshooting

### Container Startup Failures
```bash
docker compose logs <service-name>
docker pull ghcr.io/plasmalaboratories/plasma-consensus:<tag>
```

### Authentication Errors
```bash
export CR_PAT=<your-token>
echo $CR_PAT | docker login ghcr.io -u token --password-stdin
```

### Sync Issues
```bash
# Check execution client sync status
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545

```

## Monitoring

Monitor your node's health:
- Execution RPC: `http://localhost:8545`
- Consensus API: `http://localhost:35070`
- Metrics: `http://localhost:9001/metrics`

## Performance

- Use SSD storage for optimal I/O
- Ensure sufficient RAM to avoid swap usage
- Monitor CPU usage during initial sync
- Consider increasing ulimits for production deployments

---
