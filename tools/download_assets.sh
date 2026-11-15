#!/usr/bin/env bash
set -euo pipefail
mkdir -p assets
curl --fail --location --retry 4 --retry-delay 2 "https://cdn.3dassets.dev/assets/25413/v1/model.glb" --output assets/retail_shopfloor_source.glb
test "$(wc -c < assets/retail_shopfloor_source.glb)" -gt 1000000
npm install --global @gltf-transform/cli
gltf-transform dequantize assets/retail_shopfloor_source.glb assets/retail_shopfloor.glb
test "$(wc -c < assets/retail_shopfloor.glb)" -gt 1000000
