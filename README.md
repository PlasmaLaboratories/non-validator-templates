# Plasma Non-Validator Templates

Templates and deployment configurations for running Plasma non-validator (observer) nodes.

## Networks

| Network | Chain ID | Consensus Image | Consensus Version | Execution Version | Bootstrap Nodes | GHCR Auth Required |
|---------|----------|-----------------|-------------------|-------------------|-----------------|--------------------|
| mainnet | 9745 | `plasma-consensus-public` | 0.15.0 | Reth v1.8.3 | 16 consensus + 16 execution | No |
| testnet | 9746 | `plasma-consensus-public` | 0.15.0 | Reth v1.8.3 | 16 consensus + 16 execution | No |
| devnet | 9747 | `plasma-consensus-public` | 0.15.0 | Reth v1.8.3 | 3 consensus + 3 execution | No |

## Quick Start

```bash
# Clone
git clone https://github.com/PlasmaLaboratories/non-validator-templates.git
cd non-validator-templates

# No GHCR login is required; `plasma-consensus-public` is publicly accessible

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

All version numbers and image tags are defined in each network's `.env` file — that is the single source of truth. See `{network}/docker-compose/.env` for current values.

### Consensus Configuration (`non-validator.toml`)

Each network's `non-validator.toml` configures the consensus client. Key sections:

| Section | Fields | Description |
|---------|--------|-------------|
| *(top-level)* | `engine_api_url`, `consensus_api_host`, `authrpc_jwtsecret` | Execution engine connection |
| `[persistence]` | `data_dir` | Consensus data storage path |
| `[network]` | `p2p_port`, `interval`, `timeout`, `identity_file_path`, `trusted_only`, `discovery.enabled` | P2P networking and peer discovery |
| `[api]` | `enabled`, `host`, `port` | Consensus API endpoint |
| `[validators.*]` | `validator_keystore_pk_file_path`, `identity_file_path` | Validator committee |
| `[network.bootstrap_nodes.*]` | `api_host`, `p2p_port`, `peer_id` | Consensus bootstrap peers |

### Peer Discovery

The checked-in templates use `plasma-consensus-public:0.15.0` with peer discovery enabled. External addresses can be configured for nodes behind NAT:

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
```

### Image Pull Issues
```bash
# GHCR authentication is not required for `plasma-consensus-public`
docker pull ghcr.io/plasmalaboratories/plasma-consensus-public:0.15.0
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

## Database Snapshots

Plasma publishes daily database snapshots for **mainnet** and **testnet**. Snapshots let you bootstrap a new node in hours instead of syncing from genesis (which can take days to weeks).

Each snapshot contains two files — the consensus-layer database and the execution-layer database — uploaded to a requester-pays S3 bucket. You need an AWS account; standard S3 data-transfer rates apply.

### Prerequisites

| Requirement | Details |
|-------------|---------|
| AWS account | Credentials configured via `aws configure` or environment variables |
| AWS CLI | v2 recommended (`aws --version`) |
| Disk space | **Mainnet:** ~400 GB free &nbsp;&bull;&nbsp; **Testnet:** ~100 GB free |

> **Cost note:** Data transfer out from `us-east-2` is ~$0.09/GB for the first 10 TB/month. Transferring from an EC2 instance **in the same region** is free — running your node in `us-east-2` is the most cost-effective option.

### Snapshot Buckets

| Property | Mainnet | Testnet |
|----------|---------|---------|
| **Bucket** | `plasma-mainnet-db-backups` | `plasma-testnet-db-backups` |
| **Region** | `us-east-2` (Ohio) | `us-east-2` (Ohio) |
| **Access model** | Requester-pays | Requester-pays |
| **Backup cadence** | Daily | Daily at 02:00 UTC |
| **Retention** | Rolling (older backups removed automatically) | 3 days |
| **Transport** | TLS required | TLS required |

### Bucket Contents

Backups are organized into date-stamped folders (`MM-DD-YY`). Each folder contains two files:

**Mainnet** — consensus database uses `.db` extension:
```
plasma-mainnet-db-backups/
├── 03-22-26/
│   ├── consensus-backup-20260322-020001.db        (~218 GB)
│   └── execution-backup-20260322-020001.tar.gz    (~102 GB)
├── 03-23-26/
│   ├── consensus-backup-20260323-020001.db
│   └── execution-backup-20260323-020001.tar.gz
└── ...
```

**Testnet** — consensus database uses `.mdb` extension:
```
plasma-testnet-db-backups/
├── 02-23-26/
│   ├── consensus-backup-20260223-020001.mdb       (~56 GB)
│   └── execution-backup-20260223-020001.tar.gz    (~9 GB)
├── 02-24-26/
│   ├── consensus-backup-20260224-020001.mdb
│   └── execution-backup-20260224-020001.tar.gz
└── ...
```

| File | Description |
|------|-------------|
| **Consensus database** (`.db` or `.mdb`) | Full consensus-layer state, exported via `plasma-cli copy-db` |
| **Execution database** (`.tar.gz`) | Tar archive of the reth execution `data/` directory |

### Step 1 — Download

Replace `BUCKET` with the appropriate bucket name from the table above.

```bash
# Set your target network's bucket
BUCKET="plasma-mainnet-db-backups"   # or "plasma-testnet-db-backups"

# List available snapshots
aws s3 ls "s3://${BUCKET}/" \
  --region us-east-2 \
  --request-payer requester

# List files in a specific snapshot
aws s3 ls "s3://${BUCKET}/03-23-26/" \
  --region us-east-2 \
  --request-payer requester

# Download the most recent snapshot
DATE="03-23-26"   # replace with the latest date folder

aws s3 cp \
  "s3://${BUCKET}/${DATE}/" \
  ./backups/ \
  --recursive \
  --region us-east-2 \
  --request-payer requester
```

### Step 2 — Restore

Stop your node before restoring:

```bash
cd {network}/docker-compose
docker compose down
```

**Consensus layer** — copy the snapshot into the consensus data directory:

```bash
# Mainnet (.db)
cp backups/consensus-backup-*.db /path/to/plasma-data-dir/

# Testnet (.mdb)
cp backups/consensus-backup-*.mdb /path/to/plasma-data-dir/
```

**Execution layer** — extract the archive into the execution data directory:

```bash
tar -xzf backups/execution-backup-*.tar.gz -C /path/to/execution-data-dir/
```

This restores the `data/` subdirectory containing the full reth execution state.

Then restart your node:

```bash
docker compose up -d
```

### Snapshot Troubleshooting

| Issue | Cause / Fix |
|-------|-------------|
| `Access Denied` | You must include `--request-payer requester` on every command. The bucket rejects requests without it. |
| `403 Forbidden` | AWS credentials not configured. Run `aws sts get-caller-identity` to verify you have a valid session. |
| Empty bucket listing | Older backups are automatically cleaned up. If the bucket appears empty, a backup cycle may be in progress — check back later. |
| Wrong file extension | Mainnet uses `.db`; testnet uses `.mdb`. Ensure you copy the correct file for your network. |

---
