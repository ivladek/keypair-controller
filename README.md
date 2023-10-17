# keypair-controller

Key Pair Controller - generate, add to agent, show information in secure manner

Syntax: ./keypair-controller.sh -d -n [[-c] [-l] | -s] [-p]
options:
  h           - print this Help
  d path      - target path
  n name      - key pair name
  c "comment" - key pair decription
  l NNN       - use RSA algorithm with key length or ED25519 if omitted
  s pathname  - use unecrypted secret key and regenerate config and public
  p           - ask secret key password instead of auto generation

use KEYPAIR_CONFIG_PASS variable to use config file password silently"

Examples
./keypair-controller.sh -d ~/Documents/keypairs -n github.com -c "github.com / vladek@me.com"
  generate the new key pair using ED25519 in directory ~/Documents/keypairs

./keypair-controller.sh -d ~/Documents/keypairs -n gitlab.com -s ~/Documents/secrets/gitlab.com.key
  import unecrypted secret key, generate the new config and public key

./keypair-controller.sh -d ~/Documents/keypairs -n git.corp.com -l 4096 -c "corp git / vladek@corp.com" -p
  generate the new key pair using RSA, ask for secret key file password.

The second run of the same command just print information about key pair.
