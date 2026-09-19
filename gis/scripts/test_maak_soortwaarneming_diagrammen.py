from pathlib import Path
import importlib.util


MODULE_PATH = Path(__file__).with_name("maak_soortwaarneming_diagrammen.py")


def load_module():
    spec = importlib.util.spec_from_file_location("soortdiagrammen", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_vogelbronregels_volgen_de_afgesproken_perioden():
    module = load_module()

    assert module.vogelbronnen_voor_jaar(1999) == ("territoria",)
    assert module.vogelbronnen_voor_jaar(2000) == ("territoria", "winterdagwaarnemingen")
    assert module.vogelbronnen_voor_jaar(2008) == ("territoria", "winterdagwaarnemingen")
    assert module.vogelbronnen_voor_jaar(2009) == (
        "broedvogeldagwaarnemingen",
        "winterdagwaarnemingen",
    )
    assert module.vogelbronnen_voor_jaar(2025) == (
        "broedvogeldagwaarnemingen",
        "winterdagwaarnemingen",
    )


def test_soortgroepen_worden_naar_de_tien_afgesproken_groepen_vertaald():
    module = load_module()

    assert module.normaliseer_soortgroep("Vaatplanten") == "Vaatplanten"
    assert module.normaliseer_soortgroep("Mossen") == "(korst)mossen"
    assert module.normaliseer_soortgroep("Korstmossen") == "(korst)mossen"
    assert module.normaliseer_soortgroep("Korstmossen|Schimmels") == "(korst)mossen"
    assert module.normaliseer_soortgroep("Dagvlinders") == "vlinders"
    assert module.normaliseer_soortgroep("Microvlinders") == "vlinders"
    assert module.normaliseer_soortgroep("Nachtvlinders") == "vlinders"
    assert module.normaliseer_soortgroep("Zoogdieren (overig)") == "zoogdieren"
    assert module.normaliseer_soortgroep("Vleermuizen") == "vleermuizen"
    assert module.normaliseer_soortgroep("Schimmels") == "paddenstoelen"
    assert module.normaliseer_soortgroep("Weekdieren") == "weekdieren"
    assert module.normaliseer_soortgroep("Reptielen") is None


def test_trendcodes_vereisen_meer_dan_alleen_voorkomensinformatie():
    module = load_module()

    assert not module.is_mogelijke_trendwaarneming("V")
    assert module.is_mogelijke_trendwaarneming("V,I")
    assert module.is_mogelijke_trendwaarneming("V,TV")
    assert module.is_mogelijke_trendwaarneming("V,TA")
    assert module.is_mogelijke_trendwaarneming("V,TK")


def test_rangschikking_is_aflopend_en_deterministisch():
    module = load_module()
    rows = [
        {"soort": "Zandhagedis", "aantal": 4},
        {"soort": "Aardbeivlinder", "aantal": 9},
        {"soort": "Bont zandoogje", "aantal": 9},
    ]

    assert [row["soort"] for row in module.sorteer_soorten(rows)] == [
        "Aardbeivlinder",
        "Bont zandoogje",
        "Zandhagedis",
    ]


def test_diagrammen_aggregeren_tot_precies_een_balk_per_soortgroep():
    module = load_module()
    rows = [
        {
            "soortgroep": "vogels",
            "soort": "Fitis",
            "totaal_waarnemingen": 12,
            "mogelijke_trendwaarnemingen": 12,
        },
        {
            "soortgroep": "vogels",
            "soort": "Koolmees",
            "totaal_waarnemingen": 8,
            "mogelijke_trendwaarnemingen": 8,
        },
        {
            "soortgroep": "vlinders",
            "soort": "Atalanta",
            "totaal_waarnemingen": 5,
            "mogelijke_trendwaarnemingen": 2,
        },
    ]

    groepen = module.aggregeer_soortgroepen(rows)

    assert groepen == [
        {
            "soortgroep": "vogels",
            "totaal_waarnemingen": 20,
            "mogelijke_trendwaarnemingen": 20,
            "aantal_taxa": 2,
        },
        {
            "soortgroep": "vlinders",
            "totaal_waarnemingen": 5,
            "mogelijke_trendwaarnemingen": 2,
            "aantal_taxa": 1,
        },
    ]
