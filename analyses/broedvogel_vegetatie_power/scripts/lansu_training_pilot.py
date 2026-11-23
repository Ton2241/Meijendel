#!/usr/bin/env python3
"""Controleer en beproef de openbare Lansu-trainingsset.

De modelarchitectuur en gegevensafspraken volgen Lansu et al. (2025),
Zenodo-record 10.5281/zenodo.14197160, beschikbaar onder CC BY 4.0.
"""

from __future__ import annotations

import argparse
from collections import Counter
import csv
import json
from pathlib import Path
import random

import numpy as np


SPLITS = ("training", "validation", "test")
NORMALIZATION_MEAN = np.asarray(
    (68.8427, 68.4807, 61.6793, 90.5604, 480.2229, 65.1453, 660.0991),
    dtype=np.float32,
)
NORMALIZATION_STD = np.asarray(
    (67.6801, 65.3562, 59.7872, 78.8081, 659.9129, 213.4854, 924.3354),
    dtype=np.float32,
)
CLASS_ORDER = (
    "Bare_sand",
    "Shrubs",
    "Fresh_water",
    "Grass",
    "Broadl_trees",
    "Needl_trees",
    "Other",
)


def select_device(*, mps_available: bool, cuda_available: bool) -> str:
    """Kies Apple Silicon vóór CUDA en CPU."""
    if mps_available:
        return "mps"
    if cuda_available:
        return "cuda"
    return "cpu"


def seed_everything(seed: int, torch_module) -> None:
    """Zet de beschikbare toevalsgeneratoren op één vast startpunt."""
    random.seed(seed)
    np.random.seed(seed)
    torch_module.manual_seed(seed)
    if hasattr(torch_module, "mps") and hasattr(torch_module.mps, "manual_seed"):
        torch_module.mps.manual_seed(seed)
    if torch_module.cuda.is_available():
        torch_module.cuda.manual_seed_all(seed)


def build_unet(torch_module, *, input_channels: int, output_classes: int):
    """Bouw de ongewijzigde U-net-architectuur uit de openbare Lansu-code."""
    nn = torch_module.nn

    class Block(nn.Module):
        def __init__(self, in_channels: int, out_channels: int):
            super().__init__()
            self.conv1 = nn.Conv2d(in_channels, out_channels, 3)
            self.relu = nn.ReLU()
            self.conv2 = nn.Conv2d(out_channels, out_channels, 3)

        def forward(self, values):
            return self.relu(self.conv2(self.relu(self.conv1(values))))

    class UNet(nn.Module):
        def __init__(self):
            super().__init__()
            encoder_channels = (input_channels, 64, 128, 256, 512, 1024)
            decoder_channels = (1024, 512, 256, 128, 64)
            self.encoder = nn.ModuleList(
                Block(encoder_channels[index], encoder_channels[index + 1])
                for index in range(len(encoder_channels) - 1)
            )
            self.pool = nn.MaxPool2d(2)
            self.upconvs = nn.ModuleList(
                nn.ConvTranspose2d(
                    decoder_channels[index], decoder_channels[index + 1], 2, 2
                )
                for index in range(len(decoder_channels) - 1)
            )
            self.decoder = nn.ModuleList(
                Block(decoder_channels[index], decoder_channels[index + 1])
                for index in range(len(decoder_channels) - 1)
            )
            self.head = nn.Conv2d(decoder_channels[-1], output_classes, 1)

        @staticmethod
        def _center_crop(values, height: int, width: int):
            top = (values.shape[-2] - height) // 2
            left = (values.shape[-1] - width) // 2
            return values[..., top : top + height, left : left + width]

        def forward(self, values):
            features = []
            for block in self.encoder:
                values = block(values)
                features.append(values)
                values = self.pool(values)
            values = features[-1]
            for index, (upconv, block) in enumerate(zip(self.upconvs, self.decoder)):
                values = upconv(values)
                skip = self._center_crop(
                    features[-2 - index], values.shape[-2], values.shape[-1]
                )
                values = block(torch_module.cat((values, skip), dim=1))
            return self.head(values)

    return UNet()


def run_synthetic_smoke(torch_module, *, requested_device: str, seed: int) -> dict:
    """Voer één kleine rekenstap uit; dit is geen ecologische modeltraining."""
    seed_everything(seed, torch_module)
    if requested_device == "auto":
        device_name = select_device(
            mps_available=torch_module.backends.mps.is_available(),
            cuda_available=torch_module.cuda.is_available(),
        )
    else:
        device_name = requested_device
    device = torch_module.device(device_name)
    model = build_unet(torch_module, input_channels=7, output_classes=7).to(device)
    model.train()
    inputs = torch_module.randn((1, 7, 188, 188), device=device)
    targets = torch_module.randint(0, 7, (1, 4, 4), device=device)
    optimizer = torch_module.optim.SGD(model.parameters(), lr=0.001)
    loss_function = torch_module.nn.CrossEntropyLoss()
    first_parameter = next(model.parameters())
    before = first_parameter.detach().cpu().clone()
    optimizer.zero_grad()
    outputs = model(inputs)
    loss = loss_function(outputs, targets)
    loss.backward()
    optimizer.step()
    changed = not torch_module.equal(before, first_parameter.detach().cpu())
    return {
        "device": device_name,
        "seed": seed,
        "invoer_vorm": list(inputs.shape),
        "uitvoer_vorm": list(outputs.shape),
        "verlies": float(loss.detach().cpu()),
        "gewichten_gewijzigd": changed,
        "betekenis": "technische rekenproef; geen getraind habitatmodel",
    }


def run_dataset_smoke(
    torch_module,
    *,
    dataset_root: Path,
    name: str,
    requested_device: str,
    input_size: int,
    seed: int,
) -> dict:
    """Voer één trainingsstap uit op één echt openbaar beeld-maskerpaar."""
    seed_everything(seed, torch_module)
    if requested_device == "auto":
        device_name = select_device(
            mps_available=torch_module.backends.mps.is_available(),
            cuda_available=torch_module.cuda.is_available(),
        )
    else:
        device_name = requested_device
    prepared_image, prepared_mask, metadata = load_prepared_sample(
        dataset_root, name, input_size=input_size
    )
    device = torch_module.device(device_name)
    model = build_unet(torch_module, input_channels=7, output_classes=7).to(device)
    model.train()
    inputs = torch_module.from_numpy(prepared_image[np.newaxis, ...]).to(device)
    targets = torch_module.from_numpy(prepared_mask[np.newaxis, ...]).to(device)
    optimizer = torch_module.optim.SGD(model.parameters(), lr=0.001)
    loss_function = torch_module.nn.CrossEntropyLoss()
    first_parameter = next(model.parameters())
    before = first_parameter.detach().cpu().clone()
    optimizer.zero_grad()
    outputs = model(inputs)
    loss = loss_function(outputs, targets)
    loss.backward()
    optimizer.step()
    changed = not torch_module.equal(before, first_parameter.detach().cpu())
    return {
        **metadata,
        "device": device_name,
        "seed": seed,
        "model_invoer_pixels": input_size,
        "uitvoer_vorm": list(outputs.shape),
        "verlies": float(loss.detach().cpu()),
        "gewichten_gewijzigd": changed,
        "betekenis": "een technische stap; geen habitatmodel",
    }


def unet_output_size(input_size: int) -> int:
    """Bereken de uitvoermaat van het gepubliceerde U-net zonder padding."""
    size = int(input_size)
    if size < 188:
        raise ValueError("U-net-invoer is te klein; minimaal 188 pixels vereist.")
    for block in range(5):
        size -= 4
        if block < 4:
            size //= 2
    for _ in range(4):
        size = size * 2 - 4
    if size <= 0:
        raise ValueError("U-net-invoer is te klein voor een positieve uitvoermaat.")
    return size


def _center_crop(values: np.ndarray, size: int) -> np.ndarray:
    height, width = values.shape[-2:]
    if height < size or width < size:
        raise ValueError(
            f"Bronarray {height}x{width} is kleiner dan de gevraagde uitsnede {size}."
        )
    top = (height - size) // 2
    left = (width - size) // 2
    return values[..., top : top + size, left : left + size]


def prepare_sample(
    image: np.ndarray, mask: np.ndarray, *, input_size: int
) -> tuple[np.ndarray, np.ndarray]:
    """Maak één deterministische centrumuitsnede voor de technische proef."""
    image = np.asarray(image, dtype=np.float32)
    mask = np.asarray(mask, dtype=np.int64)
    if image.ndim != 3 or image.shape[0] != len(NORMALIZATION_MEAN):
        raise ValueError("Trainingsbeeld moet zeven banden in de eerste dimensie bevatten.")
    if mask.ndim != 2 or mask.shape != image.shape[1:]:
        raise ValueError("Trainingsmasker moet dezelfde hoogte en breedte als het beeld hebben.")
    output_size = unet_output_size(input_size)
    image_crop = _center_crop(image, input_size)
    mask_crop = _center_crop(mask, output_size)
    normalized = (
        image_crop - NORMALIZATION_MEAN[:, np.newaxis, np.newaxis]
    ) / NORMALIZATION_STD[:, np.newaxis, np.newaxis]
    return normalized.astype(np.float32), mask_crop.astype(np.int64)


def load_prepared_sample(
    root: Path, name: str, *, input_size: int
) -> tuple[np.ndarray, np.ndarray, dict]:
    """Lees één openbaar trainingspaar en maak de deterministische proefuitsnede."""
    try:
        import tifffile
    except ImportError as exc:
        raise RuntimeError("tifffile ontbreekt in de trainingsomgeving.") from exc
    root = Path(root)
    image = tifffile.imread(_tiff_path(root / "images", name))
    mask = tifffile.imread(_tiff_path(root / "masks", name))
    if image.ndim == 3 and image.shape[-1] == len(NORMALIZATION_MEAN):
        image = np.moveaxis(image, -1, 0)
    classes = sorted(int(value) for value in np.unique(mask))
    invalid = [value for value in classes if value < 0 or value >= len(CLASS_ORDER)]
    if invalid:
        raise ValueError(f"Trainingsmasker bevat onbekende klassewaarden: {invalid}")
    prepared_image, prepared_mask = prepare_sample(image, mask, input_size=input_size)
    return prepared_image, prepared_mask, {
        "bestandsnaam": name,
        "bronbeeld_vorm": list(image.shape),
        "bronmasker_vorm": list(mask.shape),
        "bronmasker_klassen": classes,
        "invoer_vorm": list(prepared_image.shape),
        "doel_vorm": list(prepared_mask.shape),
        "doelmasker_klassen": sorted(int(value) for value in np.unique(prepared_mask)),
    }


def _read_split(path: Path) -> list[str]:
    with path.open(newline="") as handle:
        rows = csv.DictReader(handle)
        if rows.fieldnames is None or "file" not in rows.fieldnames:
            raise ValueError(f"Splitbestand mist kolom 'file': {path}")
        return [row["file"].strip() for row in rows if row.get("file", "").strip()]


def _tiff_path(directory: Path, name: str) -> Path:
    return directory / (name if name.lower().endswith((".tif", ".tiff")) else f"{name}.tiff")


def audit_dataset(root: Path) -> dict:
    """Controleer beeld-maskerparen en, indien aanwezig, de officiële splits."""
    root = Path(root)
    images = root / "images"
    masks = root / "masks"
    sets = root / "sets" / "standard_2048"
    image_names = sorted(path.name for path in images.glob("*.tif*"))
    mask_names = sorted(path.name for path in masks.glob("*.tif*"))
    image_set = set(image_names)
    mask_set = set(mask_names)
    paired_names = sorted(image_set & mask_set)
    split_paths = {split: sets / f"{split}.csv" for split in SPLITS}
    missing_splits = [split for split, path in split_paths.items() if not path.is_file()]
    split_names = {
        split: _read_split(path)
        for split, path in split_paths.items()
        if path.is_file()
    }
    all_names = sorted({name for names in split_names.values() for name in names})
    missing_images = [name for name in all_names if not _tiff_path(images, name).is_file()]
    missing_masks = [name for name in all_names if not _tiff_path(masks, name).is_file()]
    memberships: dict[str, int] = {}
    for names in split_names.values():
        for name in set(names):
            memberships[name] = memberships.get(name, 0) + 1
    overlap = sorted(name for name, count in memberships.items() if count > 1)
    duplicate_within_split = {
        split: sorted({name for name in names if names.count(name) > 1})
        for split, names in split_names.items()
    }
    duplicate_within_split = {
        split: names for split, names in duplicate_within_split.items() if names
    }
    official_splits_present = not missing_splits
    usable = (
        official_splits_present
        and not missing_images
        and not missing_masks
        and not overlap
        and not duplicate_within_split
    )
    technical_pilot_usable = bool(paired_names)
    return {
        "dataset_root": str(root),
        "aantallen_bestanden": {"beelden": len(image_names), "maskers": len(mask_names)},
        "beelden_zonder_masker": sorted(image_set - mask_set),
        "maskers_zonder_beeld": sorted(mask_set - image_set),
        "aantallen": {split: len(split_names.get(split, [])) for split in SPLITS},
        "unieke_bestanden": len(all_names),
        "ontbrekende_beelden": missing_images,
        "ontbrekende_maskers": missing_masks,
        "ontbrekende_splitbestanden": missing_splits,
        "officiele_splits_aanwezig": official_splits_present,
        "split_overlap": overlap,
        "dubbel_binnen_split": duplicate_within_split,
        "eerste_bruikbare_paar": paired_names[0] if paired_names else None,
        "bruikbaar_voor_technische_pilot": technical_pilot_usable,
        "volledig_reproduceerbare_training": usable,
        "bruikbaar_voor_pilot": usable,
    }


def audit_raster_contents(root: Path) -> dict:
    """Lees alle rastermetadata en maskers en controleer het modelcontract."""
    try:
        import tifffile
    except ImportError as exc:
        raise RuntimeError("tifffile ontbreekt in de trainingsomgeving.") from exc
    root = Path(root)
    image_shapes: Counter[str] = Counter()
    mask_shapes: Counter[str] = Counter()
    image_dtypes: Counter[str] = Counter()
    mask_dtypes: Counter[str] = Counter()
    classes: set[int] = set()
    invalid: list[dict] = []
    image_paths = {path.name: path for path in (root / "images").glob("*.tif*")}
    mask_paths = {path.name: path for path in (root / "masks").glob("*.tif*")}
    for name in sorted(set(image_paths) & set(mask_paths)):
        try:
            with tifffile.TiffFile(image_paths[name]) as image_file:
                image_series = image_file.series[0]
                image_shape = tuple(int(value) for value in image_series.shape)
                image_dtype = str(image_series.dtype)
            mask = tifffile.imread(mask_paths[name])
            mask_shape = tuple(int(value) for value in mask.shape)
            mask_dtype = str(mask.dtype)
            mask_classes = {int(value) for value in np.unique(mask)}
            image_shapes["x".join(map(str, image_shape))] += 1
            mask_shapes["x".join(map(str, mask_shape))] += 1
            image_dtypes[image_dtype] += 1
            mask_dtypes[mask_dtype] += 1
            classes.update(mask_classes)
            reasons = []
            if image_shape != (len(NORMALIZATION_MEAN), 2048, 2048):
                reasons.append(f"beeldvorm={image_shape}")
            if mask_shape != (2048, 2048):
                reasons.append(f"maskervorm={mask_shape}")
            unknown = sorted(
                value for value in mask_classes if value < 0 or value >= len(CLASS_ORDER)
            )
            if unknown:
                reasons.append(f"onbekende_klassen={unknown}")
            if reasons:
                invalid.append({"bestand": name, "redenen": reasons})
        except Exception as exc:  # Bewaar bestandsnaam en concrete leesfout in de audit.
            invalid.append({"bestand": name, "redenen": [f"leesfout={exc}"]})
    return {
        "beeldvormen": dict(sorted(image_shapes.items())),
        "maskervormen": dict(sorted(mask_shapes.items())),
        "beelddatatypen": dict(sorted(image_dtypes.items())),
        "maskerdatatypen": dict(sorted(mask_dtypes.items())),
        "maskerklassen": sorted(classes),
        "ongeldige_bestanden": invalid,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    audit = subparsers.add_parser("audit", help="Controleer trainingsstructuur en splits.")
    audit.add_argument("dataset_root", type=Path)
    audit.add_argument("--inspect-rasters", action="store_true")
    audit.add_argument("--output", type=Path, required=True)
    smoke = subparsers.add_parser("smoke", help="Voer één synthetische trainingsstap uit.")
    smoke.add_argument("--device", choices=("auto", "mps", "cuda", "cpu"), default="auto")
    smoke.add_argument("--seed", type=int, default=20261123)
    smoke.add_argument("--output", type=Path, required=True)
    dataset_smoke = subparsers.add_parser(
        "dataset-smoke", help="Voer één stap uit op één openbaar beeld-maskerpaar."
    )
    dataset_smoke.add_argument("dataset_root", type=Path)
    dataset_smoke.add_argument("--name")
    dataset_smoke.add_argument("--input-size", type=int, default=316)
    dataset_smoke.add_argument(
        "--device", choices=("auto", "mps", "cuda", "cpu"), default="auto"
    )
    dataset_smoke.add_argument("--seed", type=int, default=20261123)
    dataset_smoke.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    if args.command == "audit":
        result = audit_dataset(args.dataset_root)
        if args.inspect_rasters:
            result["rasterinhoud"] = audit_raster_contents(args.dataset_root)
            if result["rasterinhoud"]["ongeldige_bestanden"]:
                result["bruikbaar_voor_technische_pilot"] = False
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        if not result["bruikbaar_voor_technische_pilot"]:
            raise SystemExit("Trainingsset bevat geen bruikbaar beeld-maskerpaar.")
    elif args.command == "smoke":
        try:
            import torch
        except ImportError as exc:
            raise SystemExit("PyTorch ontbreekt in deze trainingsomgeving.") from exc
        result = run_synthetic_smoke(torch, requested_device=args.device, seed=args.seed)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    elif args.command == "dataset-smoke":
        try:
            import torch
        except ImportError as exc:
            raise SystemExit("PyTorch ontbreekt in deze trainingsomgeving.") from exc
        name = args.name
        if not name:
            audit_result = audit_dataset(args.dataset_root)
            name = audit_result["eerste_bruikbare_paar"]
            if not name:
                raise SystemExit("Trainingsset bevat geen bruikbaar beeld-maskerpaar.")
        result = run_dataset_smoke(
            torch,
            dataset_root=args.dataset_root,
            name=name,
            requested_device=args.device,
            input_size=args.input_size,
            seed=args.seed,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
