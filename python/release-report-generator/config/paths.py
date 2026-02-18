import glob
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent   # release-report-generator
PROJECT_ROOT = BASE_DIR.parent.parent              # Release-Automation

# JSON directory (inside release-report-generator)
JSON_DIR = BASE_DIR / "json_files"
JSON_DIR.mkdir(parents=True, exist_ok=True)

# ============================================================
# Auto-detect latest *_ORM_Reports folder
# ============================================================

REPORT_ROOT = PROJECT_ROOT / "Report-output"
report_folders = glob.glob(str(REPORT_ROOT / "*" / "*_ORM_Reports"))

if not report_folders:
    raise Exception("No *_ORM_Reports folder found. Run Commit Summary first.")

# Pick newest report folder
OUTPUT_DIR = Path(max(report_folders, key=lambda p: Path(p).stat().st_mtime))
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

print(f"Release document will be created inside: {OUTPUT_DIR}")

# Logos directory
LOGOS_DIR = BASE_DIR / "logos"

BNP_LOGO = LOGOS_DIR / "bnp_paribas.png"
ORACLE_LOGO = LOGOS_DIR / "oracle.png"
FOOTER_LINE = LOGOS_DIR / "footer_line.png"
