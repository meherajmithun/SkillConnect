"""Build the viva guides. Requires reportlab; PDF review also uses PyMuPDF.

Run from anywhere: python docs/viva/build_pdf.py
The source Markdown remains the editable study document.
"""

from pathlib import Path
import re
from html import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, PageBreak,
    KeepTogether, Table, TableStyle, Image, HRFlowable,
)
from reportlab.platypus.tableofcontents import TableOfContents


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SOURCE = HERE / "SkillConnect_Viva_Guide.md"
NAVY = colors.HexColor("#123653")
TEAL = colors.HexColor("#087f82")
INK = colors.HexColor("#202f3b")
MUTED = colors.HexColor("#526473")
LIGHT = colors.HexColor("#edf4f8")
LINE = colors.HexColor("#d6e2e9")
PAGE_W, PAGE_H = A4
MARGIN = 18 * mm
WIDTH = PAGE_W - 2 * MARGIN

styles = getSampleStyleSheet()
styles.add(ParagraphStyle("BodyV", fontName="Helvetica", fontSize=10.2,
    leading=14.5, textColor=INK, spaceAfter=7, splitLongWords=True))
styles.add(ParagraphStyle("QuestionV", parent=styles["BodyV"], fontName="Helvetica-Bold",
    fontSize=10.5, leading=14, textColor=NAVY, spaceBefore=8, spaceAfter=4,
    keepWithNext=True))
styles.add(ParagraphStyle("ChapterV", fontName="Helvetica-Bold", fontSize=20,
    leading=25, textColor=NAVY, spaceAfter=14, keepWithNext=True))
styles.add(ParagraphStyle("SubV", parent=styles["QuestionV"], fontSize=12, leading=16))
styles.add(ParagraphStyle("SmallV", parent=styles["BodyV"], fontSize=8.8, leading=12))
styles.add(ParagraphStyle("CellV", parent=styles["BodyV"], fontSize=8.7,
    leading=11.8, spaceAfter=0))
styles.add(ParagraphStyle("CellHeadV", parent=styles["CellV"], fontName="Helvetica-Bold",
    textColor=colors.white))
styles.add(ParagraphStyle("CoverV", fontName="Helvetica-Bold", fontSize=38,
    leading=43, textColor=NAVY, spaceAfter=20))
styles.add(ParagraphStyle("CoverSubV", parent=styles["BodyV"], fontSize=17,
    leading=24, textColor=TEAL, spaceAfter=20))


def inline(value):
    value = escape(value)
    value = value.replace("&lt;br/&gt;", "<br/>")
    value = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)",
        lambda m: f'<a href="{m[2]}" color="#087f82">{m[1]}</a>', value)
    value = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", value)
    value = re.sub(r"`([^`]+)`", r'<font name="Courier" size="9">\1</font>', value)
    return value


class GuideDoc(BaseDocTemplate):
    def __init__(self, filename, label):
        super().__init__(str(filename), pagesize=A4, leftMargin=MARGIN,
            rightMargin=MARGIN, topMargin=21*mm, bottomMargin=18*mm,
            title=label, author="SkillConnect Project Study Guide",
            subject="Project-management viva questions grounded in SkillConnect source")
        self.label = label
        self.chapter = ""
        self.keys = {}
        frame = Frame(MARGIN, 18*mm, WIDTH, PAGE_H-39*mm,
                      leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
        self.addPageTemplates(PageTemplate(id="body", frames=[frame], onPage=self.decorate))

    def beforeDocument(self):
        self.keys = {}
        self.chapter = ""

    def decorate(self, canvas, doc):
        canvas.saveState()
        if doc.page > 1:
            canvas.setStrokeColor(LINE)
            canvas.line(MARGIN, PAGE_H-14*mm, PAGE_W-MARGIN, PAGE_H-14*mm)
            canvas.setFont("Helvetica-Bold", 8)
            canvas.setFillColor(NAVY)
            canvas.drawString(MARGIN, PAGE_H-11*mm, "SKILLCONNECT / VIVA PREPARATION")
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(MARGIN, 10*mm, "13 October 2026 | Based on the inspected working tree")
        canvas.drawRightString(PAGE_W-MARGIN, 10*mm, str(doc.page))
        canvas.restoreState()

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph) and flowable.style.name == "ChapterV":
            title = flowable.getPlainText()
            if title == "Contents":
                return
            key = "chapter_" + re.sub(r"\W+", "_", title)
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(title, key, level=0, closed=False)
            self.notify("TOCEntry", (0, title, self.page, key))


def p(text, style="BodyV"):
    return Paragraph(inline(text), styles[style])


def chapter(title):
    return [PageBreak(), p(title, "ChapterV"),
            HRFlowable(width=WIDTH, thickness=1.6, color=TEAL, spaceAfter=12)]


def make_table(rows):
    cells = [[p(cell, "CellHeadV" if r == 0 else "CellV") for cell in row]
             for r, row in enumerate(rows)]
    headers = rows[0]
    if len(headers) == 2:
        widths = [WIDTH*.32, WIDTH*.68]
    elif headers[0] == "Sprint / weeks":
        widths = [WIDTH*.18, WIDTH*.14, WIDTH*.68]
    elif headers[0] == "Candidate backlog item":
        widths = [WIDTH*.32, WIDTH*.25, WIDTH*.43]
    else:
        widths = [WIDTH*.15, WIDTH*.39, WIDTH*.46]
    table = Table(cells, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), NAVY),
        ("VALIGN", (0,0), (-1,-1), "TOP"),
        ("LEFTPADDING", (0,0), (-1,-1), 7),
        ("RIGHTPADDING", (0,0), (-1,-1), 7),
        ("TOPPADDING", (0,0), (-1,-1), 7),
        ("BOTTOMPADDING", (0,0), (-1,-1), 7),
        ("ROWBACKGROUNDS", (0,1), (-1,-1), [LIGHT, colors.white]),
        ("LINEBELOW", (0,0), (-1,0), .6, NAVY),
        ("LINEBELOW", (0,1), (-1,-1), .35, LINE),
    ]))
    return [table, Spacer(1,10)]


def blocks(text):
    """Parse the deliberately small, consistent Markdown dialect of this guide."""
    lines = text.splitlines()
    out = []
    i = 0
    in_questions = False
    while i < len(lines):
        line = lines[i].strip()
        if not line or line.startswith("# "):
            i += 1
            continue
        if line.startswith("## "):
            title = line[3:]
            in_questions = bool(re.match(r"\d{2}\.", title))
            out.extend(chapter(title))
            i += 1
        elif line.startswith("### "):
            title = line[4:]
            i += 1
            paragraph = []
            while i < len(lines) and not lines[i].strip():
                i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].strip().startswith(("### ", "## ", "|", "![")):
                paragraph.append(lines[i].strip())
                i += 1
            q = p(title, "QuestionV" if in_questions else "SubV")
            answer = p(" ".join(paragraph)) if paragraph else Spacer(1,1)
            out.append(KeepTogether([q, answer]))
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                row = [s.strip() for s in lines[i].strip().strip("|").split("|")]
                if not all(re.match(r"^:?-+:?$", s) for s in row):
                    rows.append(row)
                i += 1
            out.extend(make_table(rows))
        elif line.startswith("!["):
            image = Image(str(ROOT / "WBS.png"))
            ratio = image.imageHeight / image.imageWidth
            image.drawWidth = WIDTH
            image.drawHeight = WIDTH * ratio
            out.extend([Spacer(1,12), image, Spacer(1,12)])
            i += 1
        else:
            paragraph = [line]
            i += 1
            if not line.startswith("- "):
                while i < len(lines) and lines[i].strip() and not lines[i].strip().startswith(("#", "|", "![", "- ")):
                    paragraph.append(lines[i].strip())
                    i += 1
            out.append(p(" ".join(paragraph)))
    return out


def number_questions(text):
    active = False
    counter = 0
    core = 0
    numbered = []
    for line in text.splitlines():
        if line.startswith("## "):
            active = bool(re.match(r"## \d{2}\.", line))
        if active and line.startswith("### "):
            title = re.sub(r"^Q\d+\s+(?:\[CORE\]\s+)?", "", line[4:])
            important = title.startswith("*") or "[CORE]" in line
            title = title.lstrip("*")
            counter += 1
            core += int(important)
            line = f"### Q{counter:03d} {'[CORE] ' if important else ''}{title}"
        numbered.append(line)
    return "\n".join(numbered) + "\n", counter, core


def cover(total, core, quick=False):
    return [Spacer(1,34*mm), p("SKILLCONNECT", "CoverV"),
        p("Viva questions<br/>and short answers" if not quick else "Last-minute<br/>revision sheet", "CoverSubV"),
        HRFlowable(width=WIDTH, thickness=3, color=TEAL, spaceAfter=22),
        p(f"{total} numbered questions | {core} priority questions" if not quick else
          "Project facts, model choice, key definitions and demonstration reminders", "SubV"),
        p("SRS / WBS / Requirements engineering / Use cases / Exceptions / Scrum / XP / Backlogs / Estimation / Testing / Risk"),
        Spacer(1,20), p("Prepared for viva revision: 14 October 2026", "SubV"),
        p("Based on SkillConnect's proposal, supplied WBS, planning documents, Flutter source and active JavaScript backend."),
        Spacer(1,16), p("How to answer: define the term, give a SkillConnect example, then explain why it matters. Keep the first answer short; expand when asked."),
        p("Active stack: Flutter/Dart + Node.js/Express + PostgreSQL (SQLite locally). Development approach: Agile with a Scrum-based four-sprint plan.", "SmallV")]


def main():
    text, total, core = number_questions(SOURCE.read_text())
    SOURCE.write_text(text)
    toc = TableOfContents()
    toc.levelStyles = [ParagraphStyle("ContentsV", fontName="Helvetica",
        fontSize=10.2, leading=15, textColor=INK, leftIndent=0,
        spaceBefore=0, spaceAfter=0, firstLineIndent=0, alignment=TA_LEFT)]
    story = cover(total, core) + [PageBreak(), p("Contents", "ChapterV"),
        p("[CORE] marks priority questions to study first. Chapter links and PDF bookmarks support quick navigation.", "SmallV"), toc]
    story += blocks(text)
    full = HERE / "SkillConnect_Viva_Questions_and_Short_Answers.pdf"
    GuideDoc(full, "SkillConnect Viva Questions and Short Answers").multiBuild(story)

    quick = text.split("## Quick revision: the answers to learn tonight\n",1)[1].split("## 01.",1)[0]
    quick_text = "## Key project facts\n\n" + (
        "Current stack: Flutter/Dart and Node.js/Express; PostgreSQL in deployment and SQLite locally. The retained original proposal describes Python historically.\n\n"
        "Latest local Node checks: 35 tests passed; syntax and formatting passed. No new Flutter/device/provider/UAT results are claimed by this guide.\n\n"
        "Plan: Agile Scrum, four two-week sprints, eight planned weeks. Actual team names/dates, stakeholder approvals and measured velocity are not recorded.\n\n"
        "## 25 answers to practice\n\n" + quick +
        "## WBS and booking rules\n\n"
        "Sprint 1 (weeks 1-2): requirements, plan, stakeholders, flows, prototype, setup. Sprint 2 (3-4): authentication, customer/professional modules, database/API. Sprint 3 (5-6): booking, reviews, promotions, admin, notifications. Sprint 4 (7-8): testing, UAT, fixes, deployment, documentation.\n\n"
        "![WBS](../../WBS.png)\n\n"
        "Booking: pending -> accepted -> completed; pending -> rejected/cancelled; accepted -> cancelled by customer. Completed/rejected/cancelled are terminal. Pending and accepted appointments reserve time.\n\n"
        "Reviews: owning customer, completed booking, rating 1-5, once per booking. Promotions: paid, correct category/area, unexpired; duplicate confirmation cannot extend the purchase.\n\n"
        "## Follow-ups and final rehearsal\n\n"
        "Do not confuse development model (Agile/Scrum), business model (freemium marketplace) and architecture (client/API/database). Scrum organizes work; XP strengthens engineering.\n\n"
        "Do not call a planning-only phase strict Scrum: a proper sprint should deliver usable increments, and testing should happen throughout. The supplied WBS is a high-level Scrum-based academic plan.\n\n"
        "SRS defines required product behavior; WBS breaks down project work; backlog orders evolving product work; Gantt/network schedules work and dependencies.\n\n"
        "Constraint restricts choices; limitation describes missing capability; risk is uncertain; issue has already happened. Verification checks specifications; validation checks real user needs.\n\n"
        "PERT: (O+4M+P)/6. Critical path: longest dependency chain. CPI=EV/AC; SPI=EV/PV. Velocity is completed points/sprint, not hours or individual productivity.\n\n"
        "Prepare both customer and professional demo journeys. Explain offline data as per-device simulation; live collaboration requires the server. No escrow, refunds, live GPS or route distance are implemented.\n\n"
        "If asked about research or UAT, say what was actually done: document/code analysis and automated checks are evidenced; recorded interviews and acceptance are still pending.\n\n"
        "Practice: search Electrician/Mirpur -> profile -> quote -> professional reply -> customer accepts -> professional accepts/completes -> customer review. Then explain a stale quote, overlapping booking and unpaid promotion.\n\n"
        "For detailed questions, evidence and references, use the companion full viva guide."
    )
    quick_pdf = HERE / "SkillConnect_Last_Minute_Revision.pdf"
    GuideDoc(quick_pdf, "SkillConnect Last-Minute Viva Revision").build(
        cover(total, core, quick=True) + blocks(quick_text))
    print(f"Questions: {total}; priority: {core}")
    print(full)
    print(quick_pdf)


if __name__ == "__main__":
    main()
