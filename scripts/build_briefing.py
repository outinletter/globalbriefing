"""Build a static briefing from publisher RSS descriptions, without API keys."""
import json
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from html import unescape
from pathlib import Path
from urllib.request import Request, urlopen

FEEDS = [
    ("BBC News", "World", "https://feeds.bbci.co.uk/news/world/rss.xml"),
    ("The Guardian", "World", "https://www.theguardian.com/world/rss"),
    ("BBC News", "Business", "https://feeds.bbci.co.uk/news/business/rss.xml"),
    ("BBC News", "Technology", "https://feeds.bbci.co.uk/news/technology/rss.xml"),
    ("BBC News", "Science", "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml"),
]


def plain(value):
    return re.sub(r"\s+", " ", unescape(re.sub(r"<[^>]+>", " ", value or ""))).strip()


def build(output):
    now = datetime.now(timezone.utc)
    sections, seen, failures = [], set(), []
    for source, category, url in FEEDS:
        try:
            request = Request(url, headers={"User-Agent": "GlobalBriefing RSS reader/1.0"})
            with urlopen(request, timeout=30) as response:
                root = ET.fromstring(response.read())
            candidates = []
            for item in root.findall(".//item"):
                title = plain(item.findtext("title"))
                link = (item.findtext("link") or "").strip()
                try:
                    published = parsedate_to_datetime(item.findtext("pubDate") or "").astimezone(timezone.utc)
                except (ValueError, TypeError):
                    continue
                if not title or not link.startswith("https://") or not now - timedelta(hours=48) <= published <= now:
                    continue
                description = plain(item.findtext("description"))
                description = description.split(" Continue reading")[0]
                sentences = re.split(r"(?<=[.!?])\s+", description)
                summary = " ".join(sentences[:2])
                if len(summary) > 500:
                    summary = summary[:497].rsplit(" ", 1)[0] + "…"
                candidates.append((published, title, link, summary))
            for published, title, link, summary in sorted(candidates, reverse=True):
                if title.casefold() in seen or link in seen:
                    continue
                seen.update((title.casefold(), link))
                sections.append({"title": title, "tag": category, "hero": not sections,
                                 "stories": [{"title": title, "source": source, "url": link,
                                              "publishedAt": published.isoformat(),
                                              "paragraphs": [summary] if summary else []}]})
                if sum(section["stories"][0]["source"] == source and section["tag"] == category for section in sections) >= 2:
                    break
        except Exception as error:
            failures.append(source + ": " + str(error))
    if not sections:
        raise RuntimeError("No recent RSS articles; existing briefing preserved. " + "; ".join(failures))
    result = {"generatedAt": now.isoformat(), "summaryMethod": "Publisher RSS description, up to two sentences",
              "warnings": failures, "briefingSections": sections[:10]}
    Path(output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(result['briefingSections'])} stories; {len(failures)} feed failures")


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "briefing.json")
