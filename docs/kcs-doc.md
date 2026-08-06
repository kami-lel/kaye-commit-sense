# Kaye Commit Sense Documentation

## Sigil Meaning

| Sigil | Remark |
|---|---|
| 🔢 | non-text content changed |
| 📄 | whole file added |
| 🗑️ | whole file deleted |
| 📂 | moved, content kept |
| 📛 | renamed, content kept |
| 🔒 | file mode only |
| 📏 | whitespace only |
| 🔖 | [triage tags](#triage-tags) only |
| 📝 | code comments only |
| ♻️ | restructured, behavior unchanged |
| 🤖 | agent instructions changed |
| 🧪 | tests changed |
| 🧸 | examples or demonstration code changed |
| 🔨 | build or compilation changed |
| 📦 | packaging metadata changed |
| ⚙️ | configuration or settings changed |
| 🔰 | readme changed |
| 🏷️ | version changed |
| 🪧 | changelog changed |
| 🪵 | development log changed |
| 📖 | documentation changed |

These six cover the ordinary edit — the case no earlier rule claims. Color carries the balance of added against deleted lines, and shape carries the form: circle for short, square for long.

| Line Balance | Short | Long |
|---|---|---|
| more lines Added than deleted | 🟢 | 🟩 |
| more lines Deleted than added | 🔴 | 🟥 |
| added and deleted roughly Balanced | 🟡 | 🟨 |
