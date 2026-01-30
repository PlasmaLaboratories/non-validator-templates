PLASMA_CONSENSUS_VERSION="0.14.1"
RETH_VERSION="v1.8.3"
NETWORK="devnet"

log() { printf '%s %s\n' "[$(date +'%F %T')]" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# Help
###############################################################################
show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -h, --help                     Show this help and exit
  -n, --network STR              devnet|testnet|mainnet
  -c, --cleanup                  Cleanup previous deployment then exits
  -d, --down                     Stop and remove the containers then exits
  --consensus-version            Override for the plasma-consensus version
  --reth-version                 Override for the reth version
EOF
}

###############################################################################
# Arg parsing
###############################################################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help; exit 0 ;;
      -n|--network) NETWORK="${2:-}"; shift 2 ;;
      --cleanup) CLEANUP=true; shift ;;
      --consensus-version) PLASMA_CONSENSUS_VERSION=${2:-}; shift 2 ;;
      --reth-version) RETH_VERSION=${2:-}; shift 2 ;;
      -d|--down) DOWN=true; shift ;;
      *) die "Invalid option: $1" ;;
    esac
  done
}

parse_args "$@"

if [[ $DOWN == "true" ]]; then
  log "Stopping and removing containers..."
  docker rm -f plasma-execution plasma-consensus || true
  exit 0
fi

if [[ "$CLEANUP" == "true" ]]; then
  log "Cleaning up previous deployment..."
  docker rm -f plasma-execution plasma-consensus || true
  rm -rf ./node
  exit 0
fi

mkdir -p node
mkdir -p node/execution
mkdir -p node/consensus

docker network create plasma

# Read the enodes
enodes=$(cat enodes.txt)

# Create jwt.hex
if [[ ! -f node/jwt.hex ]]; then
  openssl rand -hex 32 | tr -d '\n' > node/jwt.hex
fi

# Create consensus identity
if [[ ! -f ./node/consensus/ec-secp256k1-non-validator.pem ]]; then
  openssl ecparam -name secp256k1 -genkey -noout -out ./node/consensus/ec-secp256k1-non-validator.pem
  openssl ec -in ./node/consensus/ec-secp256k1-non-validator.pem -outform DER -no_public -out ./node/consensus/ec-secp256k1-non-validator.der
fi

# Copy genesis
cp ../shared/$NETWORK.json ./node/$NETWORK.json

# Initialize Execution DB
if [[ ! -d ./node/execution/db ]]; then
  log "Initializing execution database..."
  docker run \
    --rm \
    -i \
    --user "$(id -u):$(id -g)" \
    -v ./node:/node \
    ghcr.io/paradigmxyz/reth:"$RETH_VERSION" \
      init \
      --chain /node/$NETWORK.json \
      --datadir /node/execution \
      --log.file.directory /node/execution/log
fi

# Initialize Consensus DB
if [[ ! -d ./node/consensus/data.mdbx ]]; then
  log "Initializing consensus database..."
  docker run \
    --rm \
    -i \
    --platform linux/amd64 \
    --user "$(id -u):$(id -g)" \
    -v ./node:/node \
    ghcr.io/plasmalaboratories/plasma-consensus:"$PLASMA_CONSENSUS_VERSION" \
      plasma-cli \
      init \
      --chain /node/$NETWORK.json \
      --data-dir /node/consensus
fi
# Initialize Consensus identity
docker run \
  --rm \
  -it \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -v ./node:/node \
  ghcr.io/plasmalaboratories/plasma-consensus:"$PLASMA_CONSENSUS_VERSION" \
    plasma-cli peer-id \
    --identity-file-path /node/consensus/ec-secp256k1-non-validator.der > ./node/peer-id.txt

# Run Execution node
docker run \
  --network plasma \
  -d \
  --user "$(id -u):$(id -g)" \
  --name plasma-execution \
  -p 8551:8551 \
  -p 30303:30303 \
  -v ./node:/node \
  ghcr.io/paradigmxyz/reth:"$RETH_VERSION" \
    node \
    --chain /node/$NETWORK.json \
    --datadir /node/execution \
    --trusted-peers "$enodes" \
    --authrpc.jwtsecret /node/jwt.hex \
    --authrpc.addr 0.0.0.0 \
    --authrpc.port 8551 \
    --http \
    --http.addr 0.0.0.0 \
    --http.api eth,net,web3,txpool,debug \
    --http.corsdomain '*' \
    -vvv \
    --color never \
    --rpc.gascap "36000000" \
    --txpool.gas-limit "36000000" \
    --txpool.blobpool-max-count "0" \
    --txpool.blobpool-max-size "0" \
    --txpool.blob-cache-size "0" \
    --log.file.directory /node/execution/log

# Run consensus node
# 34070: p2p
# 35070: rpc
# 9001: metrics
docker run \
  --network plasma \
  -d \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  --name plasma-consensus \
  -p 34070:34070 \
  -p 35070:35070 \
  -p 9001:9001 \
  -v ./node:/node \
  -v ../shared/keys:/node/keys \
  -v ../shared/identities:/node/identities \
  -v ./non-validator.toml:/node/non-validator.toml \
  ghcr.io/plasmalaboratories/plasma-consensus:"$PLASMA_CONSENSUS_VERSION" \
    plasma-cli \
    observer \
    --config-path /node/non-validator.toml \
    --no-color \
    --timeout-stream-manager 10ms \
    -vvv
