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
network=testnet

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
  ghcr.io/plasmalaboratories/plasma-consensus:0.11.4 \
    plasma-cli \
    dump-genesis \
    --chain $network > ./node/$network.json

# Initialize Execution DB
docker run \
  --rm \
  -i \
  --user "$(id -u):$(id -g)" \
  -v ./node:/node \
  ghcr.io/paradigmxyz/reth:v1.6.0 \
    init \
    --chain /node/$network.json \
    --datadir /node/execution \
    --log.file.directory /node/execution/log

# Initialize Consensus DB
docker run \
  --rm \
  -i \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -v ./node:/node \
  ghcr.io/plasmalaboratories/plasma-consensus:0.11.4 \
    plasma-cli \
    init \
    --chain /node/$network.json \
    --data-dir /node/consensus

# Initialize Consensus identity
docker run \
  --rm \
  -it \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -v ./node:/node \
  ghcr.io/plasmalaboratories/plasma-consensus:0.11.4 \
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
  ghcr.io/paradigmxyz/reth:v1.6.0 \
    node \
    --chain /node/$network.json \
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
docker run \
  --network plasma \
  -d \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  --name plasma-consensus \
  -p 34070:34070 \
  -v ./node:/node \
  -v ./non-validator.toml:/node/non-validator.toml \
  ghcr.io/plasmalaboratories/plasma-consensus:0.11.4 \
    plasma-cli \
    observer \
    --config-path /node/non-validator.toml \
    --no-color \
    --disable-peer-scoring \
    --timeout-stream-manager 10ms \
    -vvv
