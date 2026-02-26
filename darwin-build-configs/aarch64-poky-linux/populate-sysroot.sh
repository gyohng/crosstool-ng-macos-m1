#!/usr/bin/env bash
set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <user@host>"
    echo "  e.g. $0 root@192.168.1.204"
    exit 1
fi

TARGET_HOST="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLCHAIN_PREFIX="$(basename "${SCRIPT_DIR}")"
SYSROOT="${SCRIPT_DIR}/${TOOLCHAIN_PREFIX}/sysroot"

if [ ! -d "${SYSROOT}" ]; then
    echo "Error: sysroot not found at ${SYSROOT}"
    exit 1
fi

echo "=== Populating sysroot from ${TARGET_HOST} ==="
echo "=== Sysroot: ${SYSROOT} ==="
echo ""

# ── 1. Headers (/usr/include) ──────────────────────────────────────────
echo "[1/5] Syncing /usr/include/ ..."
ssh "${TARGET_HOST}" "tar czf - -C / usr/include" | \
    tar xzf - -C "${SYSROOT}"
echo "      done."

# ── 2. Runtime libs from /lib ──────────────────────────────────────────
echo "[2/5] Syncing /lib/ (runtime libs) ..."
ssh "${TARGET_HOST}" \
    "tar chzf - -C / \
     --exclude='lib/firmware' --exclude='lib/modules' \
     --exclude='lib/systemd' --exclude='lib/udev' --exclude='lib/security' \
     --exclude='lib/modprobe.d' --exclude='lib/depmod.d' \
     --exclude='lib/tmpfiles.d' --exclude='lib/sysctl.d' \
     lib" | \
    tar xzf - -C "${SYSROOT}"
echo "      done."

# ── 3. /usr/lib: dev libs, pkgconfig, cmake, arch headers ─────────────
#    Exclude large runtime-only trees, keep lib-internal include dirs
#    (e.g. glib-2.0/include, dbus-1.0/include) and all .so/.a files.
echo "[3/5] Syncing /usr/lib/ ..."
ssh "${TARGET_HOST}" \
    "tar czf - -C / \
     --exclude='usr/lib/python*' --exclude='usr/lib/perl*' --exclude='usr/lib/ruby' \
     --exclude='usr/lib/gobject-introspection' \
     --exclude='usr/lib/girepository-1.0' --exclude='usr/lib/opkg' \
     --exclude='usr/lib/systemd' --exclude='usr/lib/udev' \
     --exclude='usr/lib/tmpfiles.d' --exclude='usr/lib/sysctl.d' \
     --exclude='usr/lib/locale' --exclude='usr/lib/gconv' \
     --exclude='usr/lib/NetworkManager' --exclude='usr/lib/connman' \
     --exclude='usr/lib/pam.d' --exclude='usr/lib/security' \
     --exclude='usr/lib/rpm' --exclude='usr/lib/dnf' \
     --exclude='usr/lib/bash' --exclude='usr/lib/coreutils' \
     --exclude='usr/lib/wpe-webkit*' --exclude='usr/lib/weston' \
     --exclude='usr/lib/libweston*' --exclude='usr/lib/dri' \
     --exclude='usr/lib/gallium-pipe' --exclude='usr/lib/valgrind' \
     --exclude='usr/lib/audit' \
     usr/lib" 2>/dev/null | \
    tar xzf - -C "${SYSROOT}"
echo "      done."

# ── 4. /usr/share/pkgconfig ───────────────────────────────────────────
echo "[4/5] Syncing /usr/share/pkgconfig/ ..."
mkdir -p "${SYSROOT}/usr/share/pkgconfig"
ssh "${TARGET_HOST}" "tar czf - -C / usr/share/pkgconfig 2>/dev/null" | \
    tar xzf - -C "${SYSROOT}" 2>/dev/null || true
echo "      done."

# ── 5. /usr/share/aclocal (autotools macros) ──────────────────────────
echo "[5/5] Syncing /usr/share/aclocal/ ..."
mkdir -p "${SYSROOT}/usr/share/aclocal"
ssh "${TARGET_HOST}" "tar czf - -C / usr/share/aclocal 2>/dev/null" | \
    tar xzf - -C "${SYSROOT}" 2>/dev/null || true
echo "      done."

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "=== Sysroot population complete ==="
echo ""
echo "Headers:   $(find "${SYSROOT}/usr/include" -type f | wc -l | tr -d ' ') files"
echo "Libs:      $(find "${SYSROOT}/usr/lib" "${SYSROOT}/lib" \( -name '*.so' -o -name '*.so.*' -o -name '*.a' \) 2>/dev/null | wc -l | tr -d ' ') files"
echo "Pkgconfig: $(find "${SYSROOT}" -name '*.pc' 2>/dev/null | wc -l | tr -d ' ') files"
echo "CMake:     $(find "${SYSROOT}/usr/lib/cmake" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo ""
echo "Total sysroot size: $(du -sh "${SYSROOT}" | cut -f1)"
