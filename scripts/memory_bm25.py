"""BM25 ranking over Claude Code memory files (shared by memory-search.py and memory-recall.py).

Fields are weighted: `when` (the task context a memory applies to) x3, name/slug/description
x2, body x1. Matching ignores case, diacritics (Vietnamese "mở đầu" == "mo dau") and English
plurals. Relevance is not correctness: callers show `verified` / `source` with each hit.
"""
import math
import os
import re
import unicodedata

# Function words plus generic request verbs: they appear in most prompts and memory bodies, so
# they only add noise (Vietnamese is stored diacritic-folded).
STOP = set(
    "a an the and or of to in on for with is are be by as at from it this that these those "
    "i me my we our you your please can could would should do does did have has had will "
    "la va cua cho cac nhung mot khi thi de co khong duoc bi toi minh ban nay do day kia "
    "trong ngoai voi sau truoc len xuong ra vao lai nua roi se da dang van cung neu vi nen "
    "ma hay hoac nhu the nao gi sao giup xem lam tao them sua chay can phai muon biet "
    "loi cai con nhe nha".split())
WEIGHTS = {"when": 3, "name": 2, "description": 2, "_body": 1}


def default_dir(cwd=None):
    key = re.sub(r"[^A-Za-z0-9]", "-", cwd or os.getcwd())
    return os.path.join(os.path.expanduser("~"), ".claude", "projects", key, "memory")


def fold(s):
    s = unicodedata.normalize("NFD", s.lower().replace("đ", "d"))
    return "".join(c for c in s if not unicodedata.combining(c))


def stem(t):
    if len(t) > 4 and t.endswith("ies"):
        return t[:-3] + "y"
    if len(t) > 3 and t.endswith("s") and not t.endswith("ss"):
        return t[:-1]
    return t


def tokens(s):
    return [stem(t) for t in re.findall(r"[a-z0-9]+", fold(s)) if t not in STOP and len(t) > 1]


def parse(path):
    text = open(path, encoding="utf-8", errors="replace").read().replace("\r\n", "\n")
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    fm = {"_body": text[m.end():] if m else text}
    for line in (m.group(1) if m else "").splitlines():
        kv = re.match(r"\s*([a-z_]+):\s*(.*)", line)
        if kv and kv.group(1) not in fm:
            fm[kv.group(1)] = kv.group(2).strip().strip('"')
    return fm


def load(mem, include_all=False):
    docs = []
    for f in sorted(os.listdir(mem)) if os.path.isdir(mem) else []:
        if not f.endswith(".md") or f == "MEMORY.md":
            continue
        try:
            fm = parse(os.path.join(mem, f))
        except (OSError, UnicodeDecodeError):
            continue
        if not include_all and fm.get("status", "active") != "active":
            continue
        toks = []
        for field, w in WEIGHTS.items():
            text = fm.get(field, "") + (" " + f[:-3] if field == "name" else "")
            toks += tokens(text) * w
        docs.append((f, fm, toks))
    return docs


def rank(docs, query, k1=1.2, b=0.75):
    """Return [(score, file, frontmatter)] with score > 0, best first."""
    q = set(tokens(query))
    if not docs or not q:
        return []
    n = len(docs)
    avgdl = sum(len(t) for _, _, t in docs) / n or 1
    df = {t: sum(1 for _, _, d in docs if t in d) for t in q}
    out = []
    for f, fm, d in docs:
        s = 0.0
        for t in q:
            tf = d.count(t)
            if tf:
                idf = math.log(1 + (n - df[t] + 0.5) / (df[t] + 0.5))
                s += idf * tf * (k1 + 1) / (tf + k1 * (1 - b + b * len(d) / avgdl))
        if s > 0:
            out.append((s, f, fm))
    return sorted(out, key=lambda x: (-x[0], x[1]))
