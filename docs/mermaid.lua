-- ---
-- title: Render Mermaid Code Blocks on the Docs Site
-- author: Brendan Casey
-- created: 2026-10-07
-- inputs: ```mermaid fenced code blocks in the site's pages
-- outputs: <pre class="mermaid"> blocks, and the mermaid.js
--   script, in the HTML
-- notes:
--   - GitHub renders ```mermaid blocks; Quarto only renders its
--     own {mermaid} cells. This filter lets one Markdown source
--     show the diagram in both places.
-- ---

local function escape_html(text)
  return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local used = false

function CodeBlock(block)
  if not block.classes:includes("mermaid") then
    return nil
  end

  used = true
  return pandoc.RawBlock(
    "html",
    '<pre class="mermaid">' .. escape_html(block.text) .. "</pre>"
  )
end

function Pandoc(doc)
  if used then
    quarto.doc.include_text("after-body", [[
<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
mermaid.initialize({ startOnLoad: true });
</script>]])
  end
  return doc
end
