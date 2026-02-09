from docx.oxml import OxmlElement, ns
from docx.shared import Pt

def add_page_border(section):
    sectPr = section._sectPr
    pgBorders = OxmlElement("w:pgBorders")

    for side in ("top", "left", "bottom", "right"):
        border = OxmlElement(f"w:{side}")
        border.set(ns.qn("w:val"), "single")
        border.set(ns.qn("w:sz"), "6")
        border.set(ns.qn("w:space"), "24")
        border.set(ns.qn("w:color"), "auto")
        pgBorders.append(border)

    sectPr.append(pgBorders)


def add_colored_bar(doc, text, bg_color, size=11, bold=True, italic=False):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.bold = bold
    run.italic = italic
    run.font.size = Pt(size)

    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(ns.qn("w:fill"), bg_color)
    pPr.append(shd)
