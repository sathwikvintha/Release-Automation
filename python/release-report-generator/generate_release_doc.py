from docx import Document
from config.paths import OUTPUT_DIR
from utils.json_loader import load_json
from utils.word_helpers import add_page_border
from pages.header_footer import add_header, add_footer
from pages.title_page import build_title_page
from pages.document_control_page import build_document_control_page
from pages.toc_page import build_toc_page
from pages.deployment_details_page import build_deployment_details_page
from pages.introduction_page_1 import build_introduction_page_1
from pages.introduction_page_2 import build_introduction_page_2
from pages.deployment_details_page_1 import build_deployment_details_page_1
from pages.deployment_details_page_2 import build_deployment_details_page_2
from pages.deployment_details_page_3 import build_deployment_details_page_3
from pages.deployment_details_page_4 import build_deployment_details_page_4
from pages.deployment_details_page_5 import build_deployment_details_page_5
from pages.deployment_details_page_6 import build_deployment_details_page_6

json_file = input("Enter JSON file name: ").strip()
title = input("Enter Document Title: ").strip()
release = input("Enter Release Number: ").strip()
subtitle = input("Enter Sub Title: ").strip()
version_no = input("Enter Version Number: ").strip()
version_date = input("Enter Version Date: ").strip()

data = load_json(json_file)

doc_name = f"BNPP_{release}_Release_Deployment_Documents.docx"
output_doc = OUTPUT_DIR / doc_name

doc = Document()
section = doc.sections[0]

add_page_border(section)
add_header(section)

build_title_page(doc, title, release, subtitle, version_no, version_date)
build_document_control_page(doc, version_no)
build_toc_page(doc)
doc.add_page_break()
build_introduction_page_1(doc)
build_introduction_page_2(doc)
build_deployment_details_page_1(doc, data)
build_deployment_details_page_2(doc, data)
build_deployment_details_page_3(doc, data)
build_deployment_details_page_4(doc, data)
build_deployment_details_page_5(doc, data)
build_deployment_details_page_6(doc, data)

add_footer(section, doc_name)

doc.save(output_doc)
print(f"\n✅ Document generated: {output_doc}")
