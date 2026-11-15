// Option tables: a click on an option row (or Enter/Space on it) opens or closes the card row below it, and an
// option anchor in the URL opens its card on load and on hash changes. Delegated from the document, so it keeps
// working with Material's instant navigation, which swaps the page content without reloading.
(function () {
  "use strict";

  function setOpen(row, open) {
    var card = row.nextElementSibling;
    if (!card || !card.classList.contains("nd-card")) return;
    card.hidden = !open;
    row.setAttribute("aria-expanded", open ? "true" : "false");
  }

  function toggle(row) {
    setOpen(row, row.getAttribute("aria-expanded") !== "true");
  }

  function openFromHash() {
    if (!location.hash) return;
    var id;
    try {
      id = decodeURIComponent(location.hash.slice(1));
    } catch (e) {
      return;
    }
    var row = document.getElementById(id);
    if (row && row.classList.contains("nd-option")) {
      setOpen(row, true);
      row.scrollIntoView({ block: "start" }); // scroll-margin-top keeps it below the header
    }
  }

  document.addEventListener("click", function (event) {
    var row = event.target.closest && event.target.closest("tr.nd-option");
    if (!row) return;
    // The name links to the option's anchor: open it (and let the hash change), never close it
    if (event.target.closest("a.nd-name")) {
      setOpen(row, true);
      return;
    }
    // Other links in the row, and selecting text, keep their default
    if (event.target.closest("a") || String(window.getSelection()) !== "") return;
    toggle(row);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Enter" && event.key !== " ") return;
    var row = event.target;
    if (!row.classList || !row.classList.contains("nd-option")) return;
    event.preventDefault();
    toggle(row);
  });

  window.addEventListener("hashchange", openFromHash);
  if (typeof document$ !== "undefined" && document$.subscribe) {
    document$.subscribe(openFromHash);
  } else if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", openFromHash);
  } else {
    openFromHash();
  }
})();
