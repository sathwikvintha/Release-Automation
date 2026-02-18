import os
import subprocess
import shutil
import logging
import sys

# ============================================================
# ARGUMENTS (called from pipeline runner)
# ============================================================

if len(sys.argv) != 3:
    print("Usage: python automate_release.py <RELEASE_VERSION> <BASE_DIR>")
    sys.exit(1)

RELEASE_VERSION = sys.argv[1]
BASE_DIR = sys.argv[2]

# ============================================================
# PROJECT PATH RESOLUTION
# ============================================================

BASE_PROJECT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
)

# 🔐 Public key inside project
KEY_PATH = os.path.join(BASE_PROJECT_DIR, "keys", "pub.asc")

# 🔐 FULL fingerprint of company public key
EXPECTED_FINGERPRINT = "EDB4C925F8083BAA9ED9B829FE700299AAED2302"

# ============================================================
# LOGGING SETUP
# ============================================================

LOG_DIR = os.path.join(BASE_PROJECT_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

LOG_FILE = os.path.join(LOG_DIR, "zip.log")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler()
    ]
)

logging.info("========== ZIP + PGP Release Automation Started ==========")
logging.info(f"Release Version: {RELEASE_VERSION}")
logging.info(f"Base Directory: {BASE_DIR}")

# ============================================================
# PGP KEY IMPORT
# ============================================================

def import_public_key():
    if not os.path.exists(KEY_PATH):
        raise Exception(f"Public key file not found at {KEY_PATH}")

    logging.info("Importing company public key...")

    # We wrap the KEY_PATH in double quotes to handle spaces in the username
    subprocess.run(
        f'gpg --batch --yes --import "{KEY_PATH}"',
        shell=True,
        check=True
    )

def validate_key():
    logging.info("Validating public key fingerprint...")

    result = subprocess.run(
        ["gpg", "--list-keys", "--with-colons"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True
    )

    if EXPECTED_FINGERPRINT not in result.stdout:
        raise Exception("Expected public key fingerprint not found in keyring.")

    logging.info("Public key validated successfully.")

# ============================================================
# ZIP FUNCTION
# ============================================================

def zip_folder(folder_path):
    zip_path = f"{folder_path}.zip"

    logging.info(f"Zipping folder: {folder_path}")

    shutil.make_archive(folder_path, "zip", folder_path)

    logging.info(f"ZIP created: {zip_path}")
    return zip_path

# ============================================================
# ENCRYPT FUNCTION
# ============================================================

def pgp_encrypt(zip_file):
    pgp_file = zip_file.replace(".zip", ".pgp")

    logging.info(f"Encrypting ZIP: {zip_file}")

    # Using a formatted string with quotes for all file paths
    command = (
        f'gpg --batch --yes --trust-model always --armor '
        f'--output "{pgp_file}" --encrypt --recipient {EXPECTED_FINGERPRINT} "{zip_file}"'
    )

    subprocess.run(command, shell=True, check=True)

    logging.info(f"PGP encryption completed: {pgp_file}")
    return pgp_file

    logging.info(f"PGP encryption completed: {pgp_file}")
    return pgp_file

# ============================================================
# MAIN PROCESS
# ============================================================

def process_release():

    if not os.path.exists(BASE_DIR):
        raise Exception(f"Base directory not found: {BASE_DIR}")

    # Step 1: Import key automatically
    import_public_key()

    # Step 2: Validate fingerprint
    validate_key()

    logging.info(f"Processing release folders inside: {BASE_DIR}")

    for item in os.listdir(BASE_DIR):
        item_path = os.path.join(BASE_DIR, item)

        # Only process directories
        if os.path.isdir(item_path):
            logging.info(f"Processing directory: {item_path}")
            zip_file = zip_folder(item_path)
            pgp_encrypt(zip_file)

    logging.info("All folders zipped and encrypted successfully.")

# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    try:
        process_release()
        logging.info("========== ZIP + PGP Completed Successfully ==========")
    except Exception as e:
        logging.exception("ZIP + PGP Failed")
        sys.exit(1)
