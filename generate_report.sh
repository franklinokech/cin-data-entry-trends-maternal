#!/usr/bin/env bash
# ============================================================
# generate_report.sh — Maternal Data Entry Trends Monitor
# ============================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

DATE=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="${ROOT}/output"
LOG_DIR="${ROOT}/logs"
STAGING="${ROOT}/render_staging"
OUT="${OUTPUT_DIR}/kemri_monitor_${DATE}.pptx"
LATEST="${OUTPUT_DIR}/kemri_monitor_latest.pptx"
LOG="${LOG_DIR}/render_${TIMESTAMP}.log"

mkdir -p "${OUTPUT_DIR}/archive" "${LOG_DIR}"
echo "[$(date)] render started — pwd: ${ROOT}" > "${LOG}"

step() { echo -e "\n▶ $*"; echo "[$(date +%T)] ---- $*" >> "${LOG}"; }
ok()   { echo "  ✓ $*"; echo "[$(date +%T)] OK   $*" >> "${LOG}"; }
die()  { echo "  ✗ $*"; echo "[$(date +%T)] FAIL $*" >> "${LOG}";
         echo "── last 20 log lines ──"; tail -20 "${LOG}"; exit 1; }

# ── Preflight ─────────────────────────────────────────────
step "Preflight"
[[ -f "report.qmd"            ]] && ok "report.qmd"  || die "report.qmd missing"
[[ -f "assets/template.pptx"  ]] && ok "template"    || die "assets/template.pptx missing"
[[ -f "renv.lock"             ]] && ok "renv.lock"   || die "renv.lock missing"
command -v quarto  &>/dev/null && ok "quarto CLI"    || die "quarto CLI not in PATH"
command -v Rscript &>/dev/null && ok "Rscript"       || die "Rscript not in PATH"

# Verify the quarto R package is installed and can see the CLI
Rscript -e 'if (!requireNamespace("quarto", quietly = TRUE)) quit(status = 1)' \
  >> "${LOG}" 2>&1 && ok "quarto R package" || die "quarto R package missing — check renv.lock"

# ── Archive previous latest ───────────────────────────────
if [[ -f "${LATEST}" ]]; then
  step "Archiving previous report"
  cp "${LATEST}" "${OUTPUT_DIR}/archive/kemri_monitor_prev_${TIMESTAMP}.pptx"
  ok "Archived"
fi

# ── Render into a staging directory ───────────────────────
# Quarto removes its --output-dir before rendering. Pointing it at the
# bind-mounted /app/output triggers "Device or resource busy" (EBUSY),
# because you cannot unlink a mountpoint from inside the container.
# So render into /app/render_staging, then copy the result into the
# bind-mounted output directory.
#
# Note: quarto R package 1.5.1 does not expose an `output_dir` argument,
# so we pass `--output-dir` through `quarto_args`.
step "Rendering report"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"

Rscript -e '
  args <- commandArgs(trailingOnly = TRUE)
  quarto::quarto_render(
    input       = "report.qmd",
    output_file = args[1],
    quarto_args = c("--output-dir", args[2]),
    quiet       = FALSE
  )
' "kemri_monitor_${DATE}.pptx" "${STAGING}" \
  >> "${LOG}" 2>&1 && ok "Render complete" || die "Render failed — check ${LOG}"

[[ -f "${STAGING}/kemri_monitor_${DATE}.pptx" ]] \
  || die "Render produced no output file in ${STAGING}"

cp "${STAGING}/kemri_monitor_${DATE}.pptx" "${OUT}"
ok "Copied to ${OUT}"

# ── Verify & link ─────────────────────────────────────────
step "Verifying output"
[[ -f "${OUT}" ]] || die "Output file not found: ${OUT}"
SIZE=$(du -sh "${OUT}" | cut -f1)
ok "Output: ${OUT} (${SIZE})"
cp "${OUT}" "${LATEST}"
ok "Latest: ${LATEST}"

# ── Prune old files (keep 14 archives, 30 logs) ───────────
step "Pruning"
ls -1t "${OUTPUT_DIR}/archive"/*.pptx 2>/dev/null | tail -n +15 | xargs -r rm -f
ls -1t "${LOG_DIR}"/render_*.log      2>/dev/null | tail -n +31 | xargs -r rm -f
ok "Pruning done"

echo -e "\nReport ready → ${LATEST}\n"