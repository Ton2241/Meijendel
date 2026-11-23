#!/usr/bin/env python3

import csv
import importlib.util
from pathlib import Path
import tempfile
import unittest

import numpy as np


SCRIPT = Path(__file__).with_name("lansu_training_pilot.py")


def load_module():
    spec = importlib.util.spec_from_file_location("lansu_training_pilot", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class LansuTrainingPilotTest(unittest.TestCase):
    def test_device_selection_prefers_apple_mps(self):
        module = load_module()

        self.assertEqual(module.select_device(mps_available=True, cuda_available=True), "mps")
        self.assertEqual(module.select_device(mps_available=False, cuda_available=True), "cuda")
        self.assertEqual(module.select_device(mps_available=False, cuda_available=False), "cpu")

    def test_unet_output_size_matches_published_and_small_pilot_sizes(self):
        module = load_module()

        self.assertEqual(module.unet_output_size(2048), 1860)
        self.assertEqual(module.unet_output_size(572), 388)
        with self.assertRaisesRegex(ValueError, "te klein"):
            module.unet_output_size(187)

    def test_dataset_audit_requires_matching_images_masks_and_disjoint_splits(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "TRAIN"
            (root / "images").mkdir(parents=True)
            (root / "masks").mkdir()
            sets = root / "sets" / "standard_2048"
            sets.mkdir(parents=True)
            for name in ("a", "b", "c"):
                (root / "images" / f"{name}.tiff").write_bytes(b"image")
                (root / "masks" / f"{name}.tiff").write_bytes(b"mask")
            for split, names in {
                "training": ("a",),
                "validation": ("b",),
                "test": ("c",),
            }.items():
                with (sets / f"{split}.csv").open("w", newline="") as handle:
                    writer = csv.DictWriter(handle, fieldnames=["file"])
                    writer.writeheader()
                    writer.writerows({"file": name} for name in names)

            audit = module.audit_dataset(root)

            self.assertEqual(audit["aantallen"], {"training": 1, "validation": 1, "test": 1})
            self.assertEqual(audit["ontbrekende_beelden"], [])
            self.assertEqual(audit["ontbrekende_maskers"], [])
            self.assertEqual(audit["split_overlap"], [])
            self.assertTrue(audit["bruikbaar_voor_pilot"])

            with (sets / "validation.csv").open("a") as handle:
                handle.write("a\n")
            audit = module.audit_dataset(root)
            self.assertEqual(audit["split_overlap"], ["a"])
            self.assertFalse(audit["bruikbaar_voor_pilot"])

    def test_dataset_audit_reports_missing_official_splits_but_allows_technical_pilot(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "data"
            (root / "images").mkdir(parents=True)
            (root / "masks").mkdir()
            for name in ("a", "b"):
                (root / "images" / f"{name}.tiff").write_bytes(b"image")
                (root / "masks" / f"{name}.tiff").write_bytes(b"mask")

            audit = module.audit_dataset(root)

            self.assertEqual(audit["aantallen_bestanden"], {"beelden": 2, "maskers": 2})
            self.assertEqual(audit["ontbrekende_splitbestanden"], list(module.SPLITS))
            self.assertFalse(audit["officiele_splits_aanwezig"])
            self.assertFalse(audit["volledig_reproduceerbare_training"])
            self.assertTrue(audit["bruikbaar_voor_technische_pilot"])
            self.assertEqual(audit["eerste_bruikbare_paar"], "a.tiff")

    def test_seed_everything_reproduces_numpy_and_torch_draws(self):
        module = load_module()
        import torch

        module.seed_everything(20261123, torch)
        first_numpy = np.random.random(3)
        first_torch = torch.rand(3)
        module.seed_everything(20261123, torch)

        np.testing.assert_array_equal(np.random.random(3), first_numpy)
        self.assertTrue(torch.equal(torch.rand(3), first_torch))

    def test_published_unet_has_expected_parameter_and_output_contract(self):
        module = load_module()
        import torch

        model = module.build_unet(torch, input_channels=7, output_classes=7)
        parameter_count = sum(parameter.numel() for parameter in model.parameters())
        output = model(torch.zeros((1, 7, 188, 188), dtype=torch.float32))

        self.assertEqual(parameter_count, 31_034_439)
        self.assertEqual(tuple(output.shape), (1, 7, 4, 4))

    def test_synthetic_smoke_performs_one_finite_training_step(self):
        module = load_module()
        import torch

        result = module.run_synthetic_smoke(torch, requested_device="cpu", seed=20261123)

        self.assertEqual(result["device"], "cpu")
        self.assertEqual(result["invoer_vorm"], [1, 7, 188, 188])
        self.assertEqual(result["uitvoer_vorm"], [1, 7, 4, 4])
        self.assertTrue(np.isfinite(result["verlies"]))
        self.assertTrue(result["gewichten_gewijzigd"])

    def test_prepare_sample_uses_matching_centre_crops_and_normalisation(self):
        module = load_module()
        image = np.zeros((7, 600, 600), dtype=np.float32)
        for channel, mean in enumerate(module.NORMALIZATION_MEAN):
            image[channel, :, :] = mean
        mask = np.arange(600 * 600, dtype=np.int64).reshape(600, 600) % 7

        prepared_image, prepared_mask = module.prepare_sample(
            image, mask, input_size=572
        )

        self.assertEqual(prepared_image.shape, (7, 572, 572))
        self.assertEqual(prepared_mask.shape, (388, 388))
        np.testing.assert_allclose(prepared_image, 0.0, atol=1e-6)
        expected = mask[106:494, 106:494]
        np.testing.assert_array_equal(prepared_mask, expected)

    def test_load_prepared_sample_reads_public_tiff_layout(self):
        module = load_module()
        import tifffile

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "images").mkdir()
            (root / "masks").mkdir()
            image = np.zeros((7, 320, 320), dtype=np.uint16)
            mask = np.zeros((320, 320), dtype=np.uint8)
            mask[100:220, 100:220] = 3
            tifffile.imwrite(root / "images" / "sample.tiff", image, compression="lzw")
            tifffile.imwrite(root / "masks" / "sample.tiff", mask, compression="lzw")

            prepared_image, prepared_mask, metadata = module.load_prepared_sample(
                root, "sample", input_size=316
            )

            self.assertEqual(prepared_image.shape, (7, 316, 316))
            self.assertEqual(prepared_mask.shape, (132, 132))
            self.assertEqual(metadata["bronbeeld_vorm"], [7, 320, 320])
            self.assertEqual(metadata["bronmasker_klassen"], [0, 3])
            self.assertEqual(metadata["doelmasker_klassen"], [0, 3])

    def test_dataset_smoke_trains_on_one_real_tiff_pair(self):
        module = load_module()
        import tifffile
        import torch

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "images").mkdir()
            (root / "masks").mkdir()
            image = np.zeros((7, 188, 188), dtype=np.uint16)
            mask = np.zeros((188, 188), dtype=np.uint8)
            mask[90:98, 90:98] = 3
            tifffile.imwrite(root / "images" / "sample.tiff", image)
            tifffile.imwrite(root / "masks" / "sample.tiff", mask)

            result = module.run_dataset_smoke(
                torch,
                dataset_root=root,
                name="sample",
                requested_device="cpu",
                input_size=188,
                seed=20261123,
            )

            self.assertEqual(result["bestandsnaam"], "sample")
            self.assertEqual(result["uitvoer_vorm"], [1, 7, 4, 4])
            self.assertTrue(np.isfinite(result["verlies"]))
            self.assertTrue(result["gewichten_gewijzigd"])
            self.assertEqual(result["betekenis"], "een technische stap; geen habitatmodel")

    def test_raster_audit_reports_shapes_dtypes_and_classes(self):
        module = load_module()
        import tifffile

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "images").mkdir()
            (root / "masks").mkdir()
            image = np.zeros((7, 2048, 2048), dtype=np.int16)
            mask = np.zeros((2048, 2048), dtype=np.uint8)
            mask[100:200, 100:200] = 6
            tifffile.imwrite(root / "images" / "sample.tiff", image, compression="lzw")
            tifffile.imwrite(root / "masks" / "sample.tiff", mask, compression="lzw")

            result = module.audit_raster_contents(root)

            self.assertEqual(result["beeldvormen"], {"7x2048x2048": 1})
            self.assertEqual(result["maskervormen"], {"2048x2048": 1})
            self.assertEqual(result["beelddatatypen"], {"int16": 1})
            self.assertEqual(result["maskerdatatypen"], {"uint8": 1})
            self.assertEqual(result["maskerklassen"], [0, 6])
            self.assertEqual(result["ongeldige_bestanden"], [])


if __name__ == "__main__":
    unittest.main()
