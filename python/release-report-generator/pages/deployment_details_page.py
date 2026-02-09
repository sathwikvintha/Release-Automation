from utils.word_helpers import add_colored_bar

ORDERED_SECTIONS = [
    "2.1 Web server Changes",
    "2.2 Maven Deployment Changes",
    "2.3 App Server Changes",
    "2.4 DB Changes- Environment Specific Changes",
    "2.5 Queue Configuration Scripts",
    "2.6 Scheduler jobs",
    "2.7 Migration Scripts",
    "2.8 Shell Script changes",
    "2.9 Sql Script change",
    "2.10 Cron Job changes",
    "2.11 Keycloak Configuration changes"
]

def build_deployment_details_page(doc, data):
    add_colored_bar(doc, "2. Deployment Details", "FF0000", size=13)

    for sec in ORDERED_SECTIONS:
        add_colored_bar(doc, sec, "D9D9D9", italic=True, size=10.5)
        vals = data["deploymentDetails"].get(sec, [])
        doc.add_paragraph("No special instructions" if not vals else "\n".join(vals))
