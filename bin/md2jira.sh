#!/usr/bin/env bash
# Convert Markdown to Jira wiki markup (the string body that /rest/api/2 takes).
#
# Pure filter: stdin -> stdout. No network, no Jira knowledge, no side effects,
# so it can be unit-tested against a fixture. Used by /spec-post to render a spec
# note into a PM-facing comment.
#
# Handles: headings, bold, strikethrough, inline code, links, images, fenced code,
# tables (header row -> ||a||b||, separator dropped), bullets (nested), ordered
# lists, task checkboxes, blockquotes, horizontal rules. Anything else passes
# through untouched. Escaped pipes inside table cells become &#124; (a literal |
# would otherwise split the cell).
#
# Usage: md2jira.sh < in.md > out.wiki
set -euo pipefail

exec awk '
function repeat(c, n,   s, i) { s = ""; for (i = 0; i < n; i++) s = s c; return s }

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function indent_of(s) { match(s, /^[ \t]*/); return RLENGTH }

function depth_of(s,   ind) { ind = indent_of(s); return int(ind / 2) + 1 }

# Inline conversions, in dependency order. Code spans are lifted out first so
# nothing inside them is rewritten, then restored last.
function inline(s,   out, i, n, code, tok, p, m, t, u) {
    n = 0
    out = ""
    while (match(s, /`[^`]+`/)) {
        n++
        code[n] = substr(s, RSTART + 1, RLENGTH - 2)
        out = out substr(s, 1, RSTART - 1) "\001" n "\002"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    # images ![alt](url) -> !url!   (before links; same shape)
    out = ""
    while (match(s, /!\[[^]]*\]\([^)]*\)/)) {
        m = substr(s, RSTART, RLENGTH)
        p = index(m, "](")
        u = substr(m, p + 2, length(m) - p - 2)
        out = out substr(s, 1, RSTART - 1) "!" u "!"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    # links [text](url) -> [text|url]
    out = ""
    while (match(s, /\[[^]]*\]\([^)]*\)/)) {
        m = substr(s, RSTART, RLENGTH)
        p = index(m, "](")
        t = substr(m, 2, p - 2)
        u = substr(m, p + 2, length(m) - p - 2)
        out = out substr(s, 1, RSTART - 1) "[" t "|" u "]"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    # Escape bare [brackets] — Jira reads them as link syntax, so "[DEV] config PR"
    # or "[MISSING]" would render as a broken link. Converted links (which now
    # contain |) and [~accountid:…] mentions are left alone.
    out = ""
    while (match(s, /\[[^]|~]*\]/)) {
        out = out substr(s, 1, RSTART - 1) "\\" substr(s, RSTART, RLENGTH - 1) "\\]"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    # bold **x** -> *x*   (single-asterisk markdown italics are left alone; Jira
    # renders them as bold, which is close enough and safer than guessing)
    out = ""
    while (match(s, /\*\*[^*]+\*\*/)) {
        out = out substr(s, 1, RSTART - 1) "*" substr(s, RSTART + 2, RLENGTH - 4) "*"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    # strikethrough ~~x~~ -> -x-
    out = ""
    while (match(s, /~~[^~]+~~/)) {
        out = out substr(s, 1, RSTART - 1) "-" substr(s, RSTART + 2, RLENGTH - 4) "-"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    for (i = 1; i <= n; i++) {
        tok = "\001" i "\002"
        p = index(s, tok)
        if (p > 0) s = substr(s, 1, p - 1) "{{" code[i] "}}" substr(s, p + length(tok))
    }
    return s
}

function cells(line, sep,   s, i, k, a, c, res) {
    s = trim(line)
    sub(/^\|/, "", s)
    sub(/\|$/, "", s)
    gsub(/\\\|/, "\003", s)
    k = split(s, a, "|")
    res = ""
    for (i = 1; i <= k; i++) {
        c = trim(a[i])
        gsub(/\003/, "\\&#124;", c)
        res = res sep inline(c)
    }
    return res sep
}

{ L[NR] = $0 }

END {
    in_fence = 0
    skip_next = 0
    for (i = 1; i <= NR; i++) {
        line = L[i]

        if (line ~ /^[ \t]*```/) {
            if (in_fence) { print "{code}"; in_fence = 0 }
            else {
                lang = line
                sub(/^[ \t]*```/, "", lang)
                lang = trim(lang)
                print (lang == "" ? "{code}" : "{code:" lang "}")
                in_fence = 1
            }
            continue
        }
        if (in_fence) { print line; continue }
        if (skip_next) { skip_next = 0; continue }

        # table rows: a header row is one whose next line is the |---|---| rule
        if (line ~ /^[ \t]*\|.*\|[ \t]*$/) {
            if (i < NR && L[i+1] ~ /^[ \t]*\|[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)*\|[ \t]*$/) {
                print cells(line, "||")
                skip_next = 1
            } else {
                print cells(line, "|")
            }
            continue
        }

        if (match(line, /^#{1,6} /)) {
            print "h" (RLENGTH - 1) ". " inline(substr(line, RLENGTH + 1))
            continue
        }

        if (line ~ /^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$/) { print "----"; continue }

        # Obsidian callout: "> [!warning] title" + following quoted lines.
        # Rendered as the matching Jira macro so it keeps its emphasis box.
        if (match(line, /^[ \t]*> *\[![A-Za-z]+\]/)) {
            hd = substr(line, RSTART, RLENGTH)
            rest = trim(substr(line, RSTART + RLENGTH))
            match(hd, /\[![A-Za-z]+\]/)
            kind = tolower(substr(hd, RSTART + 2, RLENGTH - 3))
            if (kind != "warning" && kind != "note" && kind != "info" && kind != "tip") kind = "panel"
            print "{" kind (rest == "" ? "" : ":title=" rest) "}"
            j = i + 1
            while (j <= NR && L[j] ~ /^[ \t]*>/) {
                q = L[j]
                sub(/^[ \t]*> ?/, "", q)
                print inline(q)
                j++
            }
            print "{" kind "}"
            i = j - 1
            continue
        }

        # Plain blockquote: group consecutive lines into {quote}, single line as bq.
        if (match(line, /^[ \t]*> ?/)) {
            if (i < NR && L[i+1] ~ /^[ \t]*>/) {
                print "{quote}"
                j = i
                while (j <= NR && L[j] ~ /^[ \t]*>/) {
                    q = L[j]
                    sub(/^[ \t]*> ?/, "", q)
                    print inline(q)
                    j++
                }
                print "{quote}"
                i = j - 1
            } else {
                print "bq. " inline(substr(line, RLENGTH + 1))
            }
            continue
        }

        # NOTE: depth_of() runs match() internally, so RLENGTH must be captured
        # before it is called — otherwise the list marker is never stripped.
        if (match(line, /^[ \t]*[-*+] \[[ xX]\] /)) {
            len = RLENGTH
            mark = (substr(line, 1, len) ~ /\[[xX]\]/) ? "(/)" : "(?)"
            print repeat("*", depth_of(line)) " " mark " " inline(substr(line, len + 1))
            continue
        }

        if (match(line, /^[ \t]*[-*+] /)) {
            len = RLENGTH
            print repeat("*", depth_of(line)) " " inline(substr(line, len + 1))
            continue
        }

        if (match(line, /^[ \t]*[0-9]+\. /)) {
            len = RLENGTH
            print repeat("#", depth_of(line)) " " inline(substr(line, len + 1))
            continue
        }

        print inline(line)
    }
    if (in_fence) print "{code}"
}
' "$@"
