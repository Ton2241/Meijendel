#!/usr/bin/env python3
import importlib.util
from pathlib import Path

import numpy as np


SCRIPT = Path(__file__).with_name("luchtfoto_classificatie.py")
SPEC = importlib.util.spec_from_file_location("luchtfoto_classificatie", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def test_height_classes_follow_ahn_contract():
    heights = np.array([-1.0, 0.0, 0.49, 0.5, 1.99, 2.0, 4.99, 5.0, np.nan])
    actual = MODULE.height_classes(heights)
    expected = np.array([0, 0, 0, 1, 1, 2, 2, 3, -1], dtype=np.int8)
    np.testing.assert_array_equal(actual, expected)


def test_spectral_features_have_stable_names_and_values():
    rgb = np.array([[[100, 200]], [[50, 100]], [[25, 50]]], dtype=np.float32)
    cir = np.array([[[150, 200]], [[100, 100]], [[50, 50]]], dtype=np.float32)
    features, names = MODULE.spectral_features(rgb, cir)
    assert names == [
        "rgb_r_fractie", "rgb_g_fractie", "rgb_b_fractie",
        "cir_nir_fractie", "cir_r_fractie", "cir_g_fractie",
        "ndvi", "helderheid_norm", "rgb_textuur", "nir_textuur",
    ]
    assert features.shape == (1, 2, 10)
    np.testing.assert_allclose(features[0, 0, 0], 100 / 175, atol=1e-6)
    np.testing.assert_allclose(features[0, 0, 6], 0.2, atol=1e-6)
    assert np.all(np.isfinite(features))


def test_confusion_metrics_report_all_classes_including_missing_predictions():
    truth = np.array([0, 0, 1, 1, 2, 2, 3, 3])
    predicted = np.array([0, 0, 0, 1, 2, 2, 2, 2])
    metrics, rows = MODULE.classification_metrics(truth, predicted)
    assert metrics["n"] == 8
    assert metrics["accuracy"] == 5 / 8
    assert len(rows) == 4
    tree = next(row for row in rows if row["klasse"] == "boom")
    assert tree["recall"] == 0.0


def test_plot_shares_preserve_zero_classes():
    classes = np.array([[0, 0], [2, 3]], dtype=np.int8)
    plot_ids = np.array([[10, 10], [10, 20]], dtype=np.int32)
    rows = MODULE.aggregate_plot_shares(classes, plot_ids, [10, 20])
    plot10 = {row["klasse"]: row["aandeel"] for row in rows if row["plot_id"] == 10}
    assert plot10 == {"open": 2 / 3, "laag": 0.0, "struweel": 1 / 3, "boom": 0.0}
    plot20 = {row["klasse"]: row["aandeel"] for row in rows if row["plot_id"] == 20}
    assert plot20["boom"] == 1.0


if __name__ == "__main__":
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            value()
    print("OK: luchtfoto-classificatiecontracten")
