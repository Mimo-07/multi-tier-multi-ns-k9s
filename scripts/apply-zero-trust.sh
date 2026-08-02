#!/bin/bash

set -e

POLICY_DIR="./policies"

if [ ! -d "$POLICY_DIR" ]; then
    echo "Error: Directory '$POLICY_DIR' does not exist."
    exit 1
fi

echo "Applying Kubernetes Network Policies..."
echo

for file in "$POLICY_DIR"/*.yaml "$POLICY_DIR"/*.yml; do
    if [ -f "$file" ]; then
        echo "Applying $(basename "$file")..."
        kubectl apply -f "$file"
        echo
    fi
done

echo "✅ All policies have been applied."