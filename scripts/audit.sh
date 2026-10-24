#!/bin/sh
set -u

section() {
    printf '\n== %s ==\n' "$1"
}

section "CVE scope"
printf 'CVE_ID=%s\n' "${CVE_ID:-UNSET}"
printf 'AUDIT_FOCUS=%s\n' "${AUDIT_FOCUS:-general}"

section "Identity and kernel"
printf 'UID=%s\n' "$(id -u)"
printf 'GID=%s\n' "$(id -g)"
printf 'KERNEL_RELEASE=%s\n' "$(uname -r)"
printf 'KERNEL_VERSION=%s\n' "$(uname -v)"

section "Process security"
grep -E '^(NoNewPrivs|Seccomp|Cap(Inh|Prm|Eff|Bnd|Amb)):' /proc/self/status || true
if command -v capsh >/dev/null 2>&1; then
    capsh --decode="$(awk '/^CapEff:/{print $2}' /proc/self/status)" 2>/dev/null || true
fi

section "User and network namespaces"
printf 'UID_MAP:\n'
cat /proc/self/uid_map 2>/dev/null || true
for ns in user net mnt pid; do
    printf '%s_NS=%s\n' "$ns" "$(readlink "/proc/self/ns/$ns" 2>/dev/null || printf unavailable)"
done
for sysctl in /proc/sys/kernel/unprivileged_userns_clone /proc/sys/user/max_user_namespaces; do
    if [ -r "$sysctl" ]; then
        printf '%s=%s\n' "$sysctl" "$(cat "$sysctl")"
    fi
done
if command -v unshare >/dev/null 2>&1; then
    if unshare -U true 2>/dev/null; then
        printf 'USERNS_CREATE=OK\n'
    else
        printf 'USERNS_CREATE=FAIL\n'
    fi
    if unshare -Urn true 2>/dev/null; then
        printf 'USERNETNS_CREATE=OK\n'
    else
        printf 'USERNETNS_CREATE=FAIL\n'
    fi
else
    printf 'USERNS_CREATE=UNAVAILABLE (unshare missing)\n'
fi

section "Cgroups and mounts"
printf 'CGROUP_FS=%s\n' "$(stat -fc %T /sys/fs/cgroup 2>/dev/null || printf unavailable)"
grep cgroup /proc/self/mountinfo 2>/dev/null || printf 'CGROUP_MOUNTS=none-visible\n'
if command -v findmnt >/dev/null 2>&1 && [ -e /usr/bin/su ]; then
    findmnt -T /usr/bin/su -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null || true
fi
for file in /usr/bin/su /usr/bin/passwd /usr/bin/sudo /usr/bin/mount; do
    if [ -r "$file" ] && [ -u "$file" ]; then
        printf 'READABLE_SETUID=%s\n' "$file"
    fi
done

section "containerd-shim visibility"
if [ -r /proc/net/unix ]; then
    shim_lines="$(grep -a containerd-shim /proc/net/unix 2>/dev/null || true)"
    if [ -n "$shim_lines" ]; then
        printf 'CONTAINERD_SHIM_SOCKET=VISIBLE\n%s\n' "$shim_lines"
    else
        printf 'CONTAINERD_SHIM_SOCKET=NOT_VISIBLE\n'
    fi
fi

section "AF_ALG and AEAD reachability"
python3 /opt/lab/scripts/af_alg_probe.py
if grep -E 'algif_aead|authencesn' /proc/modules /proc/crypto 2>/dev/null; then
    printf 'COPY_FAIL_MODULE_HINT=VISIBLE\n'
else
    printf 'COPY_FAIL_MODULE_HINT=NOT_VISIBLE (not sufficient to exclude risk)\n'
fi

section "AF_PACKET reachability"
python3 - <<'PY'
import socket

try:
    sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, 0)
    print("AF_PACKET_SOCKET=OK")
    sock.close()
except OSError as exc:
    print(f"AF_PACKET_SOCKET=FAIL errno={exc.errno} ({exc.strerror})")
PY

section "Netfilter read-only query"
if command -v nft >/dev/null 2>&1; then
    if nft list ruleset >/dev/null 2>&1; then
        printf 'NFT_RULESET_READ=OK\n'
    else
        printf 'NFT_RULESET_READ=FAIL\n'
    fi
else
    printf 'NFT_RULESET_READ=UNAVAILABLE (nft missing)\n'
fi

section "Scope"
printf '%s\n' 'AUDIT_ONLY=No vulnerability trigger or file modification was performed.'
printf '%s\n' 'PATCH_STATUS=Confirm against the host distribution security advisory.'
