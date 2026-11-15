<!-- EIDO repository presentation. Detailed technical documentation is preserved below. -->
<p align="center"><img src="docs/assets/eido-project-banner.svg" alt="freps — EIDO Automation" width="100%"></p>

# freps

**Recursive search, replace and file operations for Windows**

A compact Windows batch utility for recursive search, rename, replace, listing, undo and guarded deletion.

[![License: MIT](https://img.shields.io/badge/License-MIT-5bbc85.svg)](LICENSE)

**Maintained by [EIDO Automation](https://github.com/EidoAut).** See the [MIT license](LICENSE) for reuse conditions. The capabilities and limitations described below are those of this repository, not a guarantee of production suitability.

## Explore

- [Documentation and usage](#project-documentation)
- [Source code](./)
- [License](LICENSE)

## Project documentation

**freps** is a small, dependency-free **Windows batch tool** to work recursively with files and folders:

- **Rename**: find & replace in file/folder names (`mode: r`)
- **Replace**: find & replace inside file contents (`mode: p`)
- **Search**: find text across files (lines or filenames only) (`mode: s`)
- **List**: show files whose **name** contains a string (`mode: l`)
- ↩ **Undo**: restore `.bak` backups created during replace (`mode: u`)
- 🗑 **Delete**: remove files by **name** (safe by default; requires `/F`) (`mode: d`)

MIT licensed. Single `bat` file. No external tools.

---

## Installation

Copy `freps.bat` to a folder in your `PATH` (e.g., `C:\Windows\System32`) so you can call it directly from **cmd**:

```cmd
freps /?
```

---

## Usage

```bat
freps MODE FROM TO DIR [EXT...] [/N] [/V] [/B] [/Q] [/M] [/CS] [/RX] [/F] [/DBG]
```

### Modes

| Mode | Description |
|------|-------------|
| `r` | Rename files/folders (find & replace in names) |
| `p` | Replace text inside file contents |
| `s` | Search text inside files (print matching lines by default) |
| `l` | List files whose **name** contains `FROM` |
| `u` | Undo: restore `.bak` files (from `/B` in replace) |
| `d` | Delete files by **name** (requires `/F` to actually delete) |

### Arguments

| Arg | Meaning |
|---:|---|
| `FROM` | Text to search for (ignored only in `u`) |
| `TO` | Replacement text (ignored in `s`, `l`, `u`, `d`) |
| `DIR` | Base directory (searched recursively) |
| `EXT` | Optional extensions with dot, e.g. `.txt .cfg .idf` |

### Flags

| Flag | Scope | Description |
|-----:|------|-------------|
| `/N` | r, p, u | Dry-run: show actions, do not modify |
| `/V` | all | Verbose/debug output |
| `/B` | p | Create `.bak` backup before writing |
| `/Q` | all | Quiet mode (suppress info lines) |
| `/M` | s | Filenames only (no lines) |
| `/CS` | s | Case-sensitive search |
| `/RX` | s | Treat `FROM` as regex (native `findstr`) |
| `/F` | d | **Force** deletion (required to actually delete) |
| `/DBG` | all | Print internal debug trace (`echo on` + tagged steps) |

---

## Examples

```bat
:: Rename files and folders (names)
freps r draft final "C:\work\repo"

:: Replace text in files (with backups and verbose)
freps p dev prod "C:\work\repo" .env .cfg /B /V

:: Search text (case-insensitive by default)
freps s token "" "C:\logs" .log .txt

:: Search: list only filenames with matches
freps s ERROR "" "C:\logs" .log /M

:: Search: regex (word boundary), note escaping for cmd
freps s ^\bTODO\b "" "C:\work" .txt /RX

:: Search: case-sensitive
freps s Token "" "C:\work" .cfg /CS

:: List files by NAME containing “report”
freps l report "" "C:\work\reports" .pdf .docx

:: Undo: restore from .bak (simulate first)
freps u "" "" "C:\work\repo" /N
freps u "" "" "C:\work\repo"

:: Delete files by NAME (simulate, then apply)
freps d temp "" "C:\work\repo" .tmp .bak
freps d temp "" "C:\work\repo" .tmp .bak /F
```

---

## Notes & Limitations

- **Replace (`p`) is case-sensitive** due to `cmd.exe` variable substitution.  
 For true case-insensitive or regex replace, consider a PowerShell variant.
- Operates **line-by-line**; intended for **text** files.
- **Rename** processes files first, then folders deepest-first.
- **Delete (`d`)** requires `/F` to actually remove files. If both `/N` and `/F` are present, dry-run wins.
- `.bak` files from replace are simple file copies of the pre-modified content.

---

## Repo structure

```
freps/
├─ freps.bat
├─ README.md
├─ LICENSE
└─ .gitignore
```

`.gitignore`:

```gitignore
*.bak
*.tmp
```

---

## License

MIT © 2025 Samuel Seijo (EIDO AUTOMATION SL)
