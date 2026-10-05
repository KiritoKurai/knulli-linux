#!/bin/bash
# Regenera ../ramdisk.img substituint-hi els fitxers d'aquesta carpeta.
#
# ramdisk.img és el ramdisk d'estoc (estil Android) que va preparar Koriki.
# No el compila Buildroot: és un binari. Per canviar-lo, edita els fitxers
# d'aquesta carpeta (p. ex. cfw.sh) i executa aquest script. Cal: cpio,
# gzip i mkimage (u-boot-tools). S'ha d'executar com a root perquè el
# cpio conservi propietaris i nodes de dispositiu.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMG="${HERE}/../ramdisk.img"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir "${WORK}/root"
dd if="${IMG}" bs=64 skip=1 status=none | gzip -dc | (cd "${WORK}/root" && cpio -id --quiet)

for f in cfw.sh; do
    install -m 0775 -o 1000 -g 1000 "${HERE}/${f}" "${WORK}/root/${f}"
done

(cd "${WORK}/root" && find . -mindepth 1 | LC_ALL=C sort | cpio -o -H newc --quiet) | gzip -9 -n > "${WORK}/ramdisk.gz"
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n "" -d "${WORK}/ramdisk.gz" "${IMG}" >/dev/null
echo "ramdisk.img regenerat"
