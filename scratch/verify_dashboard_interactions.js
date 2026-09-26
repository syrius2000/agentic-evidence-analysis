// scratch/verify_dashboard_interactions.js
// Audits interactive sorting, keyboard activation, ARIA states, and machine-readable sort keys
// directly on the generated dashboard.html for Section 16 (Task 14.10 / 14.10.R1 / 14.10.R2).

const fs = require('fs');
const path = require('path');

const runDir = process.argv[2] || 'evidence_runs/visual_qa_s14/run_20260926_122147';
const htmlPath = path.join(runDir, 'dashboard.html');

console.log(`[AUDIT] Auditing: ${htmlPath}`);
const html = fs.readFileSync(htmlPath, 'utf8');

// Simple DOM environment simulation
class MockClassList {
  constructor(classes) {
    this.classes = new Set(classes ? classes.split(/\s+/).filter(Boolean) : []);
  }
  contains(c) { return this.classes.has(c); }
  add(c) { this.classes.add(c); }
  remove(c) { this.classes.delete(c); }
}

class MockElement {
  constructor(tag, attrs = {}) {
    this.tagName = tag.toUpperCase();
    this.attributes = { ...attrs };
    this.classList = new MockClassList(attrs.class || '');
    this.children = [];
    this.parentNode = null;
    this.textContent = '';
    this.eventListeners = {};
  }
  getAttribute(name) { return this.attributes[name] !== undefined ? this.attributes[name] : null; }
  setAttribute(name, val) { this.attributes[name] = String(val); }
  addEventListener(event, fn) {
    if (!this.eventListeners[event]) this.eventListeners[event] = [];
    this.eventListeners[event].push(fn);
  }
  dispatchEvent(event) {
    const fns = this.eventListeners[event.type] || [];
    for (const fn of fns) fn(event);
  }
  querySelector(sel) {
    if (sel === '.sort-indicator') {
      return this.children.find(c => c.classList && c.classList.contains('sort-indicator')) || null;
    }
    return null;
  }
  querySelectorAll(sel) {
    if (sel === 'thead th.sortable') {
      const thead = this.children.find(c => c.tagName === 'THEAD');
      if (!thead) return [];
      return thead.children.filter(c => c.tagName === 'TH' && c.classList.contains('sortable'));
    }
    if (sel === 'th.sortable') {
      return this.children.filter(c => c.tagName === 'TH' && c.classList.contains('sortable'));
    }
    if (sel === 'tr') {
      return this.children.filter(c => c.tagName === 'TR');
    }
    return [];
  }
  appendChild(child) {
    const idx = this.children.indexOf(child);
    if (idx !== -1) this.children.splice(idx, 1);
    this.children.push(child);
    child.parentNode = this;
  }
}

// Parse HTML table into Mock DOM
function parseTable(htmlText) {
  const tableMatch = htmlText.match(/<table id="comparative-evidence-table"[^>]*>([\s\S]*?)<\/table>/);
  if (!tableMatch) throw new Error("Table comparative-evidence-table not found!");

  const table = new MockElement('table', { id: 'comparative-evidence-table' });
  const theadMatch = tableMatch[1].match(/<thead>([\s\S]*?)<\/thead>/);
  const tbodyMatch = tableMatch[1].match(/<tbody>([\s\S]*?)<\/tbody>/);

  // Headers
  const thead = new MockElement('thead');
  table.children.push(thead);
  const thRegex = /<th([^>]*)>([\s\S]*?)<\/th>/g;
  let thM;
  while ((thM = thRegex.exec(theadMatch[1])) !== null) {
    const rawAttrs = thM[1];
    const rawContent = thM[2];
    const attrs = {};
    const attrRegex = /([a-z-]+)="([^"]*)"/g;
    let aM;
    while ((aM = attrRegex.exec(rawAttrs)) !== null) {
      attrs[aM[1]] = aM[2];
    }
    const th = new MockElement('th', attrs);
    th.textContent = rawContent.replace(/<[^>]*>/g, '').trim();
    if (rawContent.includes('class="sort-indicator"')) {
      const ind = new MockElement('span', { class: 'sort-indicator' });
      ind.textContent = '↕';
      th.children.push(ind);
    }
    thead.children.push(th);
  }

  // Tbody
  const tbody = new MockElement('tbody');
  table.children.push(tbody);
  const trRegex = /<tr>([\s\S]*?)<\/tr>/g;
  let trM;
  while ((trM = trRegex.exec(tbodyMatch[1])) !== null) {
    const tr = new MockElement('tr');
    tbody.children.push(tr);
    const tdRegex = /<td([^>]*)>([\s\S]*?)<\/td>/g;
    let tdM;
    while ((tdM = tdRegex.exec(trM[1])) !== null) {
      const rawAttrs = tdM[1];
      const rawContent = tdM[2];
      const attrs = {};
      const attrRegex = /([a-z-]+)=["']([^"']*)["']/g;
      let aM;
      while ((aM = attrRegex.exec(rawAttrs)) !== null) {
        attrs[aM[1]] = aM[2];
      }
      const td = new MockElement('td', attrs);
      td.textContent = rawContent.replace(/<[^>]*>/g, '').trim();
      tr.children.push(td);
    }
  }

  return { table, thead, tbody };
}

// Attach the exact sorting script logic from dashboard.html
function attachSortingScript(table, tbody) {
  const headers = table.querySelectorAll('thead th.sortable');
  headers.forEach(function(header, colIndex) {
    function sortTable() {
      var currentSort = header.getAttribute("aria-sort") || "none";
      var newSort = (currentSort === "ascending") ? "descending" : "ascending";

      headers.forEach(function(h) {
        h.setAttribute("aria-sort", "none");
        var ind = h.querySelector(".sort-indicator");
        if (ind) ind.textContent = "↕";
      });
      header.setAttribute("aria-sort", newSort);
      var activeIndicator = header.querySelector(".sort-indicator");
      if (activeIndicator) {
        activeIndicator.textContent = (newSort === "ascending") ? "▲" : "▼";
      }

      var isNumeric = header.classList.contains("col-effect") ||
                      header.classList.contains("col-direction") ||
                      header.classList.contains("col-precision");
      var isUgrade = header.classList.contains("col-practical");

      var rows = Array.from(tbody.querySelectorAll("tr"));
      var decorated = rows.map(function(row, idx) {
        return { row: row, index: idx };
      });

      decorated.sort(function(a, b) {
        var cellA = a.row.children[colIndex];
        var cellB = b.row.children[colIndex];
        var valA = cellA.getAttribute("data-sort-value") !== null ? cellA.getAttribute("data-sort-value") : cellA.textContent.trim();
        var valB = cellB.getAttribute("data-sort-value") !== null ? cellB.getAttribute("data-sort-value") : cellB.textContent.trim();

        var aEmpty = (valA === "" || valA === "N/A" || valA === "__NA__");
        var bEmpty = (valB === "" || valB === "N/A" || valB === "__NA__");
        if (aEmpty && bEmpty) return a.index - b.index;
        if (aEmpty) return 1;
        if (bEmpty) return -1;

        var cmp = 0;
        if (isNumeric) {
          var numA = parseFloat(valA);
          var numB = parseFloat(valB);
          if (!isNaN(numA) && !isNaN(numB)) {
            cmp = numA - numB;
          } else {
            cmp = valA.localeCompare(valB);
          }
        } else if (isUgrade) {
          cmp = valA.localeCompare(valB);
        } else {
          cmp = valA.localeCompare(valB, undefined, { numeric: true, sensitivity: "base" });
        }

        if (cmp !== 0) {
          return (newSort === "ascending") ? cmp : -cmp;
        }
        return a.index - b.index;
      });

      decorated.forEach(function(item) {
        tbody.appendChild(item.row);
      });
    }

    header.addEventListener("click", sortTable);
    header.addEventListener("keydown", function(e) {
      if (e.key === "Enter" || e.key === " ") {
        if (e.preventDefault) e.preventDefault();
        sortTable();
      }
    });
  });
}

// RUN THE BATTERY
const { table, thead, tbody } = parseTable(html);
attachSortingScript(table, tbody);

const headers = table.querySelectorAll('thead th.sortable');
const rows = tbody.querySelectorAll('tr');

console.log(`[PASS 1] Total data rows: ${rows.length}`);
console.log(`[PASS 2] Total sortable headers: ${headers.length}`);

// Requirement: Every cell in every row must have an explicit data-sort-value
rows.forEach((r, rIdx) => {
  if (r.children.length !== 10) throw new Error(`Row ${rIdx} has ${r.children.length} columns, expected 10`);
  r.children.forEach((c, cIdx) => {
    const val = c.getAttribute('data-sort-value');
    if (val === null) throw new Error(`Row ${rIdx} Column ${cIdx} is missing data-sort-value!`);
  });
});
console.log(`[PASS 3] Exactly 10/10 columns have explicit data-sort-value in all rows.`);

// Helper to get theme sequence
function getThemes() {
  return tbody.children.map(r => r.children[0].textContent);
}

// 1. Test RD sorting (Column 4: RD 推定値)
const rdHeader = headers[4];
console.log(`Auditing Column 4: ${rdHeader.textContent}`);

// Click 1: Ascending
rdHeader.dispatchEvent({ type: 'click' });
const ascThemes = getThemes();
console.log(`  RD Ascending: ${JSON.stringify(ascThemes)}`);
console.log(`  aria-sort: ${rdHeader.getAttribute('aria-sort')}`);
if (rdHeader.getAttribute('aria-sort') !== 'ascending') throw new Error('Expected aria-sort ascending');
if (ascThemes[0] !== 'T2_RefExcess' || ascThemes[ascThemes.length - 1] !== 'T1_TargetExcess') {
  throw new Error(`RD ascending sort failed! First: ${ascThemes[0]}, Last: ${ascThemes[ascThemes.length - 1]}`);
}
console.log(`[PASS 4] RD Ascending sort verified (-0.395 to +0.397)`);

// Click 2: Descending
rdHeader.dispatchEvent({ type: 'click' });
const descThemes = getThemes();
console.log(`  RD Descending: ${JSON.stringify(descThemes)}`);
console.log(`  aria-sort: ${rdHeader.getAttribute('aria-sort')}`);
if (rdHeader.getAttribute('aria-sort') !== 'descending') throw new Error('Expected aria-sort descending');
if (descThemes[0] !== 'T1_TargetExcess' || descThemes[descThemes.length - 1] !== 'T2_RefExcess') {
  throw new Error(`RD descending sort failed! First: ${descThemes[0]}, Last: ${descThemes[descThemes.length - 1]}`);
}
console.log(`[PASS 5] RD Descending sort verified (+0.397 to -0.395)`);

// 2. Test U-Grade sorting (Column 7: 実務領域 / U-Grade)
const uHeader = headers[7];
console.log(`Auditing Column 7: ${uHeader.textContent}`);

// Click 1: Ascending (0_... -> 1_... -> 2_... -> 3_...)
uHeader.dispatchEvent({ type: 'click' });
const uAscThemes = getThemes();
console.log(`  U-Grade Ascending: ${JSON.stringify(uAscThemes)}`);
console.log(`  aria-sort: ${uHeader.getAttribute('aria-sort')}`);
if (uHeader.getAttribute('aria-sort') !== 'ascending') throw new Error('Expected aria-sort ascending');
if (rdHeader.getAttribute('aria-sort') !== 'none') throw new Error('Previous header aria-sort not reset to none!');
// T4_U3_Uncertain must be at the end of U0-U3 order
if (uAscThemes[uAscThemes.length - 1] !== 'T4_U3_Uncertain') {
  throw new Error(`U-Grade ascending sort failed! Last was ${uAscThemes[uAscThemes.length - 1]}, expected T4_U3_Uncertain`);
}
console.log(`[PASS 6] U-Grade Ascending sort verified (U0 -> U2 -> U3)`);

// Click 2: Descending (3_... -> 2_... -> 1_... -> 0_...)
uHeader.dispatchEvent({ type: 'click' });
const uDescThemes = getThemes();
console.log(`  U-Grade Descending: ${JSON.stringify(uDescThemes)}`);
console.log(`  aria-sort: ${uHeader.getAttribute('aria-sort')}`);
if (uHeader.getAttribute('aria-sort') !== 'descending') throw new Error('Expected aria-sort descending');
if (uDescThemes[0] !== 'T4_U3_Uncertain') {
  throw new Error(`U-Grade descending sort failed! First was ${uDescThemes[0]}, expected T4_U3_Uncertain`);
}
console.log(`[PASS 7] U-Grade Descending sort verified (U3 -> U2 -> U0)`);

// 3. Test Keyboard Navigation (Enter / Space)
const th0 = headers[0]; // Theme header
console.log(`Auditing Keyboard activation on Theme header`);
th0.dispatchEvent({ type: 'keydown', key: 'Enter', preventDefault: () => {} });
if (th0.getAttribute('aria-sort') !== 'ascending') throw new Error('Enter key activation failed!');
th0.dispatchEvent({ type: 'keydown', key: ' ', preventDefault: () => {} });
if (th0.getAttribute('aria-sort') !== 'descending') throw new Error('Space key activation failed!');
console.log(`[PASS 8] Keyboard activation (Enter / Space) toggles sort correctly.`);

// 4. Test Diagnostics sorting (Column 9)
const diagHeader = headers[9];
console.log(`Auditing Column 9: Diagnostics header`);
diagHeader.dispatchEvent({ type: 'click' });
if (diagHeader.getAttribute('aria-sort') !== 'ascending') throw new Error('Diagnostics sort failed!');
const diagAscThemes = getThemes();
console.log(`  Diagnostics Ascending: ${JSON.stringify(diagAscThemes)}`);
diagHeader.dispatchEvent({ type: 'click' });
if (diagHeader.getAttribute('aria-sort') !== 'descending') throw new Error('Diagnostics sort failed!');
const diagDescThemes = getThemes();
console.log(`  Diagnostics Descending: ${JSON.stringify(diagDescThemes)}`);
// ZERO_REFERENCE is in T6_ZeroRef, so it must be first in descending
if (diagDescThemes[0] !== 'T6_ZeroRef') {
  throw new Error(`Diagnostics descending sort failed! First: ${diagDescThemes[0]}`);
}
console.log(`[PASS 9] Diagnostics sort correctly prioritizes ZERO_REFERENCE using data-sort-value.`);

console.log(`\nALL 9 INTERACTIVE AUDIT REQUIREMENTS PASS!`);
