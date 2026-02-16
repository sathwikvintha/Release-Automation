from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent   # release-report-generator
PROJECT_ROOT = BASE_DIR.parent.parent              # Release-Automation

# JSON directory (inside release-report-generator)
JSON_DIR = BASE_DIR / "json_files"
JSON_DIR.mkdir(parents=True, exist_ok=True)

# Output directory (central Report-output folder)
OUTPUT_DIR = PROJECT_ROOT / "Report-output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Logos directory
LOGOS_DIR = BASE_DIR / "logos"

BNP_LOGO = LOGOS_DIR / "bnp_paribas.png"
ORACLE_LOGO = LOGOS_DIR / "oracle.png"
FOOTER_LINE = LOGOS_DIR / "footer_line.png"
