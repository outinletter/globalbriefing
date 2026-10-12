"""Extract human-authored Korean glosses and reverse translation equivalents."""
import gzip
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

source, destination = map(Path, sys.argv[1:3])
definitions, equivalents, forms = defaultdict(list), defaultdict(list), {}
pos_names = {"noun": "명사", "verb": "동사", "adj": "형용사", "adv": "부사",
             "prep": "전치사", "pron": "대명사", "conj": "접속사", "intj": "감탄사"}


def key(value):
    return value.strip().lower().replace("’", "'")


def add(target, word, text):
    word = key(word)
    if re.fullmatch(r"[a-z][a-z '’-]{0,79}", word) and text and text not in target[word]:
        target[word].append(text)


with gzip.open(source, "rt", encoding="utf-8") as stream:
    for line in stream:
        entry = json.loads(line)
        word = entry.get("word", "")
        if entry.get("lang_code") == "en":
            label = pos_names.get(entry.get("pos"), "")
            for sense in entry.get("senses", []):
                for gloss in sense.get("glosses", []):
                    if re.search(r"[가-힣]", gloss) and "no-gloss" not in sense.get("tags", []):
                        add(definitions, word, (label + ": " if label else "") + gloss)
                for base in sense.get("form_of", []):
                    forms[key(word)] = key(base.get("word", ""))
            for form in entry.get("forms", []):
                if form.get("form") and "romanization" not in form.get("tags", []):
                    forms[key(form["form"])] = key(word)
        elif entry.get("lang_code") == "ko" and re.search(r"[가-힣]", word):
            for translation in entry.get("translations", []):
                if translation.get("lang_code") == "en":
                    add(equivalents, translation.get("word", ""), word)

words = {}
for word in sorted(set(definitions) | set(equivalents)):
    values = definitions[word][:]
    if not values and equivalents[word]:
        values.append("한영 번역의 대응어: " + ", ".join(equivalents[word]))
    words[word] = values
forms = {form: base for form, base in forms.items() if base in words and form not in words
         and re.fullmatch(r"[a-z][a-z '’-]{0,79}", form)}
assert len(words) > 10000, "Unexpectedly small dictionary"
assert all(words.get(word) for word in ["news", "world", "government", "economy", "science"])
payload = {"source": "한국어 위키낱말사전 기여자 / Kaikki.org (Wiktextract)",
           "sourceURL": "https://kaikki.org/kowiktionary/rawdata.html",
           "license": "CC BY-SA 4.0", "licenseURL": "https://creativecommons.org/licenses/by-sa/4.0/",
           "sourceSHA256": hashlib.sha256(source.read_bytes()).hexdigest(),
           "words": words, "forms": forms}
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
print(f"{len(words):,} headwords; {sum(map(len, words.values())):,} definitions/equivalents; {len(forms):,} inflected forms")
for word in ["news", "world", "government", "economy", "science", "bank", "interest"]:
    print(word, ": ", "; ".join(words.get(word, []))[:200])
