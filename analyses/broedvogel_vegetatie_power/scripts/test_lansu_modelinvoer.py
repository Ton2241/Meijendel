#!/usr/bin/env python3

import importlib.util
from pathlib import Path
import unittest

import numpy as np


SCRIPT = Path(__file__).with_name("lansu_modelinvoer.py")


def load_module():
    spec = importlib.util.spec_from_file_location("lansu_modelinvoer", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class LansuModelinvoerTest(unittest.TestCase):
    def test_channel_contract_matches_published_configuration(self):
        module = load_module()

        self.assertEqual(
            module.CHANNELS,
            (
                "red",
                "green",
                "blue",
                "near_infrared",
                "dsm_cm",
                "canopy_height_cm",
                "distance_to_sea_m",
            ),
        )
        self.assertEqual(module.CLASS_ORDER[-1], "Other")
        self.assertEqual(len(module.CLASS_ORDER), 7)

    def test_grid_is_aligned_to_complete_model_tiles(self):
        module = load_module()

        grid = module.model_grid((82388.87, 461966.75, 84367.93, 463970.09))

        self.assertEqual(grid.bounds, (81920.0, 461824.0, 84480.0, 464384.0))
        self.assertEqual(grid.width, 10240)
        self.assertEqual(grid.height, 10240)
        self.assertEqual(grid.width % module.MODEL_TILE_PIXELS, 0)
        self.assertEqual(grid.height % module.MODEL_TILE_PIXELS, 0)

    def test_elevation_channels_use_centimetres_and_preserve_nodata(self):
        module = load_module()
        dsm = np.array([[4.80, 2.00, np.nan], [1.00, 700.00, 2.00]])
        dtm = np.array([[4.10, 2.30, 1.00], [np.nan, 1.00, 1.00]])

        dsm_cm, canopy_cm = module.elevation_channels(dsm, dtm)

        self.assertEqual(dsm_cm[0, 0], 480)
        self.assertEqual(canopy_cm[0, 0], 70)
        self.assertEqual(canopy_cm[0, 1], 0)
        self.assertEqual(dsm_cm[0, 2], module.NODATA_UINT16)
        self.assertEqual(canopy_cm[1, 0], module.NODATA_UINT16)
        self.assertEqual(dsm_cm[1, 1], module.NODATA_UINT16)

    def test_near_infrared_is_first_cir_band(self):
        module = load_module()
        cir = np.array(
            [
                [[101, 102]],
                [[51, 52]],
                [[31, 32]],
            ],
            dtype=np.uint8,
        )

        nir = module.near_infrared(cir)

        np.testing.assert_array_equal(nir, np.array([[101, 102]], dtype=np.uint8))

    def test_checkpoint_contract_rejects_wrong_channel_or_class_count(self):
        module = load_module()

        self.assertEqual(module.checkpoint_contract(7, 7), [])
        self.assertIn("7 invoerkanalen", module.checkpoint_contract(3, 7)[0])
        self.assertIn("7 uitvoerklassen", module.checkpoint_contract(7, 6)[0])

    def test_checkpoint_shapes_are_read_from_first_and_last_convolution(self):
        module = load_module()
        state = {
            "encoder.enc_blocks.0.conv1.weight": np.empty((64, 7, 3, 3)),
            "head.weight": np.empty((7, 64, 1, 1)),
        }

        result = module.infer_checkpoint_contract(state)

        self.assertEqual(result["invoerkanalen"], 7)
        self.assertEqual(result["uitvoerklassen"], 7)
        self.assertEqual(result["problemen"], [])


if __name__ == "__main__":
    unittest.main()
