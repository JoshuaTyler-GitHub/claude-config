#!/usr/bin/env python
"""Fetch a URL with crawl4ai, print clean markdown to stdout. Off the harness fetch path."""
import asyncio
import sys

from crawl4ai import AsyncWebCrawler, BrowserConfig, CacheMode, CrawlerRunConfig


async def main(url: str) -> int:
    browser = BrowserConfig(headless=True, verbose=False)
    run = CrawlerRunConfig(cache_mode=CacheMode.BYPASS, page_timeout=45000, word_count_threshold=10)
    async with AsyncWebCrawler(config=browser) as crawler:
        result = await crawler.arun(url=url, config=run)
        if not result.success:
            print(f"FETCH_ERROR: {result.error_message}", file=sys.stderr)
            return 1
        md = result.markdown.fit_markdown or result.markdown.raw_markdown
        print(md)
        return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: fetch_md.py <url>", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(asyncio.run(main(sys.argv[1])))
