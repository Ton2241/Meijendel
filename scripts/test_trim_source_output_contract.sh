#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Rscript "$repo/R/check_trim_source_output_contract.R" "$repo"
