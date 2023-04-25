#!/usr/bin/env bash
set -e

[[ "$ETH_RPC_URL" && "$(seth chain)" == "ethlive" ]] || { echo "Please set a mainnet ETH_RPC_URL"; exit 1; }

if [[ -z "$1" ]]; then
  forge test --rpc-url="$ETH_RPC_URL"
else
  forge test --rpc-url="$ETH_RPC_URL" --match "$1" -vvvv
fi
