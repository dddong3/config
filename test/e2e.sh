#!/bin/bash
set -eo pipefail

# E2E test: Stage 1 only (base install, no secrets/auth)
# Tests setup.sh on a clean macOS VM using Tart

VM_NAME="dotfiles-test"
VM_USER="admin"
VM_PASS="admin"
VM_IMAGE="ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
REPO_URL="https://github.com/dddong3/config.git"
LOG="/tmp/dotfiles-e2e.log"

echo "=== Dotfiles E2E Test (Stage 1) ==="
echo "Repo: $REPO_URL"
echo "VM:   $VM_NAME ($VM_IMAGE)"
echo ""

# ── Prerequisites ──
command -v tart &>/dev/null || { echo "Error: tart not found. Run: brew install cirruslabs/cli/tart"; exit 1; }
command -v sshpass &>/dev/null || { echo "Error: sshpass not found. Run: brew install sshpass"; exit 1; }

cleanup() {
  echo "Cleaning up..."
  tart stop "$VM_NAME" 2>/dev/null || true
  tart delete "$VM_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# ── 1. Restore VM to clean state ──
echo "[1] Restoring VM to clean state..."
tart stop "$VM_NAME" 2>/dev/null || true
tart delete "$VM_NAME" 2>/dev/null || true
tart clone "$VM_IMAGE" "$VM_NAME"

# ── 2. Start VM ──
echo "[2] Starting VM..."
tart run "$VM_NAME" --no-graphics &
VM_PID=$!

# ── 3. Wait for SSH ──
echo "[3] Waiting for SSH (up to 5 min)..."
VM_IP=""
SSH_READY=false
for i in $(seq 1 60); do
  VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || true)
  if [ -n "$VM_IP" ]; then
    if SSHPASS="$VM_PASS" sshpass -e ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
       "$VM_USER@$VM_IP" true 2>/dev/null; then
      echo "  SSH ready at $VM_IP"
      SSH_READY=true
      break
    fi
  fi
  sleep 5
done
$SSH_READY || { echo "Error: VM did not become reachable via SSH"; exit 1; }

export SSHPASS="$VM_PASS"
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no $VM_USER@$VM_IP"

# ── 4. Configure NOPASSWD sudo ──
echo "[4] Configuring passwordless sudo..."
$SSH "echo '$VM_PASS' | sudo -S bash -c 'echo \"$VM_USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$VM_USER'"
$SSH "sudo systemsetup -setremotelogin on 2>/dev/null || true"

# ── 5. Clone repo inside VM ──
echo "[5] Cloning repo inside VM..."
$SSH "git clone $REPO_URL ~/config"

# ── 6. Run setup.sh (Stage 1 only) ──
echo "[6] Running setup.sh inside VM..."
echo "    (this may take 10-15 minutes for brew installs)"
echo ""
$SSH "cd ~/config && ./setup.sh" 2>&1 | tee "$LOG"

# ── 7. Results ──
echo ""
echo "==============================="
echo "=== E2E Test Results ==="
echo "==============================="
echo ""

# Show all verify results
grep -E '(✓|✗|Result:)' "$LOG" || true

# Expected failures after Stage 1 (no secrets/SSH key yet)
EXPECTED_FAILS=("SSH key")
echo ""
echo "Note: '${EXPECTED_FAILS[*]}' is expected to fail (requires Stage 2: bw-setup.sh)"

echo ""
TOTAL_FAIL=$(grep -c '✗' "$LOG" || true)
UNEXPECTED=0
while IFS= read -r line; do
  match=false
  for exp in "${EXPECTED_FAILS[@]}"; do
    if echo "$line" | grep -qF "$exp"; then
      match=true
      break
    fi
  done
  if [ "$match" = false ]; then
    UNEXPECTED=$((UNEXPECTED+1))
  fi
done < <(grep '✗' "$LOG" || true)

if [ "$UNEXPECTED" -eq 0 ]; then
  echo "E2E TEST PASSED ($TOTAL_FAIL expected failure(s))"
  exit 0
else
  echo "E2E TEST FAILED ($UNEXPECTED unexpected failure(s))"
  echo "Full log: $LOG"
  exit 1
fi
