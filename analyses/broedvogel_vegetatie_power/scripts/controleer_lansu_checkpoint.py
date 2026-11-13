#!/usr/bin/env python3
"""Controleer ontvangen Lansu-modelgewichten tegen het gepubliceerde contract."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("lansu_modelinvoer.py")


def load_contract_module():
    spec = importlib.util.spec_from_file_location("lansu_modelinvoer", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("checkpoint", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        import torch
    except ImportError as exc:
        raise SystemExit(
            "PyTorch ontbreekt. Voer deze controle uit in de omgeving waarin het ontvangen model wordt geladen."
        ) from exc
    try:
        payload = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    except TypeError:
        payload = torch.load(args.checkpoint, map_location="cpu")
    if isinstance(payload, dict):
        state = payload.get("model_state_dict", payload.get("state_dict", payload))
    else:
        state = payload.state_dict()
    module = load_contract_module()
    result = module.infer_checkpoint_contract(state)
    result.update(
        {
            "checkpoint": str(args.checkpoint),
            "checkpoint_sha256": module.sha256(args.checkpoint),
            "bandvolgorde": list(module.CHANNELS),
            "klassevolgorde": list(module.CLASS_ORDER),
            "normalisatie_gemiddelde": list(module.NORMALIZATION_MEAN),
            "normalisatie_sd": list(module.NORMALIZATION_STD),
        }
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    if result["problemen"]:
        raise SystemExit("Checkpoint voldoet niet aan het Lansu-contract.")


if __name__ == "__main__":
    main()
