# freps (Find, REPlace, Search)

**freps** is a small, dependency-free **Windows batch tool** for:
- 🔄 Find & replace in **file/folder names** (`mode: r`)
- 📝 Find & replace in **file contents** (`mode: p`)
- 🔍 **Search** text across files with flexible options (`mode: s`)

- Works with legacy ordered arguments.
- Adds useful flags: `/N` (dry-run), `/V` (verbose), `/B` (backup), `/Q` (quiet).
- Search-specific: `/M` (filenames only), `/CS` (case-sensitive), `/RX` (regex).

## Installation

Copy `freps.bat` to a folder in your `PATH` (e.g., `C:\Windows\System32`) so you can call it directly from `cmd`.

```cmd
freps /?
```

## Usage

```bat
freps MODE FROM TO DIR [EXT...] [/N] [/V] [/B] [/Q] [/M] [/CS] [/RX]
```

| Argument | Description |
|---------:|-------------|
| `MODE` | `r` (rename), `p` (replace), `s` (search) |
| `FROM` | Text to search for |
| `TO` | Replacement text (ignored in `s`) |
| `DIR` | Base directory (searched recursively) |
| `EXT` | Extensions with dot, e.g. `.txt .cfg .idf` |

### Examples

```bat
:: Rename files and folders
freps r HC54 HC99 "C:\path\to\project"

:: Replace text (with backups and verbose output)
freps p HC54 HC99 "C:\path\to\project" .idf .ids /B /V

:: Search text (case-insensitive by default)
freps s HC54 "" "C:\path\to\project" .idf .ids .txt

:: Search: list only filenames that contain matches
freps s HC54 "" "C:\path\to\project" .txt /M

:: Search: regex (word boundary), note escaping for cmd
freps s ^\bHC54\b "" "C:\path\to\project" .txt /RX

:: Search: case-sensitive
freps s HC54 "" "C:\path\to\project" .txt /CS
```

## Notes & Limitations

- Content replacement (`mode: p`) is **case-sensitive** due to `cmd.exe` substitution behavior.
- Operates line-by-line; intended for **text** files.
- Rename runs files first, then folders from deepest to shallowest.

## License

MIT © 2025 Samuel Seijo (EIDO AUTOMATION SL)
