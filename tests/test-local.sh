#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "$0")/.."
passed=0
ok() { passed=$((passed+1)); printf 'PASS %s\n' "$1"; }
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do bash -n "$f"; done
ok bash-syntax
python3 scripts/validate-network.py dhcp '' '' ''
python3 scripts/validate-network.py static 192.168.56.10/24 192.168.56.1 192.168.56.1
ok valid-network
if python3 scripts/validate-network.py static 192.168.56.10/24 10.0.0.1 192.168.56.1 2>/dev/null; then exit 1; fi
ok rejects-outside-gateway
if python3 scripts/validate-network.py static '192.168.1.1/24,evil' 192.168.1.2 1.1.1.1 2>/dev/null; then exit 1; fi
ok rejects-network-injection
out=$(MONITOR_CONFIG=config/monitor.conf.example bash scripts/monitor.sh --simulate 85 85 90)
[[ $(grep -c 'level=ALERT' <<< "$out") == 3 ]]
[[ $(grep -c 'source=simulation' <<< "$out") == 3 ]]
ok alerts-at-all-thresholds
out=$(MONITOR_CONFIG=config/monitor.conf.example bash scripts/monitor.sh --simulate 84 84 89)
[[ $(grep -c 'level=INFO' <<< "$out") == 3 ]]
ok below-thresholds
if bash scripts/monitor.sh --simulate 101 0 0 >/dev/null 2>&1; then exit 1; fi
ok rejects-invalid-simulation
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf 'CPU_THRESHOLD=0\n' > "$tmp/invalid.conf"
if MONITOR_CONFIG="$tmp/invalid.conf" bash scripts/monitor.sh --once >/dev/null 2>&1; then exit 1; fi
ok rejects-invalid-config
# Deliberately literal shell syntax to verify config is never evaluated.
# shellcheck disable=SC2016
printf 'CPU_THRESHOLD=$(touch %s/pwned)\n' "$tmp" > "$tmp/injection.conf"
if MONITOR_CONFIG="$tmp/injection.conf" bash scripts/monitor.sh --once >/dev/null 2>&1; then exit 1; fi
[[ ! -e $tmp/pwned ]]
ok config-is-not-executed
out=$(MONITOR_CONFIG=config/monitor.conf.example bash scripts/monitor.sh --once)
[[ $(grep -c 'source=real' <<< "$out") == 3 ]]
for metric in cpu memory disk; do grep -Eq "metric=$metric usage_pct=[0-9]+ threshold_pct=" <<< "$out"; done
printf '%s\n' "$out"
ok real-linux-sample
# A long-lived compiler child must not retain the provisioning flock.
(
    source scripts/lib/common.sh
    AUDIT_LOG="$tmp/audit.log"
    exec 9>"$tmp/lock"
    flock -n 9
    if flock -n "$tmp/lock" true; then exit 1; fi
    step spawn sh -c 'sleep 30 >/dev/null 2>&1 & echo $! > "$1"' sh "$tmp/child-pid"
    child=$(cat "$tmp/child-pid")
    trap 'kill "$child" 2>/dev/null || true' EXIT
    exec 9>&-
    flock -n "$tmp/lock" true
)
ok child-does-not-inherit-provision-lock
printf 'Resultado: %s testes passaram. Provisionamento/systemd/HTTP na VM não executados.\n' "$passed"
