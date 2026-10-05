# Anbernic RG35XX original (Actions ATM7039)

Target de Knulli per a l'RG35XX de 2023 (un sol USB-C, xip Actions
ATM7039S, 256 MB de RAM). Ve del treball de Koriki / Batocera Lite.

## Com arrenca

La imatge **no** fa servir el kernel que compila Buildroot. A la partició
d'arrencada s'hi copien binaris precompilats d'aquesta carpeta:

| Fitxer | Què és |
| --- | --- |
| `uImage` | Kernel 3.10.37 precompilat (Linaro GCC 4.9, desembre 2023) |
| `kernel.dtb`, `2100mAh-gpu.dtb`, `2600mAh-gpu.dtb` | Device trees segons bateria |
| `ramdisk.img` | Ramdisk d'estoc; munta el rootfs i llança `/etc/init.d/rcS` |
| `bootloader.img`, `u-boot-dtb.img` | Bootloader d'estoc |

Buildroot sí que compila el kernel (`rg35xx-cfw/s500_kernel`, branca
`rg35xx`), però només per obtenir-ne els **mòduls** (GPU `pvrsrvkm`,
botons `gpio_keys_polled`, bateria `atc260x_cap_gauge`...), que van al
rootfs i s'han de carregar sobre el `uImage` precompilat. Tots dos
comparteixen vermagic (`3.10.37 SMP preempt mod_unload ARMv7 p2v8`) i
config base.

El ramdisk munta `boot/knulli`. Si troba `boot/knulli.update` (la imatge
nova o una actualització) primer el renombra. Si no hi ha `boot/knulli`,
prova `boot/batocera` (targetes antigues de Koriki).

## Canvis respecte a Knulli upstream

- `patches/linux/0006`–`0009`: el kernel 3.10 no compilava amb GCC 13 /
  binutils actuals (dtc, `put_user`, flags de secció, `-Werror` als drivers
  de fabricant).
- `linux-defconfig-fragment.config`: activa `gpio_keys_polled` (els botons).
- `ramdisk/`: el ramdisk ara arrenca el rootfs de Knulli.
- `package/system/knulli-atm7039-fixes`: `python-evdev` amb capçaleres 3.10.
- `configs/knulli-atm7039.board`: FPU NEON, com feia Koriki.

## Compilar

Cal Docker, ~100 GB lliures i moltes hores (millor 8 nuclis o més):

```sh
git clone --recursive -b rg35xx-atm7039 https://github.com/KiritoKurai/knulli-linux.git
cd knulli-linux
make atm7039-build
```

La imatge surt a `output/atm7039/images/knulli/images/rg35xx/` (`knulli-*.img.gz`; balenaEtcher l'accepta comprimida). Grava-la en una microSD
de **recanvi** (no la teva TF1 original) amb balenaEtcher.

## Modificar el ramdisk

Edita els fitxers de `ramdisk/` i executa `ramdisk/rebuild-ramdisk.sh`
com a root (cal `cpio`, `gzip` i `mkimage`).
