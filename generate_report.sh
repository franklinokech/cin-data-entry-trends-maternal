#!/usr/bin/env bash
# ============================================================
# generate_report.sh — KEMRI Wellcome Trust Data Entry Monitor
# ============================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"  # activates renv via .Rprofile

DATE=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="${ROOT}/output"
LOG_DIR="${ROOT}/logs"
OUT="${OUTPUT_DIR}/kemri_monitor_${DATE}.html"
LATEST="${OUTPUT_DIR}/kemri_monitor_latest.html"
LOG="${LOG_DIR}/render_${TIMESTAMP}.log"

# ── Colours ───────────────────────────────────────────────
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[1m'; N='\033[0m'

ok()   { echo -e "${G}  ✓ $*${N}"; echo "[$(date +%T)] OK   $*" >> "${LOG}"; }
warn() { echo -e "${Y}  ⚠ $*${N}"; echo "[$(date +%T)] WARN $*" >> "${LOG}"; }
die()  { echo -e "${R}  ✗ $*${N}"; echo "[$(date +%T)] FAIL $*" >> "${LOG}"
         echo "── last 15 log lines ──"; tail -15 "${LOG}"; exit 1; }
step() { echo -e "\n${B}▶ $*${N}";  echo "[$(date +%T)] ---- $*" >> "${LOG}"; }

# ── Setup ─────────────────────────────────────────────────
mkdir -p "${OUTPUT_DIR}/archive" "${LOG_DIR}"
echo "[$(date)] render started — pwd: ${ROOT}" > "${LOG}"

# ── Preflight ─────────────────────────────────────────────
step "Preflight"
[[ -f ".env"             ]] && ok ".env"       || die ".env missing"
[[ -f "report.qmd"       ]] && ok "report.qmd" || die "report.qmd missing"
[[ -f "kemri-theme.scss" ]] && ok "theme"      || warn "theme missing"
[[ -f "renv.lock"        ]] && ok "renv.lock"  || die "renv.lock missing — is this an renv project?"
command -v Rscript &>/dev/null && ok "R found"  || die "Rscript not in PATH"
command -v quarto  &>/dev/null && ok "Quarto"   || die "quarto not in PATH"

# ── renv: restore if library out of sync ──────────────────
step "Checking renv"
Rscript -e "
  if (!requireNamespace('renv', quietly = TRUE)) {
    cat('renv not installed\n'); quit(status = 1)
  }
  st <- renv::status()
  if (!isTRUE(st\$synchronized)) {
    cat('Library out of sync — running renv::restore()\n')
    renv::restore(prompt = FALSE)
  }
  cat('renv OK\n')
" >> "${LOG}" 2>&1 && ok "renv in sync" || die "renv restore failed — check ${LOG}"


# ── Verify packages ───────────────────────────────────────
step "Checking packages"
Rscript -e "
  pkgs <- c('REDCapR','tidyverse','lubridate','dotenv','here','glue','scales')
  miss <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if (length(miss)) { cat('Missing:', paste(miss, collapse=', '), '\n'); quit(status = 1) }
  cat('All packages OK\n')
" >> "${LOG}" 2>&1 && ok "Packages OK" || die "Missing packages — run renv::restore() manually"

# ── Archive previous latest ───────────────────────────────
if [[ -f "${LATEST}" ]]; then
  step "Archiving previous report"
  cp "${LATEST}" "${OUTPUT_DIR}/archive/kemri_monitor_prev_${TIMESTAMP}.html"
  ok "Archived"
fi

# ── Render ────────────────────────────────────────────────
step "Rendering report"
quarto render report.qmd \
  --output-dir "${OUTPUT_DIR}" \
  --output "kemri_monitor_${DATE}.html" \
  >> "${LOG}" 2>&1 && ok "Render complete" || die "Render failed — check ${LOG}"

# ── Verify & link ─────────────────────────────────────────
step "Verifying output"
[[ -f "${OUT}" ]] || die "Output file not found: ${OUT}"
SIZE=$(du -sh "${OUT}" | cut -f1)
ok "Output: ${OUT} (${SIZE})"
cp "${OUT}" "${LATEST}"
ok "Latest: ${LATEST}"

# ── Prune old files (keep 14 archives, 30 logs) ───────────
step "Pruning"
ls -1t "${OUTPUT_DIR}/archive"/*.html 2>/dev/null | tail -n +15 | xargs rm -f
ls -1t "${LOG_DIR}"/render_*.log      2>/dev/null | tail -n +31 | xargs rm -f
ok "Pruning done"

# ── Done ──────────────────────────────────────────────────
echo -e "\n${G}${B}  Report ready → ${LATEST}${N}\n"

# ── Optional: open in browser ─────────────────────────────
if [[ "${1:-}" == "--open" ]]; then
  command -v xdg-open &>/dev/null && xdg-open "${LATEST}" || \
  command -v open     &>/dev/null && open     "${LATEST}" || \
  warn "Cannot open browser automatically"
fi
