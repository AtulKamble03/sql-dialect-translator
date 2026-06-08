# SQL Dialect Translator — Project Plan

## Project Overview

| Item | Detail |
|---|---|
| **Project Name** | SQL Dialect Translator |
| **Owner** | Atul Kamble |
| **Start Date** | 2026-06-08 |
| **Goal** | CLI tool that scans a folder for .sql files and produces fully restructured translations for both SQL Server and PostgreSQL using Claude AI |
| **Language** | C# (.NET 10) |
| **AI** | Anthropic Claude API (claude-sonnet-4-6) |
| **Repo** | [github.com/AtulKamble03/sql-dialect-translator](https://github.com/AtulKamble03/sql-dialect-translator) |

---

## Architecture

```
 ┌─────────────────────────────────────────────────────────────┐
 │                        INPUTS                               │
 │   --input <folder>          ANTHROPIC_API_KEY (env var)     │
 └──────────┬──────────────────────────┬────────────────────────┘
            │                          │
            ▼                          │
 ┌─────────────────┐                   │
 │  Program.cs     │  ← CLI args       │
 │  (Orchestrator) │                   │
 └────────┬────────┘                   │
          │                            │
          ▼                            │
 ┌─────────────────┐                   │
 │  FileScanner    │  Recursively find all .sql files in input folder
 └────────┬────────┘
          │  List of SqlFile objects
          ▼
 ┌─────────────────┐   reads   ┌──────────────────────┐
 │ DialectDetector │ ────────► │ Config/dialects.json │
 └────────┬────────┘           │  - sqlserver keywords│
          │                    │  - postgresql keywords│
          │ DetectionResult    └──────────────────────┘
          │ (dialect + confidence)
          ▼
 ┌──────────────────────────────────────────┐
 │          TranslationService              │
 │                                          │   reads   ┌───────────────┐
 │  ≤10 files → Sequential API calls        │ ────────► │ Config/       │
 │  11+ files → Batch API (concurrent)      │           │ Prompts.cs    │
 └────────┬─────────────────────────────────┘           └───────────────┘
          │  calls
          ▼
 ┌──────────────────────────┐
 │   Anthropic Claude API   │  (external — claude-sonnet-4-6)
 └────────┬─────────────────┘
          │  TranslationResult
          │  (MsSql version + PostgreSQL version)
          ▼
 ┌─────────────────┐
 │  OutputWriter   │
 └────────┬────────┘
          │
 ┌────────▼────────────────────┐
 │         OUTPUT              │
 │  /output/mssql/<file>.sql   │
 │  /output/postgresql/<file>  │
 └─────────────────────────────┘
```

### Component Responsibilities

| Component | File | What it does |
|---|---|---|
| `Program.cs` | Entry point | Parse CLI args, orchestrate the pipeline |
| `FileScanner` | Services/FileScanner.cs | Walk folder tree, return list of .sql file paths |
| `DialectDetector` | Services/DialectDetector.cs | Keyword scan → return SqlServer or PostgreSQL |
| `TranslationService` | Services/TranslationService.cs | Call Claude API, handle retries, return both translations |
| `BatchTranslationService` | Services/BatchTranslationService.cs | Anthropic Batch API for 11+ files |
| `OutputWriter` | Services/OutputWriter.cs | Create output folders, write translated files with header |
| `Prompts` | Config/Prompts.cs | All Claude prompt templates in one place |
| `TranslatorConfig` | Config/TranslatorConfig.cs | API key, model name, thresholds, paths |
| `SqlFile` | Models/SqlFile.cs | Represents one scanned .sql file |
| `DetectionResult` | Models/DetectionResult.cs | Dialect + confidence score |
| `TranslationResult` | Models/TranslationResult.cs | MsSql version + PostgreSQL version + metadata |

---

## Repo Structure

```
sql-dialect-translator/
├── src/
│   └── SqlDialectTranslator/
│       ├── SqlDialectTranslator.csproj
│       ├── Program.cs
│       ├── Services/
│       │   ├── FileScanner.cs
│       │   ├── DialectDetector.cs
│       │   ├── TranslationService.cs
│       │   └── BatchTranslationService.cs
│       │   └── OutputWriter.cs
│       ├── Models/
│       │   ├── SqlFile.cs
│       │   ├── DetectionResult.cs
│       │   └── TranslationResult.cs
│       └── Config/
│           ├── TranslatorConfig.cs
│           └── Prompts.cs
├── tests/
│   └── SqlDialectTranslator.Tests/
│       ├── SqlDialectTranslator.Tests.csproj
│       ├── DialectDetectorTests.cs
│       └── FileScannerTests.cs
├── sample-input/
│   ├── mssql/
│   │   └── sample_mssql.sql    ← sample SQL Server file for testing
│   └── postgresql/
│       └── sample_postgres.sql ← sample PostgreSQL file for testing
├── docs/
│   ├── requirements.md         ✅ Done
│   ├── project-plan.md         ✅ This file
│   └── design.md               ← detailed design decisions
├── .gitignore
├── README.md
└── SqlDialectTranslator.sln
```

---

## CLI Design

```
SqlTranslator [options]

  --input   <path>   Folder to scan for .sql files (required)
  --output  <path>   Output folder (default: ./output)
  --dry-run          List detected files and dialects — no translation
  --help             Show usage

Examples:
  SqlTranslator --input "C:\myrepo" --output "C:\translated"
  SqlTranslator --input ./sql-scripts --dry-run
```

**Console output during run:**
```
SQL Dialect Translator — Starting
Scanning: C:\myrepo
  Found: schema/create_tables.sql         → SQL Server
  Found: schema/create_indexes.sql        → SQL Server
  Found: migrations/v1_add_column.sql     → PostgreSQL
  Found: procs/usp_get_customer.sql       → SQL Server (ambiguous — defaulted)
  Total: 4 files

Translating (batch mode — 4 files)...
  [1/4] create_tables.sql     ✓
  [2/4] create_indexes.sql    ✓
  [3/4] v1_add_column.sql     ✓
  [4/4] usp_get_customer.sql  ✓

Output written to: C:\translated\mssql\
                   C:\translated\postgresql\

Summary: 4 files translated | 0 failed | Time: 42s
```

---

## Phase 1 — Project Setup
**Status: 🔲 Not Started**

Manual steps you will do:

| Task | Done? |
|---|---|
| Create new GitHub repo: `sql-dialect-translator` | 🔲 |
| Clone repo locally to `C:\Personal Workspace\sql-dialect-translator` | 🔲 |
| Create solution: `dotnet new sln -n SqlDialectTranslator` | 🔲 |
| Create CLI project: `dotnet new console -n SqlDialectTranslator -o src/SqlDialectTranslator` | 🔲 |
| Create test project: `dotnet new xunit -n SqlDialectTranslator.Tests -o tests/SqlDialectTranslator.Tests` | 🔲 |
| Add projects to solution | 🔲 |
| Install NuGet packages (Anthropic SDK, CommandLineParser) | 🔲 |
| Create folder structure (Services, Models, Config, docs, sample-input) | 🔲 |
| Add .gitignore (standard C# + API key protection) | 🔲 |
| Push initial structure to GitHub | 🔲 |

**NuGet packages needed:**
```
Anthropic.SDK                 ← Claude API client for C#
CommandLineParser             ← Parse --input --output --dry-run args
Microsoft.Extensions.Logging  ← Console logging
```

---

## Phase 2 — File Scanner
**Status: 🔲 Not Started**

**Goal:** Walk a folder tree recursively, collect all .sql file paths.

**What you will build:** `FileScanner.cs`

| Task | Done? |
|---|---|
| Write `FileScanner.cs` — recursive folder walk, collect .sql files | 🔲 |
| Write `SqlFile.cs` model — path, filename, raw content | 🔲 |
| Write `FileScannerTests.cs` — test with sample-input folder | 🔲 |
| Add sample .sql files to `sample-input/mssql/` and `sample-input/postgresql/` | 🔲 |
| Test: run scanner on sample-input — verify correct files collected | 🔲 |

**Key learning:** `Directory.GetFiles(path, "*.sql", SearchOption.AllDirectories)`

---

## Phase 3 — Dialect Detector
**Status: 🔲 Not Started**

**Goal:** Read a .sql file's content and determine if it's SQL Server or PostgreSQL.

**What you will build:** `DialectDetector.cs`, `DetectionResult.cs`

| Task | Done? |
|---|---|
| Define SQL Server keyword fingerprints (TOP, GETDATE, ISNULL, NVARCHAR, GO, IDENTITY, etc.) | 🔲 |
| Define PostgreSQL keyword fingerprints (LIMIT, NOW, COALESCE, SERIAL, RETURNING, ::, etc.) | 🔲 |
| Write scoring logic: count fingerprint hits per dialect, return winner | 🔲 |
| Handle ambiguous case: log warning, default to SQL Server | 🔲 |
| Write `DialectDetectorTests.cs` — test with known SQL Server and PostgreSQL files | 🔲 |
| Test: run detector on sample-input files — verify correct detection | 🔲 |

**Key learning:** Regex matching, scoring algorithms, handling ambiguity gracefully

---

## Phase 4 — Claude API Integration (Single File)
**Status: 🔲 Not Started**

**Goal:** Send one .sql file to Claude, receive SQL Server + PostgreSQL versions back.

**What you will build:** `TranslationService.cs`, `TranslationResult.cs`, `Prompts.cs`

| Task | Done? |
|---|---|
| Set up Anthropic SDK — add API key to config | 🔲 |
| Write prompt template in `Prompts.cs` | 🔲 |
| Write `TranslationService.cs` — call Claude, parse response | 🔲 |
| Write `TranslationResult.cs` model — MsSqlVersion, PostgreSqlVersion, SourceFile | 🔲 |
| Implement retry logic — 3 attempts, 5 second backoff | 🔲 |
| Test with one sample SQL Server file — verify PostgreSQL output is correct | 🔲 |
| Test with one sample PostgreSQL file — verify SQL Server output is correct | 🔲 |

**The prompt structure:**
```
You are a SQL dialect translation engine.
Input: a SQL file written in {sourceDialect}.
Task: Produce two complete, correct, executable versions:
  1. SQL Server (T-SQL) version
  2. PostgreSQL version
Rules:
  - Full restructuring — not keyword replacement
  - Preserve all logic, aliases, column names, comments
  - Handle all DDL and DML
  - Return ONLY SQL, no explanation
Format your response as:
=== MSSQL ===
<sql server version here>
=== POSTGRESQL ===
<postgresql version here>
```

---

## Phase 5 — Batch Translation (50+ Files)
**Status: 🔲 Not Started**

**Goal:** Translate all files concurrently using Anthropic Message Batches API.

**What you will build:** `BatchTranslationService.cs`

| Task | Done? |
|---|---|
| Write `BatchTranslationService.cs` — build batch request from all files | 🔲 |
| Submit batch to Anthropic — get batch ID | 🔲 |
| Poll batch status until complete | 🔲 |
| Parse batch results — map each result back to its source file | 🔲 |
| Route to OutputWriter as results arrive | 🔲 |
| Test with 20+ sample files | 🔲 |

**Threshold logic in Program.cs:**
```csharp
if (files.Count <= 10)
    await translationService.TranslateSequentialAsync(files);
else
    await batchTranslationService.TranslateBatchAsync(files);
```

**Key learning:** Async/await, polling patterns, batch API structure

---

## Phase 6 — Output Writer
**Status: 🔲 Not Started**

**Goal:** Write translated files to output folders with proper headers.

**What you will build:** `OutputWriter.cs`

| Task | Done? |
|---|---|
| Write `OutputWriter.cs` — create output dirs, write files | 🔲 |
| Add header comment to each output file (source, dialect, timestamp) | 🔲 |
| Handle filename collisions (two input files with same name from different folders) | 🔲 |
| Test: verify output folder structure and file content | 🔲 |

---

## Phase 7 — CLI Wiring and End-to-End Test
**Status: 🔲 Not Started**

**Goal:** Wire all components together in Program.cs. Run end-to-end with sample files.

| Task | Done? |
|---|---|
| Write `Program.cs` — parse args, call Scanner → Detector → Translator → Writer | 🔲 |
| Implement `--dry-run` mode | 🔲 |
| Implement summary output (files found, translated, failed, time elapsed) | 🔲 |
| End-to-end test: run on `sample-input/` — verify both output folders are correct | 🔲 |
| End-to-end test: run on a real SQL repo | 🔲 |

---

## Phase 8 — Polish and Publish
**Status: 🔲 Not Started**

| Task | Done? |
|---|---|
| Write `README.md` — usage, examples, setup instructions | 🔲 |
| Add API key instructions (environment variable, not hardcoded) | 🔲 |
| Publish as self-contained exe: `dotnet publish --self-contained` | 🔲 |
| Push final version to GitHub | 🔲 |

---

## Key Design Decisions

| Decision | Choice | Why |
|---|---|---|
| Language | C# .NET 9 | Team preference |
| AI model | claude-sonnet-4-6 | Best balance of quality and speed for code tasks |
| Translation approach | Full file per API call | Preserves context across multi-statement files |
| Batch threshold | 11+ files → Batch API | Batch API is 50% cheaper, handles scale |
| Output structure | Flat (no subfolders) | Simple in v1 — preserve input structure in v2 |
| Dialect ambiguity | Default to SQL Server | Most common source dialect in target environments |
| API key storage | Environment variable `ANTHROPIC_API_KEY` | Never hardcode secrets |
| Prompt location | `Prompts.cs` only | One place to tune without touching logic |

---

## What You Will Learn

| Phase | Concept |
|---|---|
| 1 | .NET solution structure, NuGet packages, project references |
| 2 | File I/O in C# — Directory, File, Path classes |
| 3 | Regex in C#, scoring algorithms |
| 4 | Anthropic SDK in C#, async/await, prompt engineering |
| 5 | Batch API, polling pattern, concurrent processing |
| 6 | Writing structured file output, handling edge cases |
| 7 | CLI argument parsing, end-to-end integration |
| 8 | Publishing .NET apps as self-contained executables |
