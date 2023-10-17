# Key Pair Controller
Bash script for Macos for generation key pairs, adding them to ssh agent, showing information. In secure manner.

## Syntax
./keypair-controller.sh -d -n [[-c] [-l] | -s] [-p]<br>
  **h**           - print this Help<br>
  **d path**      - target path<br>
  **n name**      - key pair name<br>
  **c "comment"** - key pair decription<br>
  **l NNN**       - use RSA algorithm with key length or ED25519 if omitted<br>
  **s pathname**  - use unecrypted secret key and regenerate config and public<br>
  **p**           - ask secret key password instead of auto generation<br>

## Examples
./keypair-controller.sh -d ~/Documents/keypairs -n github.com -c "github.com / vladek@me.com"<br>
  _Generate the new key pair using ED25519 in directory ~/Documents/keypairs._

./keypair-controller.sh -d ~/Documents/keypairs -n gitlab.com -s ~/Documents/secrets/gitlab.com.key<br>
  _Import unecrypted secret key, generate the new config and public key._

./keypair-controller.sh -d ~/Documents/keypairs -n git.corp.com -l 4096 -c "corp git / vladek@corp.com" -p<br>
  _Generate the new key pair using RSA, ask for secret key file password._


## Additions
The second run of the same command just print information about key pair.<br>
Use **KEYPAIR_CONFIG_PASS** variable to use config file password silently.
