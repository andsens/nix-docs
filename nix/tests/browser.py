"""Open the fixture option pages in headless Chromium and check the cards.

Usage: browser.py PLAIN_SITE VALUES_SITE
"""

import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

from playwright.sync_api import expect, sync_playwright


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(directory):
    handler = partial(QuietHandler, directory=directory)
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return f"http://127.0.0.1:{server.server_address[1]}"


def row(page, name):
    return page.locator(f'tr.nd-option[id="{name}"]')


def card(page, name):
    return row(page, name).locator("xpath=following-sibling::tr[1]")


def main(plain_dir, values_dir):
    plain, values = serve(plain_dir), serve(values_dir)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))

        # Cards start closed, a click opens one, a second click closes it
        page.goto(f"{plain}/options/alpha/")
        name = "fixture.alpha.name"
        expect(card(page, name)).to_be_hidden()
        row(page, name).locator("td").nth(1).click()
        expect(card(page, name)).to_be_visible()
        expect(card(page, name)).to_contain_text("A second paragraph")
        expect(card(page, name)).to_contain_text("Declared in")
        expect(row(page, name)).to_have_attribute("aria-expanded", "true")
        row(page, name).locator("td").nth(1).click()
        expect(card(page, name)).to_be_hidden()

        # Keyboard: Enter on a focused row opens it
        row(page, name).focus()
        page.keyboard.press("Enter")
        expect(card(page, name)).to_be_visible()

        # The pipe in the description stays in its cell; the summary row has only the first paragraph
        expect(row(page, name)).to_contain_text("A pipe | must not break the table.")
        expect(row(page, name)).not_to_contain_text("A second paragraph")

        # No Value column and no badge without values
        expect(page.locator("table.nd-options th", has_text="Value")).to_have_count(0)
        expect(page.locator(".nd-badge")).to_have_count(0)

        # An anchor in the URL opens its card on load
        page.goto(f"{plain}/options/alpha/#fixture.alpha.settings")
        expect(card(page, "fixture.alpha.settings")).to_be_visible()
        expect(card(page, "fixture.alpha.name")).to_be_hidden()

        # ... and on a hash change within the page
        page.evaluate("location.hash = '#fixture.alpha.computed'")
        expect(card(page, "fixture.alpha.computed")).to_be_visible()

        # Options under <name> get a row too
        page.goto(f"{plain}/options/beta/")
        expect(row(page, "fixture.beta.peers.<name>.address")).to_have_count(1)

        # A long value without whitespace stays whole; one with whitespace is cut
        page.goto(f"{plain}/options/alpha/")
        expect(row(page, "fixture.alpha.path").locator("td").nth(2)).to_have_text(
            '"/var/lib/a-rather-long-directory-name/without-any-whitespace/in-it"'
        )
        expect(row(page, "fixture.alpha.longText").locator("td").nth(2)).to_have_text('"a default with spaces that is longer th…')

        # An option named like its section shows its full name
        page.goto(f"{plain}/options/gamma/")
        expect(row(page, "fixture.gamma").locator("a.nd-name")).to_have_text("fixture.gamma")

        # With values: the Value column, changed values marked, the enable badge per section
        page.goto(f"{values}/options/alpha/")
        expect(page.locator("table.nd-options th", has_text="Value")).to_have_count(1)
        expect(row(page, "fixture.alpha.enable").locator("td.nd-value.nd-changed")).to_have_count(1)
        expect(row(page, "fixture.alpha.name").locator("td.nd-value")).to_have_text('"alpha"')
        expect(row(page, "fixture.alpha.name").locator("td.nd-changed")).to_have_count(0)
        expect(page.locator(".nd-badge.nd-enabled")).to_have_count(1)
        row(page, "fixture.alpha.settings").locator("td").nth(1).click()
        expect(card(page, "fixture.alpha.settings")).to_contain_text("Value (changed)")
        page.goto(f"{values}/options/beta/")
        expect(page.locator(".nd-badge.nd-disabled")).to_have_count(1)

        assert not errors, errors
        browser.close()
    print("browser checks passed")


if __name__ == "__main__":
    main(*sys.argv[1:])
