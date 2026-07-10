#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import io
import subprocess
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REQUIRED_COLUMNS = {"year", "object_type", "assignment_type", "plot_id"}
TELLER_COLUMNS = {"teller_id", "sovoncode"}


@dataclass(frozen=True)
class Assignment:
    year: int
    plot_id: int
    teller_id: int
    source_row: int


@dataclass(frozen=True)
class MysqlSnapshot:
    plot_ids: set[int]
    tellers_by_id: dict[int, str]
    teller_ids_by_code: dict[str, int]
    existing_for_year: set[tuple[int, int]]


@dataclass(frozen=True)
class DiffPlan:
    to_insert: set[tuple[int, int]]
    to_delete: set[tuple[int, int]]
    unchanged: set[tuple[int, int]]

    @property
    def affected_plots(self) -> set[int]:
        return {plot_id for _, plot_id in self.to_insert | self.to_delete}


def _mysql(args: argparse.Namespace, sql: str) -> str:
    cmd = [
        "mysql",
        f"--login-path={args.login_path}",
        "--batch",
        "--raw",
        "--skip-column-names",
        "-D",
        args.database,
    ]
    proc = subprocess.run(cmd, input=sql, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise SystemExit(f"MySQL-fout:\n{proc.stderr.strip()}")
    return proc.stdout


def _read_csv(path: Path) -> list[dict[str, str]]:
    text = path.read_text(encoding="utf-8-sig")
    sample = text[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    reader = csv.DictReader(io.StringIO(text), dialect=dialect)
    if not reader.fieldnames:
        raise SystemExit("CSV heeft geen header.")
    rows: list[dict[str, str]] = []
    for index, row in enumerate(reader, start=2):
        if None in row:
            raise SystemExit(f"CSV-rij {index} heeft meer velden dan de header.")
        rows.append({(key or "").strip(): (value or "").strip() for key, value in row.items()})
    columns = set(rows[0]) if rows else set(reader.fieldnames)
    missing = REQUIRED_COLUMNS - columns
    if missing:
        raise SystemExit(f"CSV mist verplichte kolommen: {', '.join(sorted(missing))}")
    if not (TELLER_COLUMNS & columns):
        raise SystemExit("CSV moet minimaal teller_id of sovoncode bevatten.")
    return rows


def _to_int(value: Any, *, field: str, row_number: int) -> int | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return int(text)
    except ValueError as exc:
        raise SystemExit(f"Rij {row_number}: {field} is geen integer: {text}") from exc


def _load_snapshot(args: argparse.Namespace, year: int) -> MysqlSnapshot:
    sql = f"""
    SELECT 'P', plot_id FROM plots;
    SELECT 'T', id, tellercode FROM tellers;
    SELECT 'E', teller_id, plot_id FROM plot_jaar_teller WHERE jaar = {year};
    """
    parts = _mysql(args, sql).splitlines()
    plot_ids: set[int] = set()
    tellers_by_id: dict[int, str] = {}
    teller_ids_by_code: dict[str, int] = {}
    existing_for_year: set[tuple[int, int]] = set()

    for line in parts:
        cols = line.split("\t")
        if not cols:
            continue
        marker = cols[0]
        if marker == "P" and len(cols) == 2:
            plot_ids.add(int(cols[1]))
        elif marker == "T" and len(cols) == 3:
            teller_id = int(cols[1])
            tellercode = cols[2].strip()
            tellers_by_id[teller_id] = tellercode
            if tellercode:
                teller_ids_by_code[tellercode.lower()] = teller_id
        elif marker == "E" and len(cols) == 3:
            existing_for_year.add((int(cols[1]), int(cols[2])))

    return MysqlSnapshot(
        plot_ids=plot_ids,
        tellers_by_id=tellers_by_id,
        teller_ids_by_code=teller_ids_by_code,
        existing_for_year=existing_for_year,
    )


def _target_year(rows: list[dict[str, str]], explicit_year: int | None) -> int:
    years = {int(row["year"]) for row in rows if str(row.get("year") or "").strip()}
    if explicit_year:
        if years and years != {explicit_year}:
            raise SystemExit(f"CSV bevat jaar/jaren {sorted(years)}, maar --year is {explicit_year}.")
        return explicit_year
    if len(years) != 1:
        raise SystemExit(f"Geef --year op; CSV bevat {len(years)} jaren: {sorted(years)}")
    return years.pop()


def _build_assignments(rows: list[dict[str, str]], snapshot: MysqlSnapshot, year: int) -> tuple[list[Assignment], list[str]]:
    assignments: list[Assignment] = []
    warnings: list[str] = []
    for index, row in enumerate(rows, start=2):
        if str(row.get("year") or "").strip() and int(row["year"]) != year:
            continue
        if (row.get("object_type") or "").strip().lower() != "plot":
            continue
        if (row.get("assignment_type") or "").strip().lower() != "bmp":
            continue
        if not (row.get("teller_id") or row.get("sovoncode")):
            continue

        plot_id = _to_int(row.get("plot_id"), field="plot_id", row_number=index)
        if plot_id is None:
            warnings.append(f"Rij {index}: BMP-regel zonder plot_id overgeslagen.")
            continue
        if plot_id not in snapshot.plot_ids:
            warnings.append(f"Rij {index}: onbekend plot_id {plot_id}.")
            continue

        teller_id = _to_int(row.get("teller_id"), field="teller_id", row_number=index)
        sovoncode = (row.get("sovoncode") or "").strip()
        if teller_id is None and sovoncode:
            teller_id = snapshot.teller_ids_by_code.get(sovoncode.lower())
            if teller_id is None:
                warnings.append(f"Rij {index}: onbekende sovoncode/tellercode {sovoncode}.")
                continue
        if teller_id is None:
            warnings.append(f"Rij {index}: geen teller_id of herkenbare sovoncode.")
            continue
        if teller_id not in snapshot.tellers_by_id:
            warnings.append(f"Rij {index}: onbekend teller_id {teller_id}.")
            continue
        if sovoncode and snapshot.tellers_by_id[teller_id].lower() != sovoncode.lower():
            warnings.append(
                f"Rij {index}: teller_id {teller_id} heeft tellercode "
                f"{snapshot.tellers_by_id[teller_id]}, CSV heeft {sovoncode}."
            )

        assignments.append(Assignment(year=year, plot_id=plot_id, teller_id=teller_id, source_row=index))
    return assignments, warnings


def _sql_plan(assignments: list[Assignment], *, year: int, replace_year: bool) -> str:
    lines = [
        "START TRANSACTION;",
        f"-- Website kavelbezetting import voor jaar {year}.",
    ]
    if replace_year:
        lines.append(f"DELETE FROM plot_jaar_teller WHERE jaar = {year};")
    lines.append("INSERT INTO plot_jaar_teller (teller_id, plot_id, jaar) VALUES")
    values = [
        f"  ({assignment.teller_id}, {assignment.plot_id}, {assignment.year})"
        for assignment in assignments
    ]
    lines.append(",\n".join(values))
    lines.append("ON DUPLICATE KEY UPDATE teller_id = VALUES(teller_id);")
    lines.append("COMMIT;")
    return "\n".join(lines) + "\n"


def _sql_diff_plan(diff: DiffPlan, *, year: int) -> str:
    lines = [
        "START TRANSACTION;",
        f"-- Website kavelbezetting diff-import voor jaar {year}.",
    ]
    if diff.to_delete:
        delete_pairs = [
            f"(teller_id = {teller_id} AND plot_id = {plot_id})"
            for teller_id, plot_id in sorted(diff.to_delete, key=lambda pair: (pair[1], pair[0]))
        ]
        lines.append(
            f"DELETE FROM plot_jaar_teller WHERE jaar = {year} AND (\n  "
            + "\n  OR ".join(delete_pairs)
            + "\n);"
        )
    if diff.to_insert:
        lines.append("INSERT INTO plot_jaar_teller (teller_id, plot_id, jaar) VALUES")
        values = [
            f"  ({teller_id}, {plot_id}, {year})"
            for teller_id, plot_id in sorted(diff.to_insert, key=lambda pair: (pair[1], pair[0]))
        ]
        lines.append(",\n".join(values))
        lines.append("ON DUPLICATE KEY UPDATE teller_id = VALUES(teller_id);")
    lines.append("COMMIT;")
    return "\n".join(lines) + "\n"


def _summarize(assignments: list[Assignment], warnings: list[str], snapshot: MysqlSnapshot) -> dict[str, Any]:
    pairs = [(assignment.teller_id, assignment.plot_id) for assignment in assignments]
    duplicate_pairs = [pair for pair, count in Counter(pairs).items() if count > 1]
    already_existing = [pair for pair in pairs if pair in snapshot.existing_for_year]
    by_plot: dict[int, int] = defaultdict(int)
    for _, plot_id in pairs:
        by_plot[plot_id] += 1
    return {
        "assignments": len(assignments),
        "plots": len(by_plot),
        "tellers": len({assignment.teller_id for assignment in assignments}),
        "warnings": len(warnings),
        "duplicate_pairs": len(duplicate_pairs),
        "existing_target_year_rows": len(snapshot.existing_for_year),
        "already_existing_pairs": len(already_existing),
    }


def _diff(assignments: list[Assignment], snapshot: MysqlSnapshot) -> DiffPlan:
    desired = {(assignment.teller_id, assignment.plot_id) for assignment in assignments}
    existing = snapshot.existing_for_year
    return DiffPlan(
        to_insert=desired - existing,
        to_delete=existing - desired,
        unchanged=desired & existing,
    )


def _print_report(summary: dict[str, Any], warnings: list[str]) -> None:
    print("Kavelbezetting website-CSV -> Meijendel MySQL")
    for key, value in summary.items():
        print(f"- {key}: {value}")
    if warnings:
        print("\nWaarschuwingen:")
        for warning in warnings:
            print(f"- {warning}")


def _print_diff_report(diff: DiffPlan) -> None:
    print("\nDiff met lokaal Meijendel-MySQL:")
    print(f"- to_insert: {len(diff.to_insert)}")
    print(f"- to_delete: {len(diff.to_delete)}")
    print(f"- unchanged: {len(diff.unchanged)}")
    print(f"- affected_plots: {len(diff.affected_plots)}")
    if diff.to_insert:
        print("\nToe te voegen:")
        for teller_id, plot_id in sorted(diff.to_insert, key=lambda pair: (pair[1], pair[0])):
            print(f"- plot_id={plot_id}, teller_id={teller_id}")
    if diff.to_delete:
        print("\nTe verwijderen:")
        for teller_id, plot_id in sorted(diff.to_delete, key=lambda pair: (pair[1], pair[0])):
            print(f"- plot_id={plot_id}, teller_id={teller_id}")


def run(args: argparse.Namespace) -> int:
    rows = _read_csv(Path(args.csv))
    year = _target_year(rows, args.year)
    snapshot = _load_snapshot(args, year)
    assignments, warnings = _build_assignments(rows, snapshot, year)
    summary = _summarize(assignments, warnings, snapshot)
    _print_report(summary, warnings)

    if not assignments:
        raise SystemExit("Geen toepasbare BMP-tellerregels gevonden.")
    if summary["duplicate_pairs"]:
        raise SystemExit("CSV bevat dubbele teller/plot-combinaties; corrigeer eerst de export.")
    if warnings and not args.allow_warnings:
        raise SystemExit("Waarschuwingen gevonden; gebruik --allow-warnings alleen als ze beoordeeld zijn.")
    if args.command.startswith("diff-"):
        diff = _diff(assignments, snapshot)
        _print_diff_report(diff)
        if args.command == "diff-run":
            return 0
        sql = _sql_diff_plan(diff, year=year)
        if args.plan:
            Path(args.plan).write_text(sql, encoding="utf-8")
            print(f"\nSQL-plan geschreven: {args.plan}")
        if args.command == "diff-plan":
            return 0
        if not diff.to_insert and not diff.to_delete:
            print("\nGeen verschillen; apply niet nodig.")
            return 0
        if diff.to_delete and not args.confirm_full_year:
            raise SystemExit(
                "Diff bevat verwijderingen. Gebruik --confirm-full-year pas nadat is gecontroleerd "
                "dat de CSV een complete jaarexport is."
            )
        if not args.yes:
            raise SystemExit("Diff-apply vereist --yes.")
        _mysql(args, sql)
        print(
            f"\nDiff-apply klaar: {len(diff.to_insert)} toegevoegd, "
            f"{len(diff.to_delete)} verwijderd voor jaar {year}."
        )
        return 0
    if args.command == "dry-run":
        return 0

    sql = _sql_plan(assignments, year=year, replace_year=args.replace_year)
    if args.plan:
        Path(args.plan).write_text(sql, encoding="utf-8")
        print(f"\nSQL-plan geschreven: {args.plan}")
    if args.command == "plan":
        return 0

    if snapshot.existing_for_year and not args.replace_year:
        raise SystemExit(
            f"Doeljaar {year} bevat al {len(snapshot.existing_for_year)} regels. "
            "Gebruik --replace-year om het jaar eerst te vervangen."
        )
    if not args.yes:
        raise SystemExit("Apply vereist --yes.")
    _mysql(args, sql)
    print(f"\nApply klaar: {len(assignments)} regels verwerkt voor jaar {year}.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verwerk website-CSV kavelbezetting naar lokale Meijendel-MySQL plot_jaar_teller."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("dry-run", "plan", "apply", "diff-run", "diff-plan", "diff-apply"):
        sub = subparsers.add_parser(command)
        sub.add_argument("--csv", required=True, help="CSV uit /leden/kavels.csv")
        sub.add_argument("--year", type=int, help="Doeljaar; standaard uit CSV afgeleid.")
        sub.add_argument("--login-path", default="meijendel_root")
        sub.add_argument("--database", default="Meijendel")
        sub.add_argument("--allow-warnings", action="store_true")
        sub.add_argument("--replace-year", action="store_true", help="Vervang alle plot_jaar_teller-regels voor dit jaar.")
        sub.add_argument(
            "--confirm-full-year",
            action="store_true",
            help="Bevestig dat de CSV een complete jaarexport is; verplicht voor diff-apply met verwijderingen.",
        )
        sub.add_argument("--plan", help="Pad voor SQL-planoutput.")
        sub.add_argument("--yes", action="store_true", help="Verplicht voor apply.")
    args = parser.parse_args()
    if args.command not in {"apply", "diff-apply"} and args.yes:
        raise SystemExit("--yes is alleen toegestaan bij apply en diff-apply.")
    return run(args)


if __name__ == "__main__":
    raise SystemExit(main())
