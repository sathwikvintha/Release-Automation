import os
import subprocess
import shutil

# ================= CONFIG LOADER =================
def load_release_config(file_path="release_config.txt"):
    config = {}

    if not os.path.exists(file_path):
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
            raise Exception(f"Missing required config key: {key}")

    return config


# ================= LOAD CONFIG =================
config = load_release_config()

RELEASE_VERSION = config["RELEASE_VERSION"]
BASE_DIR = config["BASE_DIR"]
PGP_PUBLIC_KEY = config["PGP_PUBLIC_KEY"]
# ==============================================


def zip_folder(folder_path):
    zip_path = f"{folder_path}.zip"
    print(f" Zipping: {folder_path}")
    shutil.make_archive(folder_path, "zip", folder_path)
    return zip_path


def pgp_encrypt(zip_file):
    pgp_file = zip_file.replace(".zip", ".pgp")
    print(f" Encrypting: {zip_file}")

    subprocess.run(
        [
            "gpg",
            "--batch",
            "--yes",
            "--trust-model", "always",   # IMPORTANT for automation
            "--armor",
            "--output", pgp_file,
            "--encrypt",
            "--recipient", PGP_PUBLIC_KEY,
            zip_file
        ],
        check=True
    )

    return pgp_file


def process_release():
    if not os.path.exists(BASE_DIR):
        raise Exception(f"Base directory not found: {BASE_DIR}")

    print(f"\n Processing release: {RELEASE_VERSION}\n")

    for item in os.listdir(BASE_DIR):
        item_path = os.path.join(BASE_DIR, item)

        # Only zip + encrypt directories
        if os.path.isdir(item_path):
            zip_file = zip_folder(item_path)
            pgp_encrypt(zip_file)

    print("\n ALL FOLDERS ZIPPED AND PGP ENCRYPTED SUCCESSFULLY")


if __name__ == "__main__":
    process_release()
