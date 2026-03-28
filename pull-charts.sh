#!/bin/bash
set -euo pipefail

CACHE=".chart-cache"
MAX_RETRIES=3
mkdir -p "$CACHE"

pull_chart() {
  local repo=$1 chart=$2 version=$3
  if [[ "$repo" == oci://* ]]; then
    helm pull "$repo/$chart" --version "$version" -d "$CACHE"
  else
    helm pull "$chart" --version "$version" --repo "$repo" -d "$CACHE"
  fi
}

jq -c '.[]' charts.json | while read -r entry; do
  repo=$(echo "$entry" | jq -r '.repository')
  chart=$(echo "$entry" | jq -r '.chart')
  version=$(echo "$entry" | jq -r '.version')

  tgz="$CACHE/$chart-$version.tgz"
  if [ -f "$tgz" ]; then
    echo "Cached: $chart-$version"
    continue
  fi

  for attempt in $(seq 1 $MAX_RETRIES); do
    echo "Pulling: $chart@$version (attempt $attempt/$MAX_RETRIES)"
    if pull_chart "$repo" "$chart" "$version"; then
      break
    fi
    if [ "$attempt" -eq "$MAX_RETRIES" ]; then
      echo "FAILED: $chart@$version after $MAX_RETRIES attempts" >&2
      exit 1
    fi
    sleep 2
  done
done

echo "All charts cached in $CACHE/"
