#!/usr/bin/env bash

set -Eeuo pipefail

ARGOCD_NAMESPACE="argocd"
APP_NAMESPACE="go-demo"
APP_NAME="go-demo-app"
EXPECTED_CONTEXT="k3d-asciiartify"

usage() {
  printf '%s\n' \
    "Usage: $0 <command>" \
    "" \
    "Commands:" \
    "  preflight       Verify tools, context, nodes and Argo CD" \
    "  apply           Create/update the Argo CD Application" \
    "  status          Show Application and workload state" \
    "  watch           Watch sync status and frontend replicas" \
    "  app-ui          Forward the product UI to http://localhost:8888" \
    "  argocd-ui       Forward Argo CD to https://localhost:8080" \
    "  drift           Scale frontend manually to demonstrate self-heal" \
    "  cleanup         Delete the Application and its managed resources"
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

check_context() {
  local current_context
  current_context="$(kubectl config current-context)"

  if [[ "$current_context" != "$EXPECTED_CONTEXT" ]]; then
    printf 'ERROR: current context is %s, expected %s\n' \
      "$current_context" "$EXPECTED_CONTEXT" >&2
    exit 1
  fi
}

preflight() {
  require_tool kubectl
  require_tool k3d
  check_context

  printf '%s\n' '=== k3d ==='
  k3d version
  printf '%s\n' '=== Kubernetes nodes ==='
  kubectl get nodes -o wide
  printf '%s\n' '=== Argo CD pods ==='
  kubectl get pods -n "$ARGOCD_NAMESPACE"
}

apply_application() {
  require_tool kubectl
  check_context

  kubectl apply -f argocd/go-demo-app.yaml
  printf '%s\n' 'Waiting for Argo CD to report the application as Synced...'
  kubectl wait "application/$APP_NAME" \
    -n "$ARGOCD_NAMESPACE" \
    --for=jsonpath='{.status.sync.status}'=Synced \
    --timeout=300s

  status
}

status() {
  require_tool kubectl
  check_context

  printf '%s\n' '=== Argo CD Application ==='
  kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISIONS:.status.sync.revisions[*]'
  printf '%s\n' '=== Workloads ==='
  kubectl get deployments,statefulsets,pods,services -n "$APP_NAMESPACE" -o wide
}

watch_sync() {
  require_tool kubectl
  check_context

  printf '%s\n' 'Press Ctrl+C after Argo CD reaches Synced and frontend reaches 2/2.'
  while true; do
    clear
    date -Is
    kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" \
      -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISIONS:.status.sync.revisions[*]'
    printf '\n'
    kubectl get deployment go-demo-front -n "$APP_NAMESPACE"
    printf '\n'
    kubectl get pods -n "$APP_NAMESPACE" -l app=go-demo-front -o wide
    sleep 3
  done
}

app_ui() {
  require_tool kubectl
  check_context
  printf '%s\n' 'Open http://localhost:8888 in the browser.'
  kubectl port-forward -n "$APP_NAMESPACE" svc/go-demo-front 8888:80
}

argocd_ui() {
  require_tool kubectl
  check_context
  printf '%s\n' 'Open https://localhost:8080 in the browser.'
  kubectl port-forward --address 0.0.0.0 \
    svc/argocd-server -n "$ARGOCD_NAMESPACE" 8080:443
}

create_drift() {
  require_tool kubectl
  check_context

  printf '%s\n' 'Scaling go-demo-front to 3 outside Git...'
  kubectl scale deployment go-demo-front -n "$APP_NAMESPACE" --replicas=3
  printf '%s\n' 'Argo CD self-heal should restore the Git value shortly.'
  kubectl get deployment go-demo-front -n "$APP_NAMESPACE" -w
}

cleanup() {
  require_tool kubectl
  check_context

  kubectl delete application "$APP_NAME" -n "$ARGOCD_NAMESPACE"
}

case "${1:-}" in
  preflight) preflight ;;
  apply) apply_application ;;
  status) status ;;
  watch) watch_sync ;;
  app-ui) app_ui ;;
  argocd-ui) argocd_ui ;;
  drift) create_drift ;;
  cleanup) cleanup ;;
  *) usage; exit 1 ;;
esac
