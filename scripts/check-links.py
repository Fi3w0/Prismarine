#!/usr/bin/env python3
"""Check tracked Markdown links, images and local heading anchors.

Use --external to also GET HTTP links. Remote checks are kept out of normal CI
because third-party sites may rate-limit or block automated requests.
"""
import argparse
import concurrent.futures
import html
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def anchors(text):
    result = set()
    counts = {}
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for title in re.findall(r"^#{1,6}\s+(.+)$", text, re.M):
        slug = re.sub(r"[^\w\- ]", "", title.strip().lower()).replace(" ", "-")
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        result.add(slug + (f"-{count}" if count else ""))
    result.update(re.findall(r'(?:id|name)=["\']([^"\']+)', text))
    return result


def remote_status(url):
    encoded_url = urllib.parse.quote(url, safe=":/?&=%#;,+@")
    request = urllib.request.Request(encoded_url, headers={"User-Agent": "Prismarine-link-check/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return url, response.status
    except urllib.error.HTTPError as error:
        return url, error.code
    except (OSError, urllib.error.URLError) as error:
        return url, str(error)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--external", action="store_true")
    options = parser.parse_args()
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    urls = set()
    failures = []
    checked = 0
    for name in tracked:
        if not name.endswith(".md"):
            continue
        path = ROOT / name
        text = path.read_text()
        # Links inside examples are not rendered Markdown links.
        text = re.sub(r"```.*?```", "", text, flags=re.S)
        links = re.findall(r"!?\[[^\]]*\]\(([^\s)]+)(?:\s+[^)]*)?\)", text)
        links += re.findall(r'(?:src|href)=["\']([^"\']+)', text)
        for link in links:
            link = html.unescape(link).strip("<>")
            parts = urllib.parse.urlsplit(link)
            if parts.scheme in ("http", "https"):
                urls.add(link)
                continue
            if parts.scheme:
                continue
            checked += 1
            target = (path.parent / urllib.parse.unquote(parts.path)).resolve() if parts.path else path
            if not target.exists():
                failures.append(f"{name}: missing {link}")
            elif parts.fragment and target.suffix == ".md":
                if urllib.parse.unquote(parts.fragment) not in anchors(target.read_text()):
                    failures.append(f"{name}: missing anchor {link}")
    print(f"Checked {checked} local links and images; found {len(urls)} external URLs.")
    if options.external:
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            for url, status in sorted(executor.map(remote_status, urls)):
                print(f"{status}: {url}")
                if not isinstance(status, int) or status >= 400:
                    failures.append(f"External URL needs review ({status}): {url}")
    for failure in failures:
        print(failure)
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
