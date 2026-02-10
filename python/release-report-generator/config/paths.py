from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BASE_DIR.parent.parent

# Final output directory (Release-Automation/Report-output)
OUTPUT_DIR = PROJECT_ROOT / "Report-output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

JSON_DIR = PROJECT_ROOT / "json files"

LOGOS_DIR = BASE_DIR / "logos"

BNP_LOGO = LOGOS_DIR / "bnp_paribas.png"
ORACLE_LOGO = LOGOS_DIR / "oracle.png"
FOOTER_LINE = LOGOS_DIR / "footer_line.png"
