# Export snownlp .marshal.3 models to Dart-loadable JSON.
#
# Usage (from project root):
#   python tool/export_models.py            # pretty-printed
#   python tool/export_models.py --compact  # compact one-line per file
#
# Outputs are written to lib/src/data/*.json. A separate Dart tool
# (``tool/build_models.dart``) then encodes the JSON into the on-disk
# binary format used at runtime.
#
# Why this exists: Python's `marshal` binary format is not portable to
# Dart. Rather than re-train every model, we dump the loaded Python
# objects once, normalize Python-specific types (tuple, set, NormalProb,
# AddOneProb), and serialize as JSON that Dart can read at runtime.

from __future__ import print_function

import argparse
import ast
import gzip
import json
import marshal
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(HERE)
SNOWNLP_DIR = os.path.join(PROJECT_ROOT, "snownlp", "snownlp")
DATA_DIR = os.path.join(PROJECT_ROOT, "lib", "src", "data")
FORMAT_VERSION = 1
SOH = "\x01"


# ---------------------------------------------------------------------------
# Normalization helpers
# ---------------------------------------------------------------------------


def tuple_to_key(t):
    """Convert a (possibly nested) tuple into a JSON-safe string key.

    Used for tuple-**keys** in dictionaries: e.g. ``(('BOS', 'BOS'),)``
    becomes ``"BOS\u0001BOS"``. Recurses through nested tuples/lists so
    the result is always a single string.
    """
    parts = []
    for item in t:
        if isinstance(item, (tuple, list)):
            parts.append(tuple_to_key(item))
        else:
            parts.append(item)
    return SOH.join(parts)


def convert(obj):
    """Recursively normalize Python objects into JSON-friendly structures."""
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if isinstance(k, tuple):
                out[tuple_to_key(k)] = convert(v)
            elif isinstance(k, (set, frozenset)):
                out[SOH.join(sorted(list(k)))] = convert(v)
            elif isinstance(k, (tuple, list)):
                out[tuple_to_key(k)] = convert(v)
            else:
                out[k] = convert(v)
        return out
    if isinstance(obj, (tuple, list)):
        return [convert(x) for x in obj]
    if isinstance(obj, (set, frozenset)):
        return sorted(convert(x) for x in obj)
    # Frequency table objects expose ``__dict__`` with d/total/none/...
    if hasattr(obj, "__class__") and obj.__class__.__name__ in (
        "NormalProb",
        "AddOneProb",
        "GoodTuringProb",
    ):
        d = obj.__dict__.copy()
        return convert(d)
    return obj


def write_json(name, payload, compact):
    out_path = os.path.join(DATA_DIR, name)
    with open(out_path, "w", encoding="utf-8") as f:
        if compact:
            json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
        else:
            json.dump(
                payload,
                f,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
    return out_path, os.path.getsize(out_path)


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------


def load_marshal(fname):
    """Read snownlp's gzip+marshal format used since 2017."""
    with gzip.open(fname, "rb") as f:
        return marshal.loads(f.read())


def export_sentiment(compact):
    src = os.path.join(SNOWNLP_DIR, "sentiment", "sentiment.marshal.3")
    in_size = os.path.getsize(src)
    raw = load_marshal(src)
    payload = {"_format_version": FORMAT_VERSION}
    payload.update(convert(raw))
    out, out_size = write_json("sentiment.json", payload, compact)
    record_count = sum(
        len(v["d"]) for k, v in payload.get("d", {}).items() if isinstance(v, dict) and "d" in v
    )
    print("  {0:<22} in={1:>10,}  out={2:>10,}  records={3:,}".format(
        "sentiment.json", in_size, out_size, record_count))


def export_seg(compact):
    src = os.path.join(SNOWNLP_DIR, "seg", "seg.marshal.3")
    in_size = os.path.getsize(src)
    raw = load_marshal(src)
    payload = {"_format_version": FORMAT_VERSION}
    payload.update(convert(raw))
    out, out_size = write_json("seg.json", payload, compact)
    record_count = (
        len(payload.get("uni", {}).get("d", {}))
        + len(payload.get("bi", {}).get("d", {}))
        + len(payload.get("tri", {}).get("d", {}))
    )
    print("  {0:<22} in={1:>10,}  out={2:>10,}  records={3:,}".format(
        "seg.json", in_size, out_size, record_count))


def export_tag(compact):
    src = os.path.join(SNOWNLP_DIR, "tag", "tag.marshal.3")
    in_size = os.path.getsize(src)
    raw = load_marshal(src)
    payload = {"_format_version": FORMAT_VERSION}
    payload.update(convert(raw))
    out, out_size = write_json("tag.json", payload, compact)
    record_count = len(payload.get("trans", {}))
    print("  {0:<22} in={1:>10,}  out={2:>10,}  records={3:,}".format(
        "tag.json", in_size, out_size, record_count))


def export_zh2hans(compact):
    """`snownlp/normal/zh.py` is a plain module with a single dict literal
    and a ``transfer`` function. ``ast.literal_eval`` extracts the dict."""
    src = os.path.join(SNOWNLP_DIR, "normal", "zh.py")
    in_size = os.path.getsize(src)
    with open(src, "r", encoding="utf-8") as f:
        tree = ast.parse(f.read(), filename=src)
    mapping = None
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1:
            tgt = node.targets[0]
            if isinstance(tgt, ast.Name) and tgt.id == "zh2hans":
                mapping = ast.literal_eval(node.value)
                break
    if mapping is None:
        raise RuntimeError("could not find zh2hans literal in " + src)
    payload = {
        "_format_version": FORMAT_VERSION,
        "map": convert(mapping),
    }
    out, out_size = write_json("zh2hans.json", payload, compact)
    print("  {0:<22} in={1:>10,}  out={2:>10,}  records={3:,}".format(
        "zh2hans.json", in_size, out_size, len(mapping)))


def export_pinyin(compact):
    src = os.path.join(SNOWNLP_DIR, "normal", "pinyin.txt")
    in_size = os.path.getsize(src)
    entries = []
    with open(src, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.split()
            if not parts:
                continue
            entries.append({"h": parts[0], "p": parts[1:]})
    payload = {
        "_format_version": FORMAT_VERSION,
        "entries": entries,
    }
    out, out_size = write_json("pinyin.json", payload, compact)
    print("  {0:<22} in={1:>10,}  out={2:>10,}  records={3:,}".format(
        "pinyin.json", in_size, out_size, len(entries)))


def export_stopwords(compact):
    src = os.path.join(SNOWNLP_DIR, "normal", "stopwords.txt")
    in_size = os.path.getsize(src)
    with open(src, "r", encoding="utf-8") as f:
        words = sorted(w.strip() for w in f if w.strip())
    payload = {
        "_format_version": FORMAT_VERSION,
        "words": words,
    }
    out, out_size = write_json("stopwords.json", payload, compact)
    print("  {0:<22} in={1:>10,}  out={2:>10,}  records={3:,}".format(
        "stopwords.json", in_size, out_size, len(words)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compact", action="store_true", help="emit compact JSON")
    args = parser.parse_args()

    if not os.path.isdir(DATA_DIR):
        os.makedirs(DATA_DIR)

    print("Exporting snownlp models to " + os.path.relpath(DATA_DIR, PROJECT_ROOT))
    export_sentiment(args.compact)
    export_seg(args.compact)
    export_tag(args.compact)
    export_zh2hans(args.compact)
    export_pinyin(args.compact)
    export_stopwords(args.compact)
    print("Done.")


if __name__ == "__main__":
    main()
