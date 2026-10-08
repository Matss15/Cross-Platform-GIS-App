"""Builds docs/SYSTEM_AND_HARDWARE.pdf from docs/SYSTEM_AND_HARDWARE.md.

Usage:  python tools/docs-pdf/build_pdf.py
Needs:  pip install markdown, and Google Chrome or Microsoft Edge installed.
"""

import pathlib
import subprocess
import sys
import tempfile

import markdown

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs" / "SYSTEM_AND_HARDWARE.md"
HTML_OUT = ROOT / "docs" / "SYSTEM_AND_HARDWARE.html"
PDF_OUT = ROOT / "docs" / "SYSTEM_AND_HARDWARE.pdf"

BROWSERS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]

CSS = """
@page { size: A4; margin: 16mm 14mm 18mm 14mm; }
body { font-family: "Segoe UI", Arial, sans-serif; font-size: 10pt; line-height: 1.45;
       color: #1d1d1f; }
h1 { font-size: 20pt; color: #b3261e; border-bottom: 3px solid #b3261e;
     padding-bottom: 6px; margin-top: 0; }
h2 { font-size: 14pt; color: #b3261e; margin-top: 22px; border-bottom: 1px solid #ddd;
     padding-bottom: 3px; page-break-after: avoid; }
h3 { font-size: 11.5pt; margin-top: 16px; page-break-after: avoid; }
table { border-collapse: collapse; width: 100%; margin: 8px 0 12px; font-size: 9pt;
        page-break-inside: avoid; }
th { background: #f3e5e4; text-align: left; }
th, td { border: 1px solid #ccc; padding: 4px 6px; vertical-align: top; }
code { font-family: Consolas, "Courier New", monospace; font-size: 8.8pt;
       background: #f4f4f4; padding: 0 3px; border-radius: 3px; }
pre { background: #f7f7f7; border: 1px solid #ddd; border-radius: 4px; padding: 8px;
      font-size: 7.8pt; line-height: 1.3; overflow: hidden; white-space: pre;
      page-break-inside: avoid; }
pre code { background: none; padding: 0; font-size: inherit; }
.cover-note { color: #555; font-size: 9pt; }
"""


def main() -> int:
    body = markdown.markdown(
        SOURCE.read_text(encoding="utf-8"),
        extensions=["tables", "fenced_code"],
    )
    html = (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<title>BFP Rosario GIS - System and Hardware</title>"
        f"<style>{CSS}</style></head><body>{body}</body></html>"
    )
    HTML_OUT.write_text(html, encoding="utf-8")

    browser = next((b for b in BROWSERS if pathlib.Path(b).exists()), None)
    if browser is None:
        print("Chrome or Edge not found; open the HTML file and print it to PDF.")
        return 1
    before = PDF_OUT.stat().st_mtime if PDF_OUT.exists() else 0
    # A separate profile keeps an already open Chrome from swallowing the job.
    with tempfile.TemporaryDirectory() as profile:
        subprocess.run(
            [browser, "--headless", "--disable-gpu", "--no-pdf-header-footer",
             f"--user-data-dir={profile}",
             f"--print-to-pdf={PDF_OUT}", HTML_OUT.as_uri()],
            check=True, capture_output=True,
        )
    HTML_OUT.unlink()
    if not PDF_OUT.exists() or PDF_OUT.stat().st_mtime == before:
        print("PDF was not updated; close any viewer that has it open and retry.")
        return 1
    print(f"Wrote {PDF_OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
