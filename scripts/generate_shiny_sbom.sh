#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf 'Gebruik: scripts/generate_shiny_sbom.sh IMAGE UITVOER.cdx.json\n' >&2
  exit 2
fi

image="$1"
output="$2"
output_dir="$(cd "$(dirname "$output")" && pwd)"
output="$output_dir/$(basename "$output")"

[[ ! -e "$output" ]] || {
  printf 'BLOKKADE: SBOM-uitvoer bestaat al: %s\n' "$output" >&2
  exit 1
}
docker image inspect "$image" >/dev/null
docker sbom version >/dev/null

work="$(mktemp -d "${TMPDIR:-/tmp}/vwgm-shiny-sbom.XXXXXX")"
temporary_output="$(mktemp "$output_dir/.vwgm-shiny-sbom.XXXXXX")"
cleanup() {
  rm -rf -- "$work"
  if [[ -e "$temporary_output" ]]; then
    rm -f -- "$temporary_output"
  fi
}
trap cleanup EXIT

image_id="$(docker image inspect --format '{{.Id}}' "$image")"
[[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]]

docker sbom --quiet --format cyclonedx-json \
  --output "$work/base.cdx.json" "$image"
docker run --rm --platform linux/amd64 --entrypoint Rscript "$image" -e '
  packages <- installed.packages()
  write.table(
    packages[, c("Package", "Version"), drop = FALSE],
    file = stdout(), sep = "\t", row.names = FALSE, col.names = FALSE,
    quote = FALSE
  )
' > "$work/r-packages.tsv"
docker run --rm --platform linux/amd64 --entrypoint cat "$image" \
  /opt/vwgm-build/renv.lock > "$work/renv.lock"

python3 - "$work/base.cdx.json" "$work/r-packages.tsv" \
  "$work/renv.lock" "$temporary_output" "$image_id" <<'PY'
import json
import sys
from urllib.parse import quote

base_path, packages_path, lock_path, output_path, image_id = sys.argv[1:]
with open(base_path, encoding="utf-8") as handle:
    bom = json.load(handle)
with open(lock_path, encoding="utf-8") as handle:
    lock = json.load(handle)

lock_packages = lock["Packages"]
components = bom.setdefault("components", [])
known_refs = {component.get("bom-ref") for component in components}
r_count = 0

with open(packages_path, encoding="utf-8") as handle:
    for line in handle:
        name, version = line.rstrip("\n").split("\t", 1)
        purl = f"pkg:cran/{quote(name, safe='')}@{quote(version, safe='')}"
        if purl in known_refs:
            continue
        properties = [{"name": "vwg:ecosystem", "value": "R"}]
        record = lock_packages.get(name)
        if record:
            properties.append(
                {"name": "vwg:renv-source", "value": record.get("Source", "")}
            )
            if record.get("Hash"):
                properties.append(
                    {"name": "vwg:renv-hash", "value": record["Hash"]}
                )
        components.append(
            {
                "type": "library",
                "bom-ref": purl,
                "name": name,
                "version": version,
                "purl": purl,
                "properties": properties,
            }
        )
        known_refs.add(purl)
        r_count += 1

metadata = bom.setdefault("metadata", {})
metadata.setdefault("properties", []).extend(
    [
        {"name": "vwg:image-id", "value": image_id},
        {"name": "vwg:r-components-added", "value": str(r_count)},
        {
            "name": "vwg:renv-repository",
            "value": lock["R"]["Repositories"][0]["URL"],
        },
    ]
)

locked_purls = {
    f"pkg:cran/{quote(name, safe='')}@{quote(record['Version'], safe='')}"
    for name, record in lock_packages.items()
}
missing = sorted(locked_purls - known_refs)
if missing:
    raise SystemExit("Lockpackages ontbreken in SBOM: " + ", ".join(missing))
if bom.get("bomFormat") != "CycloneDX":
    raise SystemExit("SBOM is geen CycloneDX-document")

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(bom, handle, ensure_ascii=False, indent=2, sort_keys=True)
    handle.write("\n")
PY

mv "$temporary_output" "$output"
printf 'GROEN: CycloneDX-SBOM geschreven voor %s naar %s\n' "$image_id" "$output"
