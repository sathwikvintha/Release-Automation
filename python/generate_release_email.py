import os
import re
import textwrap
import logging

# =========================
# LOGGING SETUP
# =========================
LOG_DIR = os.path.join("..", "logs")
LOG_FILE = os.path.join(LOG_DIR, "release_email_generator.log")

if not os.path.exists(LOG_DIR):
    raise Exception(f"Logs directory not found at {LOG_DIR}. Expected it to be pre-created.")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler()   # live console logging
    ]
)

logging.info("========== Release Email Generator Started ==========")

# =========================
# TABLE SETTINGS
# =========================
COL1_WIDTH = 40
COL2_WIDTH = 70

SECURITY_NOTE = (
    "The report is available at this location. "
    "Please review the same and as discussed & agreed, "
    "please help to share the priority to address the issues / "
    "vulnerabilities so that the fix can be planned in the "
    "upcoming releases."
)

SECURITY_KEYWORDS = ["Malware", "OSCS", "STaaS"]

# =========================
# LOAD CONFIG
# =========================
def load_config(path):
    cfg = {}
    logging.info(f"Loading email config from {path}")

    if not os.path.exists(path):
        logging.error(f"Email config file not found: {path}")
        raise FileNotFoundError(f"Email config file not found: {path}")

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            cfg[key.strip()] = value.strip()

    logging.info("Email config loaded successfully")
    return cfg

# =========================
# HELPERS
# =========================
def scan_pgp_files(folder):
    logging.info(f"Scanning PGP files in folder: {folder}")
    files = sorted(
        f for f in os.listdir(folder)
        if os.path.isfile(os.path.join(folder, f)) and f.lower().endswith(".pgp")
    )
    logging.info(f"Found {len(files)} PGP files")
    return files


def derive_left_label(filename, release_version):
    name = filename.replace(release_version + "_", "").replace(".pgp", "")
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
    name = name.replace("DB ", "DB ").replace("UX", "UX").replace("API", "API")
    return name.strip()


def needs_security_note(label):
    return any(key.lower() in label.lower() for key in SECURITY_KEYWORDS)


def separator():
    return "+" + "-" * COL1_WIDTH + "+" + "-" * COL2_WIDTH + "+\n"


def format_row(col1, col2):
    wrapped = textwrap.wrap(col2, COL2_WIDTH) or [""]
    lines = [
        f"| {col1.ljust(COL1_WIDTH-2)}| {wrapped[0].ljust(COL2_WIDTH-2)}|\n"
    ]
    for extra in wrapped[1:]:
        lines.append(
            f"| {' '.ljust(COL1_WIDTH-2)}| {extra.ljust(COL2_WIDTH-2)}|\n"
        )
    return "".join(lines)

# =========================
# MAIN
# =========================
def generate():
    config = load_config("email_config.txt")

    release = config["RELEASE_VERSION"]
    base_folder = config["BASE_FOLDER"]
    fo_base = config["FO_BASE_PATH"]
    sign_off = config.get("SIGN_OFF_NAME", "")

    logging.info(
        f"Inputs | Release={release} | BaseFolder={base_folder} | FOPath={fo_base}"
    )

    release_folder = os.path.join(base_folder, f"release_{release}")
    if not os.path.exists(release_folder):
        logging.error(f"Release folder not found: {release_folder}")
        raise FileNotFoundError(f"Release folder not found: {release_folder}")

    pgp_files = scan_pgp_files(release_folder)

    output = []

    # Email header
    output.append("Hi Team,\n\n")
    output.append(
        f"Please find the artifacts below for release of {release}.\n"
        "Artifacts to be uploaded on SECURE FILE SHARING APAC – BNP PARIBAS Collaboration.\n\n"
    )

    # Table header
    output.append(separator())
    output.append(format_row("Item", "Details"))
    output.append(separator())

    for file in pgp_files:
        label = derive_left_label(file, release)
        value = f"{fo_base} > {release} > FO > {file}"

        if needs_security_note(label):
            logging.info(f"Security note added for file: {file}")
            value += " " + SECURITY_NOTE

        output.append(format_row(label, value))
        output.append(separator())

    # Sign-off
    output.append("\nRegards,\n")
    output.append(sign_off + "\n")

    out_file = f"Release_Email_{release}.txt"
    with open(out_file, "w", encoding="utf-8") as f:
        f.writelines(output)

    logging.info(f"Release email generated successfully: {out_file}")
    print(f" Release email generated with ALL PGP files: {out_file}")

# =========================
# ENTRY POINT
# =========================
if __name__ == "__main__":
    try:
        generate()
        logging.info("========== Release Email Generator Completed ==========")
    except Exception:
        logging.exception("Release email generation failed")
        raise
