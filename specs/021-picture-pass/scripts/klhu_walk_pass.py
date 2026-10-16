#!/usr/bin/env python3
"""klhu device walk — 021 quickstart rows 8-15 and 17.

Row 8:  the strip's own cells — the picture itself with its own count at the top
        right, and no painted file name (FR-001, FR-002, SC-001).
Row 9:  one tap: the list below, and the badge answering **that same tap**
        (FR-003, FR-006, FR-019, SC-002).
Row 10: a hold: the picture large below the strip, the app's own count words
        under it, the list hidden, and `Close` (FR-004, FR-019, SC-003).
Row 11: the controls' gating: a picture the reader gave nothing offers the move
        and the delete, one holding a sentence offers neither (FR-005, SC-004).
Row 12: the move, and the renderer's own ranges following it (FR-006, SC-005).
Row 13: the delete, its confirmation, and a cancelled delete changing nothing
        (FR-008, FR-009, SC-006).
Row 14: the selected cell at the strip's middle (FR-007, SC-007).
Row 15: the picker dialog's own surface, and the switch (FR-010, FR-011,
        FR-014, SC-008, SC-009).
Row 17: the answer carries the reader's runs and no fallback sentence (FR-016).

The mechanics are **020's own module**, imported for everything it already has
and 021 does not: 020's ten-sentence fixture and three pictures
(`make_pictures`/`push_pictures`/`seed_content`), the prompt's own flow
(`open_video_dialog`), the pass (`open_pass`), the reader's own gestures on it
(`assign`, `tap`, `hold_only`), and the dump readers beneath them — 012's
`dump`/`fresh_dump`/`dump_until`/`label s`/`on_screen`/`tap`/`screencap`, 016's
`fresh_prefs` and 011's painted band under those.

021 adds only what is its own: the **cell's own label** (the picture's name and
the number it carries, in one node — the name survives as the cell's semantic
label, FR-002, which is why this parser is 020's own shape) and the two gestures
no earlier row drives — the hold that opens a picture large, and the switch
across two pictures.

Usage:  /usr/bin/python3 -u klhu_walk_pass.py 8
        ADB_SERIAL=emulator-5554 /usr/bin/python3 -u klhu_walk_pass.py 8
        KLHU_REPO=~/Documents/GitHub/Projects/klhu KLHU_OUT=/tmp/klhu_out \\
            /usr/bin/python3 -u klhu_walk_pass.py 8
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.

A row is implemented here in the pass that walks it; `main` names the rows it
does not have yet rather than dispatching into a stub (014's own convention).
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "specs", "020-sentence-pictures",
                                "scripts"))

import klhu_walk_assignment as base  # noqa: E402

adb = base.adb
dump = base.dump
fresh_dump = base.fresh_dump
dump_until = base.dump_until
check = base.check
labels = base.labels
find = base.find
tap = base.tap
on_screen = base.on_screen
screencap = base.screencap
hold_only = base.hold_only
choose_pictures = base.choose_pictures
sentences = base.sentences
make_pictures = base.make_pictures
push_pictures = base.push_pictures
seed_content = base.seed_content
unseed_content = base.unseed_content
open_video_dialog = base.open_video_dialog
open_pass = base.open_pass
assign = base.assign
preflight = base.preflight
start_render = base.start_render
render_plan = base.render_plan
logcat = base.logcat
clear_logcat = base.clear_logcat
PICTURES = base.PICTURES
OUT = base.OUT
DEV = base.DEV
PKG = base.PKG
RESULTS = base.RESULTS

NAMES = [name for name, _ in base.PICTURES]


def cell_line(rows, name):
    """A picture's own cell label: the picture's name and the count it carries,
    in one node (`w020_white.png\\n2`).

    The name is the cell's **semantic label** and the number is the badge — the
    same one-node shape 020's own chips had, which is why 020's parser shape is
    reused here (FR-002's own decision: the name is not painted, and this is
    where it survives).
    """
    for r in rows:
        label = r["desc"] or r["text"]
        if label and label.startswith(name + "\n"):
            return label.split("\n", 1)[1]
    return None


def cell_counts(rows):
    """Every picture's own number, by name — `{name: '0'}`, `None` where the
    cell is not on screen at all."""
    return {name: cell_line(rows, name) for name in NAMES}


def cell_node(rows, name):
    """[name]'s own node, so a row can print what the device really carries."""
    for r in rows:
        label = r["desc"] or r["text"]
        if label and label.startswith(name + "\n"):
            return r
    return None


def sentence_rows(rows):
    """The sentence texts the pass's own list is showing, in the content's own
    order — the list is only there while no picture is open large (FR-004)."""
    out = []
    for text in sentences():
        needle = " ".join(text.split())
        if any(needle in " ".join((r["desc"] or r["text"] or "").split())
               for r in rows):
            out.append(text)
    return out


def fresh_pass():
    """020's own boot, then the prompt and the pass on it. `preflight` refuses
    to walk a device whose build is older than the APK on disk — the guard every
    driver in this tree carries."""
    preflight()
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.4)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.4)
    if not seed_content():
        return None
    push_pictures(make_pictures())
    rows = open_video_dialog(NAMES)
    if rows is None:
        return None
    return open_pass(rows)


def assign_own(rows, per=(1, 0, 0)):
    """Give the first picture one sentence, the rest none — 021's own copy of
    020's `assign`, because 020's two assumptions are what 021 supersedes: its
    precondition reads the cell's words (`No sentences assigned`) where 021's
    cell carries the number alone (FR-019), and its own closing check writes
    `1 sentences` where the app's own plural is `1 sentence` (020's rows never
    assigned exactly one sentence, so it never met the singular)."""
    texts = sentences()
    check("the pass opens with nothing assigned (a clean row)",
          set(cell_counts(fresh_dump()).values()) == {"0"},
          f"cells: {cell_counts(fresh_dump())}")
    taken = 0
    for index, count in enumerate(per):
        name = NAMES[index]
        rows = dump()
        if not tap(rows, name, label=f"{name}'s cell"):
            return False
        time.sleep(0.4)
        for _ in range(count):
            rows = dump()
            if not tap(rows, texts[taken], label=f"the sentence {texts[taken]!r}"):
                return False
            taken += 1
            time.sleep(0.3)
        print(f"   {name}: {count} sentences assigned")
    rows = dump()
    if not tap(rows, "Done", label="Done"):
        return False
    time.sleep(2.0)
    word = "sentence" if taken == 1 else "sentences"
    rows = dump_until(f"{taken} {word}")
    check(f"the prompt says {taken} {word} are assigned",
          on_screen(rows, f"{taken} {word}"),
          f"the labels mentioning sentences: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    return True


def tap_exact(rows, label, name=None):
    """Tap the node whose own label is **exactly** [label].

    012's `find` matches a label the app's own way (a prefix), which is right for
    a screen where every label is distinct and wrong inside a confirmation: the
    dialog's own action `Delete` is a prefix of its own title `Delete this
    picture?`, and the tap landed on the title — a no-op that looked like a
    delete that had not happened.
    """
    for r in rows:
        if ((r["desc"] or r["text"] or "").strip()) == label:
            adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
            print(f"   tap {label!r} (exactly) @{r['x']},{r['y']}")
            return True
    print(f"   no node whose own label is exactly {label!r}: "
          f"{[l for l in labels(rows)][:12]}")
    return False


def cell_x(rows, name):
    """Where [name]'s own cell sits on the screen, as the device reports it."""
    node = cell_node(rows, name)
    return None if node is None else node.get("x")


def strip_order(rows):
    """The strip's own pictures, in the order the page draws them — the dump's own
    reading order, which is the strip's (`chip_order`'s own shape in 020)."""
    order = []
    for r in rows:
        label = r["desc"] or r["text"] or ""
        for name in NAMES:
            if label.startswith(name + "\n") and name not in order:
                order.append(name)
    return order


def render_line(log):
    """The renderer's own schedule line, verbatim."""
    for line in log.splitlines():
        if "klhu render pictures=" in line:
            return line.strip()
    return "(the app wrote no schedule line)"


def fresh_prompt():
    """020's own boot and the prompt, without the pass."""
    preflight()
    # A killed run can leave a dialog on screen: back out of whatever is up before
    # the prompt's own flow starts, so a re-run is not poisoned by the last one.
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.4)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.4)
    if not seed_content():
        return None
    push_pictures(make_pictures())
    return open_video_dialog(NAMES)


def row_8():
    """The strip's own cells, and no painted name (FR-001, FR-002, SC-001)."""
    print("row 8 — the strip's own cells, each with its own count")
    rows = fresh_pass()
    if rows is None:
        return
    cells = cell_counts(rows)
    check("8: every cell carries its picture's own name and count",
          all(count == "0" for count in cells.values()),
          f"the cells' own labels: {cells}")
    print(f"   one cell, as the device reports it: {cell_node(rows, NAMES[0])}")
    check("8: the strip carries no count words (FR-019 — they live under the "
          "large picture)",
          not on_screen(rows, "No sentences assigned"),
          f"labels mentioning a count: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    # How many cells the strip is drawing, counted off their own one-node shape —
    # a check that can fail, unlike the always-true one this row first had.
    drawn = [r for r in rows
             if (r["desc"] or r["text"] or "").startswith(tuple(NAMES))]
    check("8: the strip draws one cell per chosen picture",
          len(drawn) == len(NAMES), f"cells drawn: {len(drawn)}")
    still = screencap(os.path.join(OUT, "021_row8_strip.png"))
    print(f"   the still the reader's own eye reads: {still}")


def row_9():
    """One tap: the badge answers that same tap (FR-003, FR-006, SC-002)."""
    print("row 9 — one tap, and the badge on that same tap")
    rows = fresh_pass()
    if rows is None:
        return
    check("9: the pass opens with every cell at 0",
          set(cell_counts(rows).values()) == {"0"},
          f"cells: {cell_counts(rows)}")
    texts = sentences()
    if not tap(rows, texts[0], label=f"the sentence {texts[0]!r}"):
        return
    # **One** dump, straight after the tap and with no second gesture in
    # between: this is what "the number changes on the same tap" means.
    rows = fresh_dump()
    after = cell_counts(rows)
    check("9: the tapped sentence's own picture carries 1 on that tap",
          after[NAMES[0]] == "1",
          f"cells after the tap: {after}")
    check("9: and the count's own words are still not on the strip",
          not on_screen(rows, "No sentences assigned"),
          f"labels mentioning a count: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    still = screencap(os.path.join(OUT, "021_row9_after_one_tap.png"))
    print(f"   the still after the one tap: {still}")

    if not tap(rows, NAMES[1], label=f"{NAMES[1]}'s cell"):
        return
    time.sleep(0.6)
    rows = fresh_dump()
    if not tap(rows, texts[1], label=f"the sentence {texts[1]!r}"):
        return
    rows = fresh_dump()
    both = cell_counts(rows)
    check("9: a tap on another picture assigns to **that** one — the selection "
          "is what a tap means",
          both[NAMES[1]] == "1" and both[NAMES[0]] == "1",
          f"cells: {both}")


def row_10():
    """A hold: the picture large, the words, the list hidden, `Close` (FR-004,
    FR-019, SC-003)."""
    print("row 10 — a hold opens the picture large, and Close brings the list back")
    rows = fresh_pass()
    if rows is None:
        return
    before = sentence_rows(rows)
    check("10: the list is showing before the hold", len(before) > 0,
          f"the sentence rows: {before}")
    if not hold_only(NAMES[1], seconds=1.6, label=f"{NAMES[1]}'s cell"):
        return
    rows = fresh_dump()
    check("10: the hold opened the large picture (Close is there)",
          on_screen(rows, "Close"),
          f"labels: {labels(rows)[:10]}")
    check("10: the app's own words for the count are under it (FR-019)",
          on_screen(rows, "No sentences assigned"),
          f"labels mentioning a count: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    check("10: and the sentence list is hidden while it is open",
          not sentence_rows(rows),
          f"the sentence rows still showing: {sentence_rows(rows)}")
    still = screencap(os.path.join(OUT, "021_row10_large_picture.png"))
    print(f"   the still with the picture large: {still}")
    if not tap(rows, "Close", label="Close"):
        return
    time.sleep(0.8)
    rows = fresh_dump()
    check("10: Close brings the sentence list back",
          len(sentence_rows(rows)) == len(before),
          f"the sentence rows: {sentence_rows(rows)}")
    check("10: and the words are gone with the large picture",
          not on_screen(rows, "No sentences assigned"),
          f"labels mentioning a count: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")


def row_11():
    """The controls' gating (FR-005, SC-004): only a picture the reader gave
    nothing offers the move and the delete."""
    print("row 11 — the controls, and the picture that may not be moved")
    rows = fresh_pass()
    if rows is None:
        return
    if not assign_own(rows):
        return
    rows = open_pass(fresh_dump())
    if rows is None:
        return
    check("11: the pass came back with the reader's own run in force",
          cell_counts(rows)[NAMES[0]] == "1",
          f"cells: {cell_counts(rows)}")
    if not hold_only(NAMES[0], seconds=1.6, label=f"{NAMES[0]}'s cell"):
        return
    rows = fresh_dump()
    held = on_screen(rows, "Move left")
    check("11: a picture holding a sentence of the reader's offers no move and "
          "no delete",
          not held and not on_screen(rows, "Delete this picture"),
          f"labels: {labels(rows)[:12]}")
    if not tap(rows, "Close", label="Close"):
        return
    time.sleep(0.6)
    rows = fresh_dump()
    if not hold_only(NAMES[1], seconds=1.6, label=f"{NAMES[1]}'s cell"):
        return
    rows = fresh_dump()
    check("11: a picture the reader gave nothing offers both moves and the "
          "delete",
          on_screen(rows, "Move left") and on_screen(rows, "Move right")
          and on_screen(rows, "Delete this picture"),
          f"labels: {labels(rows)[:12]}")
    still = screencap(os.path.join(OUT, "021_row11_controls.png"))
    print(f"   the still with the controls: {still}")
    tap(rows, "Close", label="Close")
    unseed_content()

def row_12():
    """The move, and the renderer's own ranges following it (FR-006, SC-005)."""
    print("row 12 — the move, and the renderer's own ranges following it")
    rows = fresh_pass()
    if rows is None:
        return
    if not assign_own(rows):
        return
    # `assign_own` leaves the reader at the prompt, which is where a render starts:
    # tapping Start from inside the pass does nothing (the pass has no Start), and
    # the first run of this row rendered nothing at all because of it.
    rows = dump_until("1 sentence")
    check("12: the record is in force before the move",
          on_screen(rows, "1 sentence"), f"labels: {labels(rows)[:10]}")
    log = start_render()
    plan_before = render_plan(log)
    line_before = render_line(log)
    print(f"   the renderer's own line before the move: {line_before}")
    check("12: the render before the move reports a schedule",
          plan_before is not None and plan_before[2] == 10,
          f"the app's own line: {line_before}")

    rows = open_video_dialog(NAMES)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    before = {name: cell_x(rows, name) for name in NAMES}
    if not hold_only(NAMES[1], seconds=1.6, label=f"{NAMES[1]}'s cell"):
        return
    rows = fresh_dump()
    if not tap(rows, "Move left", label="Move left"):
        return
    time.sleep(0.9)
    rows = fresh_dump()
    order = strip_order(rows)
    after = {name: cell_x(rows, name) for name in NAMES}
    check("12: the thumbnails answer the move at once — the strip's own order is "
          "the new one",
          order == [NAMES[1], NAMES[0], NAMES[2]],
          f"the strip's own order: {order}")
    print(f"   the cells' own x before the move: {before}")
    print(f"   the cells' own x after the move:  {after}")
    still = screencap(os.path.join(OUT, "021_row12_after_move.png"))
    print(f"   the still after the move: {still}")

    # The move shown, the pass is answered with Done and the render starts where
    # every render starts: on the prompt.
    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(1.5)
    rows = dump_until("1 sentence")
    log = start_render()
    plan_after = render_plan(log)
    line_after = render_line(log)
    print(f"   the renderer's own line after the move: {line_after}")
    check("12: the renderer's own schedule follows the new order",
          plan_after is not None and plan_after != plan_before,
          f"before: {line_before}\nafter:  {line_after}")
    check("12: and the content is the same video's — ten sentences, three "
          "pictures, both times",
          plan_after is not None and plan_after[2] == plan_before[2]
          and plan_after[0] == plan_before[0],
          f"pictures/sentences: {plan_after} against {plan_before}")
    unseed_content()


def row_13():
    """The delete, its confirmation, and a cancelled delete (FR-008, FR-009,
    SC-006)."""
    print("row 13 — the delete asks first, and cancelling changes nothing")
    rows = fresh_pass()
    if rows is None:
        return
    if not assign_own(rows):
        return
    rows = open_pass(fresh_dump())
    if rows is None:
        return
    if not hold_only(NAMES[1], seconds=1.6, label=f"{NAMES[1]}'s cell"):
        return
    rows = fresh_dump()
    if not tap_exact(rows, "Delete this picture"):
        return
    time.sleep(1.0)
    rows = fresh_dump()
    check("13: the delete asks first", on_screen(rows, "Delete this picture?"),
          f"labels: {labels(rows)[:14]}")
    check("13: and the confirmation names the picture itself, not its file name",
          any((r["desc"] or r["text"] or "").strip() == NAMES[1] for r in rows),
          f"the confirmation's own labels: "
          f"{[l for l in labels(rows) if l.startswith('w020')]}")
    still = screencap(os.path.join(OUT, "021_row13_confirmation.png"))
    print(f"   the confirmation's own still: {still}")
    if not tap(rows, "Cancel", label="Cancel"):
        return
    time.sleep(0.8)
    rows = fresh_dump()
    check("13: cancelling changes nothing — the strip still holds its three "
          "pictures",
          strip_order(rows) == NAMES, f"the strip's own order: {strip_order(rows)}")
    check("13: and the record is untouched by the cancelled delete",
          cell_counts(rows)[NAMES[0]] == "1", f"cells: {cell_counts(rows)}")

    if not hold_only(NAMES[1], seconds=1.6, label=f"{NAMES[1]}'s cell"):
        return
    rows = fresh_dump()
    if not tap_exact(rows, "Delete this picture"):
        return
    time.sleep(1.0)
    rows = fresh_dump()
    if not tap_exact(rows, "Delete", name="the confirmation's own Delete"):
        return
    time.sleep(1.2)
    rows = fresh_dump()
    check("13: confirming takes that picture out — one picture fewer",
          strip_order(rows) == [NAMES[0], NAMES[2]],
          f"the strip's own order: {strip_order(rows)}\n"
          f"      on screen: {labels(rows)[:14]}\n"
          f"      the app's own lines: "
          f"{[l for l in logcat().splitlines() if 'klhu' in l][-3:]}")
    check("13: the picture that held nothing took nothing with it",
          cell_counts(rows)[NAMES[0]] == "1", f"cells: {cell_counts(rows)}")
    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(1.5)
    rows = dump_until("1 sentence")
    check("13: and the prompt's own line still says 1 sentence",
          on_screen(rows, "1 sentence"),
          f"the labels mentioning sentences: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    unseed_content()


def row_14():
    """The selected cell, and where the strip can put it (FR-007, SC-007)."""
    print("row 14 — the selected cell, and the strip's own bounds")
    rows = fresh_pass()
    if rows is None:
        return
    first = {name: cell_x(rows, name) for name in NAMES}
    widths = [r for r in rows if (r["desc"] or "").startswith(tuple(NAMES))]
    print(f"   the strip's own cells, as the device reports them: {first}")
    check("14: every cell of the fixture is on screen at once",
          len(widths) == len(NAMES) and all(x is not None for x in first.values()),
          f"the cells the device reports: {len(widths)}")
    for name in NAMES:
        if not tap(rows, name, label=f"{name}'s cell"):
            return
        time.sleep(0.9)
        rows = fresh_dump()
        xs = {n: cell_x(rows, n) for n in NAMES}
        check(f"14: selecting {name} scrolls nothing, because the three pictures "
              f"fit",
              xs == first, f"the cells' own x: {xs} against {first}")
    print("   **the limit this row records**: FR-007's own claim is that the "
          "selected cell sits at the *middle* of the strip. With 020's three "
          "pictures — 3 x (72 + 8) = 240 logical pixels — the strip fits the "
          "screen whole, so `ensureVisible(alignment: 0.5)` has nothing to "
          "scroll and the middle cannot be observed. Making it observable needs "
          "a fixture wider than the screen (about thirteen cells), whose "
          "selection through the platform's own file dialog needs scrolling in "
          "the Files app — not this row's, and named rather than faked.")
    unseed_content()


def row_15():
    """The prompt's own surface, and the switch across two pictures (FR-010,
    FR-011, FR-014, SC-008, SC-009)."""
    print("row 15 — the prompt's own cells and its asking remove, then the switch")
    rows = fresh_prompt()
    if rows is None:
        return
    check("15: the prompt draws the same cells the pass does",
          all(cell_line(rows, name) is not None for name in NAMES),
          f"the prompt's own labels: {[l for l in labels(rows) if l.startswith('w020')]}")
    if not tap(rows, "Remove this picture", label="Remove this picture"):
        return
    time.sleep(1.0)
    rows = fresh_dump()
    check("15: the prompt's own remove asks first too",
          on_screen(rows, "Delete this picture?"), f"labels: {labels(rows)[:14]}")
    if not tap(rows, "Cancel", label="Cancel"):
        return
    time.sleep(0.8)
    rows = dump_until("3 pictures chosen")
    check("15: cancelling takes nothing back",
          on_screen(rows, "3 pictures chosen"),
          f"the prompt's own line: {[l for l in labels(rows) if 'chosen' in l.lower()]}")

    rows = open_pass(rows)
    if rows is None:
        return
    if not assign_own(rows):
        return
    rows = open_pass(fresh_dump())
    if rows is None:
        return
    if not tap(rows, NAMES[1], label=f"{NAMES[1]}'s cell"):
        return
    time.sleep(0.6)
    rows = fresh_dump()
    texts = sentences()
    if not tap(rows, texts[0], label=f"the sentence {texts[0]!r} (the first "
             f"picture's own)"):
        return
    time.sleep(1.0)
    rows = fresh_dump()
    check("15: a sentence another picture holds is proposed, not refused",
          on_screen(rows, "Give this sentence to the selected picture?"),
          f"labels: {labels(rows)[:14]}")
    check("15: and the proposal shows **both** pictures",
          cell_line(rows, NAMES[0]) is not None
          and cell_line(rows, NAMES[1]) is not None,
          f"the pictures the proposal names: "
          f"{[l for l in labels(rows) if l.startswith('w020')]}")
    still = screencap(os.path.join(OUT, "021_row15_switch_proposal.png"))
    print(f"   the proposal's own still: {still}")
    if not tap(rows, "Cancel", label="Cancel"):
        return
    time.sleep(0.8)
    rows = fresh_dump()
    check("15: cancelling leaves both counts as they were",
          cell_counts(rows) == {NAMES[0]: "1", NAMES[1]: "0", NAMES[2]: "0"},
          f"cells: {cell_counts(rows)}")

    if not tap(rows, texts[0], label="the same sentence again"):
        return
    time.sleep(1.0)
    rows = fresh_dump()
    if not tap(rows, "Move it", label="Move it"):
        return
    time.sleep(1.0)
    rows = fresh_dump()
    after = cell_counts(rows)
    check("15: confirming moves exactly one sentence — one picture down, the "
          "other up",
          after == {NAMES[0]: "0", NAMES[1]: "1", NAMES[2]: "0"},
          f"cells: {after}")
    unseed_content()


def row_17():
    """The answer carries the reader's runs, never the fallback (FR-016)."""
    print("row 17 — the answer carries the reader's runs, never the fallback")
    rows = fresh_pass()
    if rows is None:
        return
    if not assign_own(rows):
        return
    rows = open_pass(fresh_dump())
    if rows is None:
        return
    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(1.5)
    rows = dump_until("1 sentence")
    check("17: the record says 1 sentence, not the ten a render would paint",
          on_screen(rows, "1 sentence")
          and not on_screen(rows, "10 sentences"),
          f"the labels mentioning sentences: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    rows = open_pass(rows)
    if rows is None:
        return
    cells = cell_counts(rows)
    check("17: reopening shows the reader's own runs — the sentences no run names "
          "are on no picture",
          cells == {NAMES[0]: "1", NAMES[1]: "0", NAMES[2]: "0"},
          f"cells: {cells}")
    unseed_content()

def row_19():
    """The reader's own report of 2026-10-15: pick, assign, cancel, then open the
    prompt again — with no pictures picked, the assignment line must not claim the
    stored record (FR-019's own meaning: the number follows what is in force)."""
    print("row 19 — the assignment line with nothing picked (the reader's report)")
    rows = fresh_pass()
    if rows is None:
        return
    if not assign_own(rows):
        return
    rows = dump_until("1 sentence")
    check("19: with the pictures picked, the line says what is in force",
          on_screen(rows, "1 sentence"),
          f"labels: {labels(rows)[:12]}")
    if not tap_exact(rows, "Cancel"):
        return
    time.sleep(1.5)
    rows = fresh_dump()
    check("19: Cancel leaves the prompt", not on_screen(rows, "Video format"),
          f"on screen: {labels(rows)[:8]}")
    if not tap(rows, "Video", label="the video action"):
        return
    time.sleep(2.0)
    rows = dump_until("Video format")
    # The app's own words for "nothing picked" are `No pictures chosen` — a
    # negative test for `pictures chosen` matches those very words, which is what
    # this check did on its first run.
    check("19: the prompt opens again with nothing picked",
          on_screen(rows, "Video format") and on_screen(rows, "No pictures chosen"),
          f"labels: {labels(rows)[:10]}")
    check("19: and the line does **not** claim the stored record",
          on_screen(rows, "No sentences assigned")
          and not on_screen(rows, "1 sentence"),
          f"labels: {labels(rows)[:12]}")
    still = screencap(os.path.join(OUT, "021_row19_line_with_nothing_picked.png"))
    print(f"   the still: {still}")

    # And the reader's own next step: the same three files again — the record the
    # cancelled visit took away must not come back with them.
    if not tap(rows, "Choose pictures", label="Choose pictures"):
        return
    time.sleep(3)
    if not choose_pictures(NAMES):
        return
    rows = dump()
    check("19: picking the same three files again brings nothing back",
          on_screen(rows, "No sentences assigned")
          and not on_screen(rows, "1 sentence"),
          f"labels: {labels(rows)[:12]}")
    rows = open_pass(rows)
    if rows is None:
        return
    cells = cell_counts(rows)
    check("19: and the pass's own cells all read 0", set(cells.values()) == {"0"},
          f"cells: {cells}")
    still = screencap(os.path.join(OUT, "021_row19_repicked.png"))
    print(f"   the still after re-picking: {still}")
    unseed_content()


ROWS = {"8": row_8, "9": row_9, "10": row_10, "11": row_11,
        "12": row_12, "13": row_13, "14": row_14, "15": row_15, "17": row_17,
        "19": row_19}

OWED = ()


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ROWS:
        print(f"usage: {os.path.basename(__file__)} {'|'.join(sorted(ROWS, key=int))}")
        print(f"rows this walk still owes: {', '.join(OWED)}")
        sys.exit(2)
    os.makedirs(OUT, exist_ok=True)
    print(f"klhu walk 021 row {sys.argv[1]} — device {DEV}, package {PKG}, "
          f"out {OUT}")
    ROWS[sys.argv[1]]()
    print("\n===== result =====")
    failed = [r for r in RESULTS if not r[1]]
    for name, ok, detail in RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}"
              f"{(' — ' + detail) if detail else ''}")
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
