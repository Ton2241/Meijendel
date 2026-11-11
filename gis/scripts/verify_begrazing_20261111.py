#!/usr/bin/env python3
"""Controleer de begrazingsactualisering van 11 november 2026."""

from __future__ import annotations

import argparse
import subprocess


MYSQL = "/usr/local/mysql/bin/mysql"


def query(args: argparse.Namespace, sql: str) -> str:
    command = [MYSQL]
    if args.socket:
        command.extend(["--no-defaults", "--protocol=SOCKET", f"--socket={args.socket}", "-uroot"])
    else:
        command.extend(["--login-path=meijendel_root", "--host=127.0.0.1", "--protocol=TCP"])
    command.extend(["--batch", "--skip-column-names"])
    command.append(args.database)
    result = subprocess.run(command, input=sql, text=True, capture_output=True, check=False)
    if result.returncode:
        raise AssertionError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def scalar(args: argparse.Namespace, sql: str) -> int:
    return int(query(args, sql))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--socket")
    args = parser.parse_args()

    assert scalar(args, """
      SELECT COUNT(*) FROM maatregel_bron
      WHERE zotero_item_key IN ('UNQKQA7F','2DTPDE3F','EAZMT3DN','2LJHNLXU','8BPDBYC5','I3QJJ4ID','U5HPG8GI');
    """) == 7
    assert scalar(args, """
      SELECT COUNT(*) FROM maatregel_bron
      WHERE (bron_code='zotero_begrazing_2008' AND titel='Integrale begrazing door vee in Meijendel')
         OR (bron_code='zotero_begrazing_2012' AND titel='Twintig jaar paarden en koeien in Meijendel, een panacee voor alle kwalen?');
    """) == 2
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_bron WHERE bron_code='handmatig_begrazing_m74_20261111' AND brontype_code='handmatige_registratie';") == 1

    assert scalar(args, """
      SELECT COUNT(*) FROM maatregel_uitvoering
      WHERE uitvoering_code='begrazing_kijfhoek_bierlap_1990'
        AND datum_vanaf='1990-09-29' AND datum_precisie='dag'
        AND datum_tot IS NULL AND uitvoering_status_code='in_uitvoering';
    """) == 1
    assert scalar(args, """
      SELECT COUNT(*) FROM maatregel_uitvoering
      WHERE uitvoering_code='begrazing_m74_1996'
        AND datum_vanaf='1996-01-01' AND datum_tot IS NULL
        AND uitvoering_status_code='in_uitvoering';
    """) == 1
    assert query(args, """
      SELECT GROUP_CONCAT(p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ',')
      FROM maatregel_plot_koppeling pk
      JOIN maatregel_uitvoering u USING (uitvoering_id)
      JOIN plots p USING (plot_id)
      WHERE u.uitvoering_code='begrazing_m74_1996';
    """) == "M74"
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_uitvoering WHERE uitvoering_code='begrazing_meeuwenhoek_voor_2008';") == 0
    assert query(args, """
      SELECT GROUP_CONCAT(p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ',')
      FROM maatregel_plot_koppeling pk
      JOIN maatregel_uitvoering u USING (uitvoering_id)
      JOIN plots p USING (plot_id)
      WHERE u.uitvoering_code='begrazing_meeuwenhoek_2004';
    """) == "M10-12-76,M12a,M73,M75"
    assert query(args, """
      SELECT GROUP_CONCAT(DISTINCT p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ',')
      FROM maatregel_plot_koppeling pk
      JOIN maatregel_uitvoering u USING (uitvoering_id)
      JOIN plots p USING (plot_id)
      WHERE u.uitvoering_code IN ('begrazing_m74_1996','begrazing_meeuwenhoek_2004');
    """) == "M10-12-76,M12a,M73,M74,M75"

    assert scalar(args, "SELECT COUNT(*) FROM maatregel_uitvoering_jaar j JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_22h_aanvullend_beheer';") == 1
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_uitvoering_jaar j JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_22h_aanvullend_beheer' AND j.jaar=2017;") == 1
    assert scalar(args, "SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='pas_22h_schapenbegrazing_2016' AND jaar=2016;") == 6
    assert scalar(args, "SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='pas_22h_deelbegrazing_2017' AND jaar=2017;") == 6
    assert query(args, """
      SELECT GROUP_CONCAT(jaar ORDER BY jaar SEPARATOR ',')
      FROM maatregel_uitvoering_jaar j
      JOIN maatregel_uitvoering u USING (uitvoering_id)
      WHERE u.uitvoering_code='begrazingsregime_meijendel_2019_2023';
    """) == "2019,2021,2023"
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_plot_koppeling pk JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code IN ('begrazingsdruk_kijfhoek_bierlap_1995','begrazingsregime_meijendel_2019_2023');") == 0
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_plot_koppeling pk JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_3c_begrazing_vanaf_2022';") == 13
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_uitvoering_jaar j JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_3c_begrazing_vanaf_2022';") == 0

    assert scalar(args, """
      SELECT COUNT(*) FROM maatregel_uitvoering_bron ub
      JOIN maatregel_uitvoering u USING (uitvoering_id)
      JOIN maatregel_bron b USING (bron_id)
      WHERE u.uitvoering_code='kikkervalleien_begrazing_1997'
        AND b.bron_code='zotero_begrazing_2012'
        AND ub.bronrol='tegenstrijdig_bewijs';
    """) == 1
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_plot_jaar_registratie;") == 139
    assert scalar(args, "SELECT COUNT(*) FROM maatregel_registratie_herkomst;") == 144
    print("OK: begrazingsactualisering 2026-11-11")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
