PLASMA_CONSENSUS_VERSION="0.12.2"
RETH_VERSION="v1.6.0"
NETWORK="mainnet"

rm -rf ./node/execution
rm -rf ./node/consensus

rm ./node/jwt.hex

mkdir -p node
mkdir -p node/execution
mkdir -p node/consensus

docker rm -f plasma-execution
docker rm -f plasma-consensus

docker network create plasma

# Read the enodes
enodes=$(cat enodes.txt)

# Create jwt.hex
openssl rand -hex 32 | tr -d '\n' > node/jwt.hex

# Create consensus identity
openssl ecparam -name secp256k1 -genkey -noout -out ./node/consensus/ec-secp256k1-non-validator.pem
openssl ec -in ./node/consensus/ec-secp256k1-non-validator.pem -outform DER -no_public -out ./node/consensus/ec-secp256k1-non-validator.der

# Dump genesis
docker \
  run \
  --rm \
  -i \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -v ./node:/node \
  ghcr.io/plasmalaboratories/plasma-consensus:"$PLASMA_CONSENSUS_VERSION" \
    plasma-cli \
    dump-genesis \
    --chain $NETWORK > ./node/$NETWORK.json

# Initialize Execution DB
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

# Initialize Consensus DB
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
    --disable-peer-scoring \
    --timeout-stream-manager 10ms \
    -vvv
