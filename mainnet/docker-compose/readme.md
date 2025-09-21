# Running the `plasma-consensus` non-validator on the Plasma Testnet

## Using docker-compose

### Tools required
* Docker
* docker-compose
* Linux

1. Use the provided GitHub PAT to authenticate to Plasma's Docker registry
```
export CR_PAT=<your-pat>
echo $CR_PAT | docker login ghcr.io -u token --password-stdin
```
2. Make sure the node IP addresses are provided to our team
3. Run `docker compose up -d`

### Run in foreground
```
docker compose up
```

### Clean up previous run
```
docker compose down -v && docker compose up
```
