# SQL Dialect Translator

A C# CLI tool that scans a folder for `.sql` files, detects whether each file is written
in **SQL Server (T-SQL)** or **PostgreSQL** dialect, and uses **Claude AI** to produce
fully restructured translations for both dialects.

---

## What It Does

```
Input folder (any repo or directory)
    ↓  scan recursively for .sql files
    ↓  detect dialect per file (SQL Server or PostgreSQL)
    ↓  translate via Claude AI — full restructuring, not find/replace
    ↓
output/
  mssql/       ← SQL Server version of every file
  postgresql/  ← PostgreSQL version of every file
```

---

## Usage

```bash
SqlTranslator --input "C:\myrepo" --output "C:\output"
SqlTranslator --input ./sql-scripts --dry-run
SqlTranslator --help
```

### Options

| Option | Description |
|---|---|
| `--input` | Path to folder to scan (required) |
| `--output` | Output directory (default: `./output`) |
| `--dry-run` | Detect and list files — no translation |
| `--help` | Show usage |

---

## Setup

### Prerequisites
- .NET 10 SDK
- Anthropic API key

### API Key
Set your Anthropic API key as an environment variable:
```bash
# Windows
set ANTHROPIC_API_KEY=your-key-here

# PowerShell
$env:ANTHROPIC_API_KEY = "your-key-here"
```

### Run
```bash
cd src/SqlDialectTranslator
dotnet run -- --input "C:\myrepo" --output "C:\output"
```

### Build self-contained executable
```bash
dotnet publish -c Release --self-contained
```

---

## Tech Stack

| | |
|---|---|
| Language | C# (.NET 10) |
| AI | Anthropic Claude API |
| Testing | xUnit + Moq + FluentAssertions |
| CLI parsing | CommandLineParser |
| Dialect config | `config/dialects.json` |

---

## Project Structure

```
sql-dialect-translator/
├── src/SqlDialectTranslator/
│   ├── Program.cs
│   ├── Services/        FileScanner, DialectDetector, TranslationService, OutputWriter
│   ├── Models/          SqlFile, DetectionResult, TranslationResult
│   └── Config/          TranslatorConfig, Prompts
├── tests/SqlDialectTranslator.Tests/
│   ├── Unit/            Fast tests — no external dependencies
│   ├── Integration/     Real Claude API tests (run manually)
│   ├── E2E/             Full pipeline tests
│   └── TestData/        Sample SQL files for testing
├── config/
│   └── dialects.json    Keyword fingerprints per dialect
├── sample-input/
│   ├── mssql/           Sample SQL Server files
│   └── postgresql/      Sample PostgreSQL files
└── docs/
    ├── requirements.md
    ├── project-plan.md
    └── testing-plan.md
```

---

## Running Tests

```bash
# Unit tests only (fast)
dotnet test --filter "Category=Unit"

# All tests (requires ANTHROPIC_API_KEY)
dotnet test

# With coverage
dotnet test --collect:"XPlat Code Coverage"
```

---

## Documentation

- [Requirements](docs/requirements.md)
- [Project Plan](docs/project-plan.md)
- [Testing Plan](docs/testing-plan.md)
