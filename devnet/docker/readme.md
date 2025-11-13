# Running the `plasma-consensus` non-validator on the Plasma Devnet

## Using the provided `launch.sh` script

### Tools required
* Docker
* Linux
* `openssl`

1. Use the provided GitHub PAT to authenticate to Plasma's Docker registry
```
export CR_PAT=<your-pat>
echo $CR_PAT | docker login ghcr.io -u token --password-stdin
```
2. Make sure the node IP addresses are provided to our team
3. Run `./launch.sh`

## General steps to run a non-validator

1. Use openssl to generate a jwt.hex for you non-validator + execution client communication
2. Dump the genesis file via plasma-cli (consensus image)
3. Initialize execution client with genesis file
4. Initialize consensus client with genesis file
5. Create consensus identity
6. Start the execution node with the enodes
7. Start the consensus node via plasma-cli non-validator --config-path <non-validator.toml>
   - Make sure to update the `engine_api_url` to your local execution node and update any of the paths for your configuration
