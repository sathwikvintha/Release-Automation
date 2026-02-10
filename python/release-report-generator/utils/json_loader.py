import json
from config.paths import JSON_DIR

def load_json(json_filename: str):
    json_path = JSON_DIR / json_filename

    if not json_path.exists():
        available = [p.name for p in JSON_DIR.glob("*.json")]
        raise FileNotFoundError(
            f"\n❌ JSON file not found: {json_filename}\n"
            f"📂 Looked in: {JSON_DIR}\n"
            f"📄 Available JSON files: {available}\n"
        )

    with open(json_path, "r", encoding="utf-8-sig") as f:
        return json.load(f)
