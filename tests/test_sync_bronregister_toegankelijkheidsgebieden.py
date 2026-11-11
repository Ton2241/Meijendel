import ast
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "sync_bronregister_toegankelijkheidsgebieden.py"


class BronregisterSynchronisatieTest(unittest.TestCase):
    def test_actuele_parser18_alinea_blijft_opnieuw_synchroniseerbaar(self):
        tree = ast.parse(SCRIPT.read_text(encoding="utf-8"))
        assignments = {
            node.targets[0].id: ast.literal_eval(node.value)
            for node in tree.body
            if isinstance(node, ast.Assign)
            and len(node.targets) == 1
            and isinstance(node.targets[0], ast.Name)
            and node.targets[0].id == "SHINY_PARAGRAPH_PREFIXES"
        }

        self.assertIn(
            "Shiny en de statische browser gebruiken parser/cacheversie 18",
            assignments["SHINY_PARAGRAPH_PREFIXES"],
        )
        self.assertTrue(
            any(
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "replace_paragraph_any"
                and any(
                    isinstance(argument, ast.Name)
                    and argument.id == "SHINY_PARAGRAPH_PREFIXES"
                    for argument in node.args
                )
                for node in ast.walk(tree)
            )
        )


if __name__ == "__main__":
    unittest.main()
