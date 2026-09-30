"""Renders docs/privacy-policy.md to _site/index.html for GitHub Pages."""
import pathlib

import markdown

body = markdown.markdown(
    pathlib.Path("docs/privacy-policy.md").read_text(encoding="utf-8"),
    extensions=["tables"],
)
page = f"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RENOK Gizlilik Politikası</title>
<style>
body{{font:16px/1.6 system-ui,sans-serif;max-width:760px;margin:0 auto;padding:24px 16px;color:#1c1c1e}}
table{{border-collapse:collapse}}td,th{{border:1px solid #ccc;padding:6px 10px}}
hr{{margin:40px 0}}
</style>
</head>
<body>
{body}
</body>
</html>
"""
out = pathlib.Path("_site")
out.mkdir(exist_ok=True)
(out / "index.html").write_text(page, encoding="utf-8")
