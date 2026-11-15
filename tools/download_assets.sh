#!/usr/bin/env bash
set -euo pipefail
mkdir -p assets
npm install --global @gltf-transform/cli
curl --fail --location --retry 4 --retry-delay 2 "https://cdn.3dassets.dev/assets/25413/v1/model.glb" --output assets/retail_shopfloor_source.glb
gltf-transform dequantize assets/retail_shopfloor_source.glb assets/retail_shopfloor.glb
rm assets/retail_shopfloor_source.glb
curl --fail --location --retry 4 --retry-delay 2 "https://cdn.3dassets.dev/assets/25360/v1/model.glb" --output assets/concourse_escalator_source.glb
gltf-transform dequantize assets/concourse_escalator_source.glb assets/concourse_escalator.glb
rm assets/concourse_escalator_source.glb
curl --fail --location --retry 4 --retry-delay 2 "https://cdn.3dassets.dev/assets/25377/v1/model.glb" --output assets/mall_column_cladding_source.glb
gltf-transform dequantize assets/mall_column_cladding_source.glb assets/mall_column_cladding.glb
rm assets/mall_column_cladding_source.glb
curl --fail --location --retry 4 --retry-delay 2 "https://cdn.3dassets.dev/assets/25381/v1/model.glb" --output assets/concourse_planter_bench_source.glb
gltf-transform dequantize assets/concourse_planter_bench_source.glb assets/concourse_planter_bench.glb
rm assets/concourse_planter_bench_source.glb
curl --fail --location --retry 4 --retry-delay 2 "https://cdn.3dassets.dev/assets/25385/v1/model.glb" --output assets/concourse_litter_bin_source.glb
gltf-transform dequantize assets/concourse_litter_bin_source.glb assets/concourse_litter_bin.glb
rm assets/concourse_litter_bin_source.glb
for file in assets/retail_shopfloor.glb assets/concourse_escalator.glb assets/mall_column_cladding.glb assets/concourse_planter_bench.glb assets/concourse_litter_bin.glb; do test "$(wc -c < "$file")" -gt 10000; done
