#!/usr/bin/env bash
# Host Ubuntu: inicia QEMU/KVM. Só altera a rede da VM convidada descartável.
set -Eeuo pipefail
cd -- "$(dirname -- "$0")/.."
repo=$PWD
state=$(mktemp -d)
mkdir -p evidence/raw
qemu_pid=''
cleanup() {
    if [[ -n $qemu_pid ]]; then kill "$qemu_pid" 2>/dev/null || true; wait "$qemu_pid" 2>/dev/null || true; fi
    rm -rf -- "$state"
}
trap cleanup EXIT
sudo apt-get update
sudo apt-get install -y qemu-system-x86 qemu-utils cloud-image-utils ubuntu-cloudimage-keyring
base=https://cloud-images.ubuntu.com/noble/current
for name in SHA256SUMS SHA256SUMS.gpg noble-server-cloudimg-amd64.img; do
    curl --fail --location --retry 3 "$base/$name" -o "$state/$name"
done
gpgv --keyring /usr/share/keyrings/ubuntu-cloudimage-keyring.gpg "$state/SHA256SUMS.gpg" "$state/SHA256SUMS"
(cd "$state" && grep -E ' [*]?noble-server-cloudimg-amd64.img$' SHA256SUMS | sha256sum --check -)
qemu-img create -f qcow2 -F qcow2 -b "$state/noble-server-cloudimg-amd64.img" "$state/disk.qcow2" 25G
ssh-keygen -q -t ed25519 -N '' -f "$state/key"
{
    printf '#cloud-config\nusers:\n  - name: ubuntu\n    groups: [sudo]\n    sudo: "ALL=(ALL) NOPASSWD:ALL"\n    shell: /bin/bash\n    ssh_authorized_keys:\n      - '
    cat "$state/key.pub"
    printf 'ssh_pwauth: false\nwrite_files:\n  - path: /etc/alertasp-ci-vm\n    content: "disposable-qemu-test"\n'
} > "$state/user-data"
printf 'instance-id: alertasp-ci\nlocal-hostname: alertasp-ci\n' > "$state/meta-data"
cloud-localds "$state/seed.img" "$state/user-data" "$state/meta-data"
accel=tcg
cpu=max
if [[ -e /dev/kvm ]]; then
    sudo setfacl -m "u:$(id -un):rw" /dev/kvm
    accel=kvm
    cpu=host
fi
qemu-system-x86_64 -accel "$accel" -cpu "$cpu" -m 4096 -smp 2 -nographic -no-reboot \
    -drive "file=$state/disk.qcow2,if=virtio,format=qcow2" \
    -drive "file=$state/seed.img,if=virtio,format=raw" \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:18080-:8080 \
    -device virtio-net-pci,netdev=net0 > "$repo/evidence/raw/serial.log" 2>&1 &
qemu_pid=$!
ssh_args=(-i "$state/key" -p 2222 -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$state/known_hosts")
# Arguments are intentionally complete remote shell commands.
# shellcheck disable=SC2029
remote() { ssh "${ssh_args[@]}" ubuntu@127.0.0.1 "$@"; }
wait_ssh() {
    for ((i=0;i<180;i++)); do
        if remote true 2>/dev/null; then return 0; fi
        kill -0 "$qemu_pid" || return 1
        sleep 2
    done
    return 1
}
wait_ssh
remote 'sudo cloud-init status --wait'
tar --exclude=.git --exclude=evidence/raw -czf "$state/repo.tar.gz" .
scp -i "$state/key" -P 2222 -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$state/known_hosts" "$state/repo.tar.gz" ubuntu@127.0.0.1:/tmp/repo.tar.gz
remote 'mkdir -p ~/os && tar -xzf /tmp/repo.tar.gz -C ~/os'
result=0
remote 'cd ~/os && sudo bash tests/verify-vm.sh' || result=$?
remote 'sudo tar -C ~/os/evidence -czf /tmp/evidence.tar.gz raw && sudo chmod 644 /tmp/evidence.tar.gz' || true
scp -i "$state/key" -P 2222 -o "UserKnownHostsFile=$state/known_hosts" ubuntu@127.0.0.1:/tmp/evidence.tar.gz "$state/evidence.tar.gz" || true
[[ ! -f $state/evidence.tar.gz ]] || tar -xzf "$state/evidence.tar.gz" -C evidence
((result == 0)) || exit "$result"
curl --fail --silent --show-error http://127.0.0.1:18080/health
# QEMU -no-reboot encerra no reboot. Reiniciar o mesmo disco preserva os dados.
remote 'sudo reboot' || true
for ((i=0;i<30;i++)); do kill -0 "$qemu_pid" 2>/dev/null || break; sleep 1; done
wait "$qemu_pid"
qemu-system-x86_64 -accel "$accel" -cpu "$cpu" -m 4096 -smp 2 -nographic \
    -drive "file=$state/disk.qcow2,if=virtio,format=qcow2" \
    -drive "file=$state/seed.img,if=virtio,format=raw" \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:18080-:8080 \
    -device virtio-net-pci,netdev=net0 >> "$repo/evidence/raw/serial.log" 2>&1 &
qemu_pid=$!
wait_ssh
remote 'sudo systemctl is-system-running --wait' || true
remote 'cd ~/os && sudo bash tests/verify-reboot.sh'
curl --fail --silent --show-error http://127.0.0.1:18080/health
remote 'cat ~/os/evidence/raw/reboot-validation.log' > evidence/raw/reboot-validation.log
printf 'PASS full-ubuntu-vm-validation\n' | tee evidence/raw/RESULT.txt
