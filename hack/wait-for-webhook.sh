#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Get script parameters
SCHEDULER_NAME="${1:-}"
if [[ -z "$SCHEDULER_NAME" ]]; then
    echo "Usage: $0 <scheduler-name>"
    echo "Example: $0 kueue"
    exit 1
fi

# Set variables
KUBECONFIG="${KUBECONFIG:-./kubeconfig.yaml}"
NAMESPACE="${SCHEDULER_NAME}-system"
WEBHOOK_SERVICE="${SCHEDULER_NAME}-webhook-service"

echo "Waiting for ${SCHEDULER_NAME} webhook service to be ready..."

# Wait for webhook certificate generation
echo "Checking webhook certificate..."
for i in $(seq 1 30); do
    if kubectl --kubeconfig="$KUBECONFIG" get secret -n "$NAMESPACE" "${SCHEDULER_NAME}-webhook-server-cert" >/dev/null 2>&1; then
        echo "✓ Webhook certificate generated"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "✗ Timeout waiting for webhook certificate"
        exit 1
    fi
    sleep 2
done

# Wait for webhook Pod to be ready
echo "Waiting for webhook Pod to be ready..."
kubectl --kubeconfig="$KUBECONFIG" wait --for=condition=ready pod -l control-plane=controller-manager -n "$NAMESPACE" --timeout=120s

# Wait for webhook service endpoints to be ready
echo "Waiting for webhook service endpoints..."
for i in $(seq 1 30); do
    if kubectl --kubeconfig="$KUBECONFIG" get endpoints -n "$NAMESPACE" "$WEBHOOK_SERVICE" -o jsonpath='{.subsets[0].addresses}' | grep -q .; then
        echo "✓ Webhook service endpoints ready"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "✗ Timeout waiting for webhook service endpoints"
        exit 1
    fi
    sleep 2
done

# Verify webhook service accessibility
echo "Verifying webhook service accessibility..."
for i in $(seq 1 10); do
    if kubectl --kubeconfig="$KUBECONFIG" get endpoints -n "$NAMESPACE" "$WEBHOOK_SERVICE" -o jsonpath='{.subsets[0].ports[0].port}' | grep -q "443"; then
        echo "✓ Webhook service port is normal"
        break
    fi
    if [[ $i -eq 10 ]]; then
        echo "✗ Webhook service port verification failed"
        exit 1
    fi
    sleep 1
done

echo "✓ ${SCHEDULER_NAME} webhook service is fully ready" 