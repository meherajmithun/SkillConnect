"""Generate the two-page project summary. Requires reportlab."""

from html import escape
from pathlib import Path
import re

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle,
)

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "PROJECT_STATE_SUMMARY.md"
OUTPUT = HERE / "SkillConnect_Project_State_and_Future_Scope.pdf"
NAVY = colors.HexColor("#15384A")
TEAL = colors.HexColor("#087F82")
INK = colors.HexColor("#263B48")
MUTED = colors.HexColor("#5B6F7A")
LINE = colors.HexColor("#D7E3E7")
WIDTH = A4[0] - 36 * mm

STYLES = {
    "title": ParagraphStyle("title", fontName="Helvetica-Bold", fontSize=23,
                            leading=27, textColor=NAVY, spaceAfter=8),
    "section": ParagraphStyle("section", fontName="Helvetica-Bold", fontSize=17,
                              leading=21, textColor=NAVY, spaceAfter=9),
    "sub": ParagraphStyle("sub", fontName="Helvetica-Bold", fontSize=11,
                          leading=14, textColor=TEAL, spaceBefore=10,
                          spaceAfter=4, keepWithNext=True),
    "body": ParagraphStyle("body", fontName="Helvetica", fontSize=10,
                           leading=13.5, textColor=INK, spaceAfter=7),
    "small": ParagraphStyle("small", fontName="Helvetica", fontSize=8.4,
                            leading=11, textColor=MUTED, spaceAfter=6),
    "cell": ParagraphStyle("cell", fontName="Helvetica", fontSize=9.2,
                           leading=12.3, textColor=INK),
    "head": ParagraphStyle("head", fontName="Helvetica-Bold", fontSize=9.2,
                           leading=12.3, textColor=colors.white),
}


def inline(value):
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", escape(value))


def para(value, style="body"):
    return Paragraph(inline(value), STYLES[style])


def table(rows):
    item = Table(
        [[para(value, "head" if n == 0 else "cell") for value in row]
         for n, row in enumerate(rows)],
        colWidths=[WIDTH * .22, WIDTH * .78], hAlign="LEFT", repeatRows=1,
    )
    item.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1),
         [colors.HexColor("#EEF5F6"), colors.white]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("LINEBELOW", (0, 0), (-1, -1), .4, LINE),
    ]))
    return item


def decorate(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(TEAL)
    canvas.rect(0, A4[1] - 5 * mm, A4[0], 5 * mm, fill=1, stroke=0)
    canvas.setStrokeColor(LINE)
    canvas.line(18 * mm, 15 * mm, A4[0] - 18 * mm, 15 * mm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 10 * mm, "SKILLCONNECT  |  Codebase review  |  14 October 2026")
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"{doc.page} / 2")
    canvas.restoreState()


def main():
    lines = SOURCE.read_text().splitlines()
    story = []
    i = 0
    evidence = False
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        if not line:
            continue
        if line == "<!-- PAGEBREAK -->":
            story.append(PageBreak())
        elif line.startswith("# "):
            story.append(para("SkillConnect", "title"))
            story.append(para("Current State &amp; Future Scope".replace("&amp;", "&"), "section"))
        elif line.startswith("## "):
            story.append(para(line[3:], "section"))
            story.append(HRFlowable(width=WIDTH, thickness=1, color=TEAL, spaceAfter=9))
        elif line.startswith("### "):
            evidence = line == "### Evidence and scope"
            story.append(para(line[4:], "sub"))
        elif line.startswith("|"):
            rows = [[cell.strip() for cell in line.strip("|").split("|")]]
            while i < len(lines) and lines[i].strip().startswith("|"):
                row = [cell.strip() for cell in lines[i].strip().strip("|").split("|")]
                i += 1
                if not all(re.fullmatch(r":?-+:?", cell) for cell in row):
                    rows.append(row)
            story.extend([table(rows), Spacer(1, 4)])
        elif line.startswith("- "):
            story.append(para("• " + line[2:]))
        else:
            style = "small" if evidence or line.startswith("Codebase review") else "body"
            story.append(para(line, style))

    doc = SimpleDocTemplate(
        str(OUTPUT), pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
        topMargin=15 * mm, bottomMargin=21 * mm,
        title="SkillConnect: Current State and Future Scope",
        author="SkillConnect", subject="Concise codebase assessment and improvement priorities",
    )
    doc.build(story, onFirstPage=decorate, onLaterPages=decorate)
    print(OUTPUT)


if __name__ == "__main__":
    main()
