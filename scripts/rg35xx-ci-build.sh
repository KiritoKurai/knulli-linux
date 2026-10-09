#!/bin/bash
# Compila el target atm7039 (RG35XX original) i publica l'estat a la
# branca build-logs del repositori, perquè es pugui seguir des de fora
# sense accedir al servidor.
#
# El crida .github/workflows/rg35xx-build.yml dins del runner. Variables:
#   GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_RUN_ID (de l'Action)
#   WORK_ROOT  (per defecte /srv/knulli): directoris persistents entre builds
#   REPORT_EVERY (per defecte 600 s): cada quant es publica el progrés
set -uo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK_ROOT="${WORK_ROOT:-/srv/knulli}"
REPORT_EVERY="${REPORT_EVERY:-600}"
LOG="${WORK_ROOT}/build.log"
LOGS_REPO="${WORK_ROOT}/build-logs"
IMG_DIR="${WORK_ROOT}/output/atm7039/images/knulli/images/rg35xx"
REMOTE="${LOGS_REMOTE:-https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git}"
START="$(date +%s)"

mkdir -p "${WORK_ROOT}/dl" "${WORK_ROOT}/output" "${WORK_ROOT}/ccache"

# --- publicació de l'estat a la branca build-logs -------------------------
init_logs_repo() {
    rm -rf "${LOGS_REPO}"
    if git clone -q --depth 1 -b build-logs "${REMOTE}" "${LOGS_REPO}" 2>/dev/null; then
        return
    fi
    git init -q -b build-logs "${LOGS_REPO}"
    git -C "${LOGS_REPO}" remote add origin "${REMOTE}"
}

report() {
    local state="$1"
    local now elapsed stage
    now="$(date +%s)"
    elapsed=$(( (now - START) / 60 ))
    stage="$(grep -a '^>>> ' "${LOG}" 2>/dev/null | tail -1)"
    {
        echo "estat:     ${state}"
        echo "commit:    ${GITHUB_SHA}"
        echo "run:       https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
        echo "inici:     $(date -u -d "@${START}" '+%Y-%m-%d %H:%M UTC')"
        echo "actualitz: $(date -u '+%Y-%m-%d %H:%M UTC')"
        echo "minuts:    ${elapsed}"
        echo "paquets:   $(grep -ac '^>>> .* Installing to target' "${LOG}" 2>/dev/null || echo 0) instal·lats"
        echo "pas:       ${stage:-(encara cap)}"
        echo "disc:      $(df -h "${WORK_ROOT}" | awk 'NR==2{print $3" usats, "$4" lliures"}')"
        if [ -d "${IMG_DIR}" ]; then
            echo "imatges:"
            ls -l "${IMG_DIR}" 2>/dev/null | sed 's/^/  /'
        fi
    } > "${LOGS_REPO}/status.txt"
    tail -n 400 "${LOG}" > "${LOGS_REPO}/tail.log" 2>/dev/null || true
    grep -anE '(^|[^a-z])(error|Error|ERROR)[: ]|\*\*\*' "${LOG}" 2>/dev/null \
        | grep -avE 'warning|-Werror|error\.(c|h|o)|_error|errors? (=|:) ?0' \
        | tail -n 200 > "${LOGS_REPO}/errors.log" || true
    git -C "${LOGS_REPO}" add -A
    git -C "${LOGS_REPO}" -c user.name="rg35xx-builder" -c user.email="builder@localhost" \
        commit -q -m "${state} (${elapsed} min)" || true
    git -C "${LOGS_REPO}" push -q origin HEAD:build-logs 2>/dev/null \
        || echo "avís: no s'ha pogut publicar l'estat" >&2
}

# --- compilació -------------------------------------------------------------
init_logs_repo
: > "${LOG}"
report "en curs"

cd "${SRC}" || exit 1
make BATCH_MODE=1 \
    DL_DIR="${WORK_ROOT}/dl" \
    OUTPUT_DIR="${WORK_ROOT}/output" \
    CCACHE_DIR="${WORK_ROOT}/ccache" \
    atm7039-build > "${LOG}" 2>&1 &
BUILD_PID=$!

while kill -0 "${BUILD_PID}" 2>/dev/null; do
    for _ in $(seq "${REPORT_EVERY}"); do
        kill -0 "${BUILD_PID}" 2>/dev/null || break
        sleep 1
    done
    kill -0 "${BUILD_PID}" 2>/dev/null && report "en curs"
done
wait "${BUILD_PID}"
RC=$?

if [ "${RC}" -eq 0 ] && ls "${IMG_DIR}"/*.img.gz >/dev/null 2>&1; then
    report "OK"
    exit 0
fi
report "ERROR (codi ${RC})"
exit 1
