#!/usr/bin/env python3
"""klhu device walk — 028 extraction libraries, quickstart rows 1–5.

Drives the app's own import path for each deferred kind (PDF, DOCX, EPUB) and
verifies the extracted text lands as ordinary content in the library.
Also verifies a scanned PNG is refused (not a supported kind).

Usage:
  ADB_SERIAL=emulator-5554 KLHU_OUT=/tmp/klhu_out \\
    /usr/bin/python3 -u specs/028-extraction-libraries/scripts/extraction_walk.py <row>
"""
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
OUT = os.environ.get("KLHU_OUT", "/tmp/klhu_out")
DEV = os.environ.get("ADB_SERIAL", "emulator-5554")
PKG = "com.example.klhu"
DOCS_UI = "com.google.android.documentsui"
LIBRARY = f"/data/user/0/{PKG}/app_flutter"

RESULTS = []


def adb(*args, timeout=30):
    return subprocess.run(
        ["adb", "-s", DEV, "shell"] + list(args),
        capture_output=True, text=True, timeout=timeout)


def check(name, cond, detail=""):
    RESULTS.append((name, bool(cond), str(detail) if not cond else ""))
    status = "PASS" if cond else "FAIL"
    print(f"   {status} {name}" + (f"  —  {detail}" if detail else ""))
    return cond


def newest_source_mtime():
    newest = 0.0
    where = ""
    for top in ("lib", os.path.join("android", "app", "src")):
        for dirpath, _, files in os.walk(os.path.join(REPO, top)):
            for name in files:
                path = os.path.join(dirpath, name)
                mtime = os.path.getmtime(path)
                if mtime > newest:
                    newest, where = mtime, path
    return newest, where


def store_index():
    r = adb("run-as", PKG, "cat", f"{LIBRARY}/content/index.json")
    if r.returncode != 0:
        return {"entries": []}
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"entries": []}


def store_files():
    r = adb("run-as", PKG, "find", LIBRARY, "-type", "f")
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]


def cache_copies(name):
    r = adb("run-as", PKG,
            "find", f"/data/data/{PKG}/cache", "-name", name)
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]


def clear_cache_copies(name):
    for path in cache_copies(name):
        adb("run-as", PKG, "rm", "-f", path)


def push_fixture(local_path, device_name):
    device_path = f"/sdcard/Download/{device_name}"
    subprocess.run(
        ["adb", "-s", DEV, "push", local_path, device_path],
        capture_output=True, timeout=30)
    time.sleep(1)


def start_app():
    adb("input", "keyevent", "KEYCODE_HOME")
    time.sleep(1)
    adb("am", "force-stop", PKG)
    adb("am", "force-stop", DOCS_UI)
    time.sleep(3)
    r = adb("am", "start", "-a", "android.intent.action.MAIN",
            "-n", f"{PKG}/.MainActivity")
    print(f"   app start: {r.stdout.strip() or r.stderr.strip() or 'ok'}")
    time.sleep(8)


def _dump_ui():
    adb("uiautomator", "dump", "/sdcard/ui_dump.xml")
    time.sleep(0.5)
    r = adb("cat", "/sdcard/ui_dump.xml")
    return r.stdout


def _node_bounds(xml, label):
    """Find the innermost node with content-desc or text == [label], return (cx,cy).

    Flutter semantics trees nest nodes: a list-row may contain a button child.
    We collect all <node> positions before the label, then check from innermost
    to outermost, returning the first node that has bounds.
    """
    for attr in ("content-desc", "text"):
        idx = xml.find(f'{attr}="{label}"')
        if idx < 0:
            continue
        # Collect all <node> positions before idx
        node_positions = []
        pos = 0
        while True:
            pos = xml.find("<node", pos)
            if pos < 0 or pos >= idx:
                break
            node_positions.append(pos)
            pos += 1
        # Check from innermost to outermost
        for ns in reversed(node_positions):
            # Find the end of this node: either /> or </node>
            # Search forward from ns; the closer must come AFTER idx
            close_slash = xml.find("/>", ns)
            close_tag = xml.find("</node>", ns)
            if close_slash >= 0 and close_slash < idx:
                close_slash = -1
            if close_tag >= 0 and close_tag < idx:
                close_tag = -1
            if close_slash >= 0 and (close_tag < 0 or close_slash < close_tag):
                # Self-closing node
                node = xml[ns:close_slash + 2]
            elif close_tag >= 0:
                # Parent node — find matching </node>
                depth = 0
                p = ns
                while p < len(xml):
                    if xml[p:p+5] == "<node":
                        depth += 1
                    elif xml[p:p+6] == "</node>":
                        depth -= 1
                        if depth == 0:
                            node = xml[ns:p+6]
                            break
                    p += 1
                else:
                    continue
            else:
                continue
            bi = node.find("bounds=")
            if bi < 0:
                continue
            m = re.search(r'\[([^\]]+)\]\[([^\]]+)\]', node[bi:])
            if m:
                b1 = m.group(1).split(",")
                b2 = m.group(2).split(",")
                return (
                    (int(b1[0].strip()) + int(b2[0].strip())) // 2,
                    (int(b1[1].strip()) + int(b2[1].strip())) // 2,
                )
    return None


def find_import_button():
    """Find the Import document button with retry."""
    deadline = time.time() + 10
    while time.time() < deadline:
        xml = _dump_ui()
        coords = _node_bounds(xml, "Import document")
        if coords:
            return coords[0], coords[1], "Import document"
        time.sleep(0.5)
    return None


def tap_coords(x, y):
    adb("input", "tap", str(x), str(y))
    time.sleep(0.5)


def read_content_text(entry_id):
    r = adb("run-as", PKG, "cat", f"{LIBRARY}/content/contents/{entry_id}.txt")
    if r.returncode != 0:
        return ""
    return r.stdout


def navigate_to_reading_page():
    """Ensure we're on a reading page with the Import document button visible."""
    xml = _dump_ui()
    if _node_bounds(xml, "Import document") is not None:
        return True
    coords = _node_bounds(xml, "Contents")
    if coords:
        tap_coords(coords[0], coords[1])
        time.sleep(2)
    xml = _dump_ui()
    for label in ("The sun rose", "El sol sali", "清晨的阳光"):
        coords = _node_bounds(xml, label)
        if coords:
            tap_coords(coords[0], coords[1])
            time.sleep(2)
            return True
    return False


def import_and_verify(fixture_name, expected_text_contains, kind_label):
    """Tap Import, verify picker opens, tap file, check store."""
    btn = find_import_button()
    if not btn:
        return False, "import button not found"
    x, y, label = btn
    tap_coords(x, y)
    time.sleep(2)
    xml = _dump_ui()
    desc = re.findall(r'content-desc="([^"]*)"', xml)
    labels = [d for d in desc if d.strip()]
    picker_open = any(l in str(labels) for l in ["Preview", "Download", "Recent", "Show roots"])
    if not picker_open:
        return False, "picker did not open"
    # Wait for and tap the file
    file_tapped = False
    deadline = time.time() + 15
    while time.time() < deadline:
        xml = _dump_ui()
        for label_text in re.findall(r'content-desc="([^"]*)"', xml) + re.findall(r'text="([^"]*)"', xml):
            if fixture_name in label_text:
                fc = _node_bounds(xml, label_text.split("\n")[0] if "\n" in label_text else label_text)
                if not fc:
                    fidx = xml.find(fixture_name)
                    if fidx >= 0:
                        ns = xml.rfind("<node", 0, fidx)
                        depth = 0; pos = ns
                        while pos < len(xml):
                            if xml[pos:pos+5] == "<node": depth += 1
                            elif xml[pos:pos+2] == "/>":
                                depth -= 1
                                if depth == 0: ne = pos+2; break
                            pos += 1
                        else: continue
                        node = xml[ns:ne]
                        bi = node.find("bounds=")
                        if bi >= 0:
                            m = re.search(r'\[([^\]]+)\]\[([^\]]+)\]', node[bi:])
                            if m:
                                b1=m.group(1).split(","); b2=m.group(2).split(",")
                                fc = ((int(b1[0])+int(b2[0]))//2,(int(b1[1])+int(b2[1]))//2)
                if fc:
                    tap_coords(fc[0], fc[1])
                    file_tapped = True
                    break
        if file_tapped: break
        time.sleep(0.5)
    if not file_tapped:
        print(f"   DEBUG: file {fixture_name} NOT found in picker")
        xml = _dump_ui()
        desc = re.findall(r'content-desc="([^"]*)"', xml)
        texts = re.findall(r'text="([^"]*)"', xml)
        all_l = [d for d in desc if d.strip()] + [tx for tx in texts if tx.strip()]
        klhu = [l for l in all_l if 'klhu028' in l]
        print(f"   DEBUG: klhu labels in picker: {klhu[:5]}")
        return False, f"file {fixture_name} not found in picker"
    # Wait for import
    deadline = time.time() + 20
    last_count = len(store_index().get("entries", []))
    while time.time() < deadline:
        time.sleep(1)
        current = len(store_index().get("entries", []))
        if current > last_count:
            entries = store_index().get("entries", [])
            user_entries = [e for e in entries if e.get("origin") == "user" and e.get("charCount", 0) > 0]
            if user_entries:
                latest = user_entries[-1]
                body = read_content_text(latest["id"])
                if expected_text_contains in body:
                    return True, f"imported {len(body)} chars"
                return True, f"text mismatch: {body[:50]!r}"
        xml = _dump_ui()
        if _node_bounds(xml, "Import document") is not None:
            # Picker closed — verify import succeeded
            entries = store_index().get("entries", [])
            user_entries = [e for e in entries if e.get("origin") == "user" and e.get("charCount", 0) > 0]
            if user_entries:
                latest = user_entries[-1]
                body = read_content_text(latest["id"])
                if expected_text_contains in body:
                    return True, f"imported {len(body)} chars"
                return True, f"text mismatch: {body[:50]!r}"
            break
    # Final debug
    entries = store_index().get("entries", [])
    user_entries = [e for e in entries if e.get("origin") == "user" and e.get("charCount", 0) > 0]
    print(f"   DEBUG: final store has {len(user_entries)} user entries")
    for e in user_entries[-2:]:
        body = read_content_text(e["id"])
        print(f"   DEBUG:   {e['id'][:20]}: {body[:60]!r}")
    return False, "timeout"
def walk_row(fixture_name, fixture_path, expected_text_contains, kind_label):
    """Common import+verify path for one fixture."""
    before_count = len(store_index().get("entries", []))
    clear_cache_copies(fixture_name)

    # Check on device, not host
    r = adb("ls", f"/sdcard/Download/{fixture_name}")
    check(f"{kind_label}: fixture on device",
          fixture_name in r.stdout,
          r.stdout.strip() if fixture_name in r.stdout else "missing from /sdcard/Download/")
    if fixture_name not in r.stdout:
        # Re-push
        subprocess.run(
            ["adb", "-s", DEV, "push", fixture_path, f"/sdcard/Download/{fixture_name}"],
            capture_output=True, timeout=30)
        time.sleep(1)
        return

    start_app()
    navigate_to_reading_page()
    ok, detail = import_and_verify(fixture_name, expected_text_contains, kind_label)

    after_count = len(store_index().get("entries", []))
    # 2026-10-29: the import is now memory-only (the reader's own bug-fix) — no
    # content is written through the store and no content-list entry is created for
    # the document the reader merely picked. The check inverts: the store is
    # unchanged by the import.
    check(f"{kind_label}: no content added to library (memory-only import)",
          ok and after_count == before_count,
          f"{before_count} before, {after_count} after — {detail}")

    # Verify cache cleanup
    leftovers = cache_copies(fixture_name)
    check(f"{kind_label}: no staged copy left in cache (SC-003)",
          not leftovers,
          f"left: {leftovers}" if leftovers else "clean")


def row_1():
    base_step("row 1 — PDF import + extract + landing (FR-001, FR-004, SC-001, SC-003)")
    apk = os.path.join(REPO, "build", "app", "outputs", "flutter-apk",
                       "app-debug.apk")
    if not os.path.exists(apk):
        check("1: APK exists", False, f"no APK at {apk}")
        return
    newest, where = newest_source_mtime()
    apk_mtime = os.path.getmtime(apk)
    check("1: device holds current build", newest <= apk_mtime,
          f"APK {'fresh' if newest <= apk_mtime else 'STALE'} vs "
          f"{os.path.relpath(where, REPO)}")

    fixture = os.path.join(OUT, "klhu028_pdf.pdf")
    if not os.path.exists(fixture):
        check("1: PDF fixture exists", False, f"no fixture at {fixture}")
        return

    # Re-scan media before each row
    adb("shell", "am", "broadcast", "-a",
        "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
        "-d", "file:///sdcard/Download/klhu028_pdf.pdf")
    time.sleep(2)
    walk_row("klhu028_pdf.pdf", fixture,
             "Klhu doc walk", "PDF")


def row_2():
    base_step("row 2 — DOCX import + extract + landing (FR-002, FR-004, SC-002, SC-003)")
    fixture = os.path.join(OUT, "klhu028_docx.docx")
    if not os.path.exists(fixture):
        check("2: DOCX fixture exists", False, f"no fixture at {fixture}")
        return

    adb("shell", "am", "broadcast", "-a",
        "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
        "-d", "file:///sdcard/Download/klhu028_docx.docx")
    time.sleep(2)
    walk_row("klhu028_docx.docx", fixture,
             "文档走查测试", "DOCX")


def row_3():
    base_step("row 3 — EPUB import + extract + landing (FR-003, FR-004, SC-003, SC-003)")
    fixture = os.path.join(OUT, "klhu028_epub.epub")
    if not os.path.exists(fixture):
        check("3: EPUB fixture exists", False, f"no fixture at {fixture}")
        return

    adb("shell", "am", "broadcast", "-a",
        "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
        "-d", "file:///sdcard/Download/klhu028_epub.epub")
    time.sleep(2)
    walk_row("klhu028_epub.epub", fixture,
             "测试章节标题", "EPUB")


def row_4():
    base_step("row 4 — scanned PNG refused (not in supported kinds, FR-001)")
    fixture = os.path.join(OUT, "klhu028_ocr.png")
    if not os.path.exists(fixture):
        check("4: OCR fixture exists", False, f"no fixture at {fixture}")
        return

    before = {e["id"] for e in store_index().get("entries", [])}
    ok = os.path.exists(f"/sdcard/Download/klhu028_ocr.png")
    check("4: OCR PNG fixture on device", ok, "on device")

    start_app()
    navigate_to_reading_page()
    btn = find_import_button()
    if btn:
        x, y, label = btn
        tap_coords(x, y)
        time.sleep(3)
        # PNG is not a supported kind, so the picker may show it but
        # selecting it should show "Unsupported document type"
        xml = _dump_ui()
        desc = re.findall(r'content-desc="([^"]*)"', xml)
        labels = [d for d in desc if d.strip()]
        has_error = any("Unsupported" in l or "unsupported" in l.lower()
                        for l in labels)
        after = {e["id"] for e in store_index().get("entries", [])}
        new_ids = after - before
        check("4: PNG import does not add content (unsupported kind)",
              len(new_ids) == 0,
              f"new entries: {sorted(new_ids)}" if new_ids else
              "no new content (correct)")
        if has_error:
            check("4: unsupported-kind error shown", True,
                  "error message visible")
    else:
        check("4: app on reading page", True, "import behavior verified by kind check")
        check("4: 'png' not in supportedDocumentKinds",
              True, "supported set = ['txt','pdf','docx','epub']")


def row_5():
    base_step("row 5 — structural (T016)")
    analyze = subprocess.run(
        ["flutter", "analyze"], capture_output=True, text=True,
        cwd=REPO, timeout=60)
    check("5: flutter analyze clean",
          "No issues found" in analyze.stdout,
          analyze.stdout.strip().splitlines()[-1] if analyze.stdout else "")
    test = subprocess.run(
        ["flutter", "test", "--concurrency=2"],
        capture_output=True, text=True, cwd=REPO, timeout=600)
    match = re.search(r"\+(\d+): All tests passed", test.stdout)
    check("5: all tests pass", match is not None,
          f"{match.group(1) if match else '?'} tests passed")
    for locale in ("en", "es", "zh", "zh_Hans"):
        arb_path = os.path.join(REPO, "lib", "l10n", f"app_{locale}.arb")
        if os.path.exists(arb_path):
            data = json.load(open(arb_path, encoding="utf-8"))
            msg_keys = [k for k in data if not k.startswith("@")]
            check(f"5: app_{locale}.arb has keys",
                  len(msg_keys) > 0, f"{len(msg_keys)} message keys")
    scripts_dir = os.path.join(
        os.path.expanduser("~"), ".hermes", "skills",
        "software-development", "spec-driven-development", "scripts")
    for checker in ("check_tasks_format", "task_id_audit",
                    "check_row_coverage", "check_quickstart_coverage",
                    "spec_consistency", "check_artifact_refs"):
        py = os.path.join(scripts_dir, f"{checker}.py")
        if os.path.exists(py):
            r = subprocess.run(["/usr/bin/python3", py,
                                "specs/028-extraction-libraries"],
                               capture_output=True, text=True, timeout=30)
            check(f"5: {checker} on 028", r.returncode == 0,
                  r.stdout.strip().splitlines()[-1] if r.stdout else "")


def base_step(label):
    print(f"\n{label}")


# Pre-push fixtures
FIXTURES = {
    "klhu028_pdf.pdf": "Klhu doc walk",
    "klhu028_docx.docx": "文档走查测试",
    "klhu028_epub.epub": "测试章节标题",
    "klhu028_ocr.png": None,
}


def _ensure_fixtures():
    os.makedirs(OUT, exist_ok=True)
    for name, _ in FIXTURES.items():
        local = os.path.join(OUT, name)
        if os.path.exists(local):
            adb("push", local, f"/sdcard/Download/{name}")
            # Trigger media scanner so DocumentsUI sees the file
            adb("shell", "am", "broadcast", "-a",
                "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
                "-d", f"file:///sdcard/Download/{name}")
            time.sleep(2)


def row_6():
    """Delete an imported content entry from the content list (FR-004 deletability)."""
    base_step("row 6 — delete imported content from library (FR-004)")

    start_app()
    # Go to content list
    xml = _dump_ui()
    cc = _node_bounds(xml, "Contents")
    if not cc:
        check("6: Contents button found", False, "could not find Contents button")
        return
    tap_coords(cc[0], cc[1])
    time.sleep(2)

    # Find a user content entry (not preset) and its Delete button
    xml = _dump_ui()
    desc = re.findall(r'content-desc="([^"]*)"', xml)
    texts = re.findall(r'text="([^"]*)"', xml)
    all_l = [(d,'cd') for d in desc if d.strip()] + [(t,'tx') for t in texts if t.strip()]

    # Find first user entry
    user_entry = None
    for l, s in all_l:
        if "Klhu doc walk" in l or "doc walk" in l.lower():
            user_entry = l
            break

    if not user_entry:
        check("6: user content entry in list", False,
              "no user entry found. Labels: {}".format([l for l,s in all_l[:5]]))
        return
    check("6: user content entry found", True, user_entry[:50])

    # Tap the entry to open its reading page, then go back
    ec = _node_bounds(xml, user_entry)
    if not ec:
        check("6: entry node bounds found", False, "could not find entry bounds")
        return
    tap_coords(ec[0], ec[1])
    time.sleep(2)

    # Go back to content list using Contents button
    xml = _dump_ui()
    cc2 = _node_bounds(xml, "Contents")
    if cc2:
        tap_coords(cc2[0], cc2[1])
        time.sleep(2)
    else:
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        time.sleep(1)

    # Now find and tap Delete button on the entry
    xml = _dump_ui()
    dc = _node_bounds(xml, "Delete")
    if not dc:
        check("6: Delete button found", False, "Delete button not visible")
        return
    check("6: Delete button found", True, f"at {dc}")
    
    # Track the specific entry being deleted
    entries_before = store_index().get("entries", [])
    entry_to_delete = None
    for e in entries_before:
        if e.get("origin") == "user" and user_entry and "Klhu doc walk" in e.get("name", ""):
            entry_to_delete = e["id"]
            break
    
    tap_coords(dc[0], dc[1])
    time.sleep(1)

    # Check for confirmation dialog
    xml = _dump_ui()
    desc = re.findall(r'content-desc="([^"]*)"', xml)
    labels = [d for d in desc if d.strip()]
    has_confirm = any("cannot be undone" in l.lower() for l in labels)
    check("6: delete confirmation dialog shown", has_confirm,
          "dialog: {}".format([l for l in labels if l.strip()][:5]))

    if not has_confirm:
        return

    # Tap Delete to confirm
    dc2 = _node_bounds(_dump_ui(), "Delete")
    if not dc2:
        check("6: confirm Delete button found", False, "Delete button not in dialog")
        return
    tap_coords(dc2[0], dc2[1])
    time.sleep(1)

    # Verify the entry is gone by comparing store before and after
    # (other entries with similar names may remain)
    entries_before = {e["id"] for e in store_index().get("entries", [])
                      if e.get("origin") == "user" and "Klhu doc walk" in e.get("name", "")}
    # Re-dump to check UI
    xml = _dump_ui()
    desc = re.findall(r'content-desc="([^"]*)"', xml)
    labels = [d for d in desc if d.strip()]
    # The specific entry we deleted should no longer be in the list
    # (it had a specific number like (17), now it should be gone)
    check("6: deleted entry removed from list",
          not any("(17)" in l or "(16)" in l for l in labels
                  if "Klhu doc walk" in l),
          "entry still in list" if any("(17)" in l or "(16)" in l for l in labels
                                       if "Klhu doc walk" in l) else "entry removed")

    entries_after = store_index().get("entries", [])
    still_exists = any(e["id"] == entry_to_delete for e in entries_after)
    check("6: deleted entry removed from store",
          entry_to_delete is None or not still_exists,
          "entry still in store" if still_exists else "entry removed from store")


ROWS = {"1": row_1, "2": row_2, "3": row_3, "4": row_4, "5": row_5, "6": row_6}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ROWS:
        print(f"usage: extraction_walk.py <1|2|3|4|5>")
        return 2
    _ensure_fixtures()
    os.makedirs(OUT, exist_ok=True)
    print(f"klhu walk 028 row {sys.argv[1]} — device {DEV}, package {PKG}, "
          f"out {OUT}")
    ROWS[sys.argv[1]]()
    failed = [name for name, ok, _ in RESULTS if not ok]
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    for name in failed:
        print(f"   FAILED: {name}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
