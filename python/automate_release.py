import os
import subprocess
import shutil
import logging
from datetime import datetime

# ================= LOGGING SETUP =================
LOG_DIR = os.path.join("..", "logs")
LOG_FILE = os.path.join(LOG_DIR, "zip_pgp_release.log")

if not os.path.exists(LOG_DIR):
    raise Exception(f"Logs directory not found at {LOG_DIR}. Expected it to be pre-created.")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler()  # keeps console output live
    ]
)

logging.info("========== ZIP + PGP Release Automation Started ==========")

# ================= CONFIG LOADER =================
def load_release_config(file_path="release_config.txt"):
    config = {}

    if not os.path.exists(file_path):
        logging.error(f"Config file not found: {file_path}")
        raise Exception(f"Config file not found: {file_path}")

    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                config[key.strip()] = value.strip()

    required_keys = ["RELEASE_VERSION", "BASE_DIR", "PGP_PUBLIC_KEY"]
    for key in required_keys:
        if key not in config:
            logging.error(f"Missing required config key: {key}")
            raise Exception(f"Missing required config key: {key}")

    logging.info("Release config loaded successfully")
    return config


# ================= LOAD CONFIG =================
config = load_release_config()

RELEASE_VERSION = config["RELEASE_VERSION"]
BASE_DIR = config["BASE_DIR"]
PGP_PUBLIC_KEY = config["PGP_PUBLIC_KEY"]

logging.info(
    f"Inputs | Release={RELEASE_VERSION} | BaseDir={BASE_DIR} | PGPKey={PGP_PUBLIC_KEY}"
)

# ==============================================

def zip_folder(folder_path):
    zip_path = f"{folder_path}.zip"
    print(f" Zipping: {folder_path}")
    logging.info(f"Zipping folder: {folder_path}")

    shutil.make_archive(folder_path, "zip", folder_path)

    logging.info(f"ZIP created: {zip_path}")
    return zip_path


def pgp_encrypt(zip_file):
    pgp_file = zip_file.replace(".zip", ".pgp")
    print(f" Encrypting: {zip_file}")
    logging.info(f"Encrypting ZIP using PGP: {zip_file}")

    subprocess.run(
        [
            "gpg",
            "--batch",
            "--yes",
            "--trust-model", "always",
            "--armor",
            "--output", pgp_file,
            "--encrypt",
            "--recipient", PGP_PUBLIC_KEY,
            zip_file
        ],
        check=True
    )

    logging.info(f"PGP encryption completed: {pgp_file}")
    return pgp_file


def process_release():
    if not os.path.exists(BASE_DIR):
        logging.error(f"Base directory not found: {BASE_DIR}")
        raise Exception(f"Base directory not found: {BASE_DIR}")

    print(f"\n Processing release: {RELEASE_VERSION}\n")
    logging.info(f"Processing release: {RELEASE_VERSION}")

    for item in os.listdir(BASE_DIR):
        item_path = os.path.join(BASE_DIR, item)

        # Only zip + encrypt directories
        if os.path.isdir(item_path):
            logging.info(f"Processing directory: {item_path}")
            zip_file = zip_folder(item_path)
            pgp_encrypt(zip_file)

    print("\n ALL FOLDERS ZIPPED AND PGP ENCRYPTED SUCCESSFULLY")
    logging.info("All folders zipped and PGP encrypted successfully")


if __name__ == "__main__":
    try:
        process_release()
        logging.info("========== ZIP + PGP Release Automation Completed ==========")
    except Exception as e:
        logging.exception("Release automation failed")
        raise
