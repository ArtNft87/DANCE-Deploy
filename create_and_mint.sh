#!/usr/bin/env bash
set -e

# Keypair paths (edit these to your real files):
KEY1=~/keys/you1.json
KEY2=~/keys/you2.json
KEY3=~/keys/backup.json

# Network: pass “devnet” or “mainnet-beta” as first argument (defaults to devnet)
CLUSTER=${1:-devnet}
RPC_URL="https://api.${CLUSTER}.solana.com"

echo "🛠️  Running on cluster: $CLUSTER ($RPC_URL)"

# 1) Create the 2-of-3 multisig
echo "1) Creating multisig (2-of-3)…"
MULTISIG=$(solana spl-token create-multisig \
  $(solana-keygen pubkey $KEY1) \
  $(solana-keygen pubkey $KEY2) \
  $(solana-keygen pubkey $KEY3) 2 \
  --url $RPC_URL --keypair $KEY1 \
  | awk '{print $2}')
echo "   → Multisig address: $MULTISIG"

# 2) Create the Dancecoin mint
echo "2) Creating Dancecoin mint (6 decimals)…"
MINT=$(solana spl-token create-token \
  --decimals 6 \
  --mint-authority $MULTISIG \
  --burn-authority $MULTISIG \
  --url $RPC_URL --keypair $KEY1 \
  | awk '{print $2}')
echo "   → Mint address: $MINT"

# 3) Create the treasury (associated token) account
echo "3) Creating treasury token account…"
solana spl-token create-account $MINT \
  --url $RPC_URL --owner $KEY1

# 4) Mint the full 100,000,000 DANCE (×10^6 base units)
echo "4) Minting full supply (100 M)…"
solana spl-token mint $MINT 100000000000000000 \
  --owner $MULTISIG \
  --signer $KEY1 --signer $KEY2 \
  --url $RPC_URL
echo "   → Minted 100 M DANCE to treasury"

# 5) (Optional) Disable future mint authority
read -p "Disable mint authority forever? [y/N] " yn
if [[ $yn =~ ^[Yy] ]]; then
  echo "5) Disabling mint authority…"
  solana spl-token authorize $MINT mint --disable-authority \
    --owner $MULTISIG --signer $KEY1 --signer $KEY2 \
    --url $RPC_URL
  echo "   → Mint authority disabled"
fi

echo "✅ Done on $CLUSTER"
echo "   • Multisig: $MULTISIG"
echo "   • Mint:     $MINT"
