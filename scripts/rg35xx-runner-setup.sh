#!/bin/bash
# Prepara un servidor Ubuntu/Debian x86_64 nou per compilar el target
# atm7039 (RG35XX original) amb GitHub Actions.
#
# Instal·la Docker i un "self-hosted runner" de GitHub Actions lligat al
# repositori, amb l'etiqueta "rg35xx-builder". A partir d'aquí, cada push a
# la branca build-rg35xx compila la imatge en aquest servidor.
#
# Ús (com a root, al servidor):
#   curl -fsSL https://raw.githubusercontent.com/KiritoKurai/knulli-linux/rg35xx-atm7039/scripts/rg35xx-runner-setup.sh \
#     | bash -s -- <TOKEN>
#
# <TOKEN> és el que surt a GitHub > Settings > Actions > Runners >
# New self-hosted runner (a la comanda ./config.sh ... --token XXXX).
# Caduca al cap d'una hora.
set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
    echo "Falta el token del runner (mira la capçalera d'aquest script)." >&2
    exit 1
fi
TOKEN="$1"
REPO_URL="${REPO_URL:-https://github.com/KiritoKurai/knulli-linux}"
RUNNER_USER=runner
RUNNER_DIR="/home/${RUNNER_USER}/actions-runner"
WORK_ROOT=/srv/knulli

if [ "$(id -u)" -ne 0 ]; then
    echo "Executa'l com a root (o amb sudo)." >&2
    exit 1
fi
if [ "$(uname -m)" != "x86_64" ]; then
    echo "Aquest script només suporta servidors x86_64." >&2
    exit 1
fi

echo "==> Paquets del sistema i Docker"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io git curl jq ca-certificates >/dev/null
systemctl enable --now docker

echo "==> Usuari ${RUNNER_USER}"
id "${RUNNER_USER}" >/dev/null 2>&1 || useradd -m -s /bin/bash "${RUNNER_USER}"
usermod -aG docker "${RUNNER_USER}"
mkdir -p "${WORK_ROOT}"
chown "${RUNNER_USER}:${RUNNER_USER}" "${WORK_ROOT}"

echo "==> GitHub Actions runner"
VER="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)"
VER="${VER#v}"
mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"
if [ ! -x ./config.sh ]; then
    curl -fsSL -o runner.tgz \
        "https://github.com/actions/runner/releases/download/v${VER}/actions-runner-linux-x64-${VER}.tar.gz"
    tar xzf runner.tgz
    rm runner.tgz
fi
chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"
./bin/installdependencies.sh >/dev/null

if [ -f .runner ]; then
    ./svc.sh stop || true
    ./svc.sh uninstall || true
fi
sudo -u "${RUNNER_USER}" ./config.sh --unattended --replace \
    --url "${REPO_URL}" --token "${TOKEN}" \
    --name "$(hostname)" --labels rg35xx-builder
./svc.sh install "${RUNNER_USER}"
./svc.sh start

echo
echo "Fet. El runner '$(hostname)' està en marxa."
echo "Comprova-ho a ${REPO_URL}/settings/actions/runners (ha de sortir 'Idle')."
