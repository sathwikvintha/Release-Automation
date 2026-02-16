import json
from pathlib import Path

# Get project root dynamically
BASE_DIR = Path(__file__).resolve().parent.parent

# Correct JSON folder
JSON_DIR = BASE_DIR / "json_files"

def load_json(filename: str):
    file_path = JSON_DIR / filename

    if not file_path.exists():
        raise FileNotFoundError(
            f"\n❌ JSON file not found: {filename}\n"
            f"📂 Looked in: {JSON_DIR}\n"
            f"📄 Available JSON files: {[f.name for f in JSON_DIR.glob('*.json')]}"
        )

    with open(file_path, "r", encoding="utf-8-sig") as f:
        return json.load(f)
