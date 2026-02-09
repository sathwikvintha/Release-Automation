import os
import re
import textwrap

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

SECURITY_KEYWORDS = [
    "Malware",
    "OSCS",
    "STaaS"
]

# =========================
# LOAD CONFIG
# =========================

def load_config(path):
    cfg = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            cfg[key.strip()] = value.strip()
    return cfg


# =========================
# HELPERS
# =========================

def scan_pgp_files(folder):
    return sorted(
        f for f in os.listdir(folder)
        if os.path.isfile(os.path.join(folder, f)) and f.lower().endswith(".pgp")
    )


def derive_left_label(filename, release_version):
    name = filename.replace(release_version + "_", "").replace(".pgp", "")

    # Add spaces before capital letters (DBExecution → DB Execution)
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)

    # Normalize common acronyms
    name = name.replace("DB ", "DB ")
    name = name.replace("UX", "UX")
    name = name.replace("API", "API")

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

    release_folder = os.path.join(base_folder, f"release_{release}")
    if not os.path.exists(release_folder):
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
            value += " " + SECURITY_NOTE

        output.append(format_row(label, value))
        output.append(separator())

    # Sign-off
    output.append("\nRegards,\n")
    output.append(sign_off + "\n")

    out_file = f"Release_Email_{release}.txt"
    with open(out_file, "w", encoding="utf-8") as f:
        f.writelines(output)

    print(f" Release email generated with ALL PGP files: {out_file}")


if __name__ == "__main__":
    generate()
