# SQL Dialect Translator — Testing Plan

## Philosophy

- **No false positives.** Every test must verify real behaviour, not just that code runs without crashing.
- **Automated only.** All tests run with one command: `dotnet test`
- **Unit tests are isolated.** No real API calls, no real file system writes — mock everything external.
- **Integration tests are labelled separately.** Run them intentionally, not in CI by default.
- **Each component has its own test class.** Fail in one area = easy to locate.

---

## Test Framework Stack

| Package | Purpose |
|---|---|
| `xUnit` | Test runner — industry standard for modern .NET |
| `Moq` | Mock the Anthropic API client — no real API calls in unit tests |
| `FluentAssertions` | Readable assertions (`result.Should().Be("SqlServer")`) |
| `Microsoft.NET.Test.Sdk` | Required by dotnet test |
| `coverlet.collector` | Code coverage — tells you what % of your code is tested |

Install via:
```
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package Moq
dotnet add package FluentAssertions
dotnet add package coverlet.collector
```

---

## Test Categories

Mark every test with a category trait so you can filter:

```csharp
[Trait("Category", "Unit")]         // fast, no external deps — run always
[Trait("Category", "Integration")]  // real API calls — run manually
[Trait("Category", "E2E")]          // full pipeline run — run manually
```

Run only unit tests (for CI/CD):
```
dotnet test --filter "Category=Unit"
```

Run everything:
```
dotnet test
```

---

## Test Structure

```
tests/
└── SqlDialectTranslator.Tests/
    ├── SqlDialectTranslator.Tests.csproj
    ├── Unit/
    │   ├── FileScannerTests.cs
    │   ├── DialectDetectorTests.cs
    │   ├── TranslationServiceTests.cs
    │   └── OutputWriterTests.cs
    ├── Integration/
    │   └── TranslationIntegrationTests.cs   ← real Claude API
    ├── E2E/
    │   └── EndToEndTests.cs                 ← full pipeline
    └── TestData/
        ├── mssql/
        │   ├── simple_select.sql
        │   ├── create_table.sql
        │   ├── stored_procedure.sql
        │   └── complex_query.sql
        ├── postgresql/
        │   ├── simple_select.sql
        │   ├── create_table.sql
        │   ├── function.sql
        │   └── complex_query.sql
        ├── ambiguous/
        │   └── mixed_keywords.sql           ← for ambiguity tests
        └── empty/
            └── empty_file.sql
```

---

## Unit Tests — FileScanner

**File:** `Unit/FileScannerTests.cs`

| Test | What it verifies |
|---|---|
| `Scan_ValidFolder_ReturnsSqlFilesOnly` | Only .sql files returned, not .txt .cs .json |
| `Scan_NestedSubfolders_ReturnsAllSqlFiles` | Recursion works — finds files in subfolders |
| `Scan_EmptyFolder_ReturnsEmptyList` | No files found → returns empty list, no crash |
| `Scan_FolderDoesNotExist_ThrowsArgumentException` | Bad path → meaningful error |
| `Scan_FolderWithNoSqlFiles_ReturnsEmptyList` | Folder has files but none are .sql |
| `Scan_SqlFileContent_IsReadCorrectly` | File content matches what's on disk |

```csharp
[Fact]
[Trait("Category", "Unit")]
public void Scan_ValidFolder_ReturnsSqlFilesOnly()
{
    // Arrange
    var testFolder = Path.Combine(TestDataPath, "mssql");
    var scanner = new FileScanner();

    // Act
    var result = scanner.Scan(testFolder);

    // Assert
    result.Should().NotBeEmpty();
    result.Should().OnlyContain(f => f.FilePath.EndsWith(".sql"));
}
```

---

## Unit Tests — DialectDetector

**File:** `Unit/DialectDetectorTests.cs`

| Test | What it verifies |
|---|---|
| `Detect_SqlServerKeywords_ReturnsSqlServer` | File with TOP, GETDATE, ISNULL → SqlServer |
| `Detect_PostgreSqlKeywords_ReturnsPostgreSql` | File with LIMIT, NOW, COALESCE → PostgreSQL |
| `Detect_EmptyFile_DefaultsToSqlServer` | Empty file → SqlServer (safe default) |
| `Detect_AmbiguousFile_DefaultsToSqlServerWithWarning` | Mixed keywords → SqlServer + logs warning |
| `Detect_StrongSqlServerSignal_HighConfidence` | File full of T-SQL → high confidence score |
| `Detect_StrongPostgreSqlSignal_HighConfidence` | File full of PG SQL → high confidence score |
| `Detect_LoadsKeywordsFromJson_NotHardcoded` | Detector reads from dialects.json, not constants |
| `Detect_JsonConfigMissing_ThrowsMeaningfulError` | Missing dialects.json → clear error message |

```csharp
[Fact]
[Trait("Category", "Unit")]
public void Detect_SqlServerKeywords_ReturnsSqlServer()
{
    // Arrange
    var detector = new DialectDetector(LoadTestDialectsConfig());
    var sqlContent = "SELECT TOP 10 * FROM customers WHERE CreatedAt < GETDATE()";

    // Act
    var result = detector.Detect(sqlContent);

    // Assert
    result.Dialect.Should().Be(Dialect.SqlServer);
    result.Confidence.Should().BeGreaterThan(0.5);
}

[Fact]
[Trait("Category", "Unit")]
public void Detect_AmbiguousFile_DefaultsToSqlServerWithWarning()
{
    var detector = new DialectDetector(LoadTestDialectsConfig());
    var ambiguous = "SELECT * FROM orders";  // no dialect-specific keywords

    var result = detector.Detect(ambiguous);

    result.Dialect.Should().Be(Dialect.SqlServer);
    result.IsAmbiguous.Should().BeTrue();
}
```

---

## Unit Tests — TranslationService

**File:** `Unit/TranslationServiceTests.cs`

The Anthropic client is **mocked** — no real API calls.

| Test | What it verifies |
|---|---|
| `Translate_SqlServerSource_SendsCorrectPrompt` | Prompt includes source dialect and full file content |
| `Translate_ParsesResponse_ExtractsMsSqlSection` | `=== MSSQL ===` section is extracted correctly |
| `Translate_ParsesResponse_ExtractsPostgreSqlSection` | `=== POSTGRESQL ===` section is extracted correctly |
| `Translate_ApiFailsOnce_RetriesAndSucceeds` | First call fails, second succeeds → result returned |
| `Translate_ApiFailsThreeTimes_ThrowsAfterMaxRetries` | All 3 retries fail → TranslationException thrown |
| `Translate_EmptyResponse_ThrowsMeaningfulError` | Claude returns empty → handled gracefully |
| `Translate_MalformedResponse_ThrowsMeaningfulError` | Missing section markers → handled gracefully |

```csharp
[Fact]
[Trait("Category", "Unit")]
public async Task Translate_ApiFailsOnce_RetriesAndSucceeds()
{
    // Arrange — mock fails first call, succeeds second
    var mockClient = new Mock<IAnthropicClient>();
    mockClient
        .SetupSequence(c => c.SendMessageAsync(It.IsAny<MessageRequest>()))
        .ThrowsAsync(new HttpRequestException("timeout"))
        .ReturnsAsync(FakeValidResponse());

    var service = new TranslationService(mockClient.Object, config);

    // Act
    var result = await service.TranslateAsync(sampleSqlFile);

    // Assert
    result.MsSqlVersion.Should().NotBeNullOrEmpty();
    result.PostgreSqlVersion.Should().NotBeNullOrEmpty();
    mockClient.Verify(c => c.SendMessageAsync(It.IsAny<MessageRequest>()), Times.Exactly(2));
}
```

---

## Unit Tests — OutputWriter

**File:** `Unit/OutputWriterTests.cs`

Use a **temp directory** — write real files but clean up after each test.

| Test | What it verifies |
|---|---|
| `Write_CreatesOutputDirectories_IfMissing` | `/output/mssql/` and `/output/postgresql/` created |
| `Write_FileWrittenToCorrectSubfolder` | MSSQL version in `/mssql/`, PG version in `/postgresql/` |
| `Write_OutputFilename_MatchesInputFilename` | `create_tables.sql` in → `create_tables.sql` out |
| `Write_HeaderCommentIncluded` | Output file starts with generated-by comment |
| `Write_HeaderContainsSourcePath` | Header includes original file path |
| `Write_HeaderContainsSourceDialect` | Header includes detected dialect |
| `Write_DuplicateFilenames_HandledGracefully` | Two inputs named `create_tables.sql` → not overwritten |

---

## Integration Tests — Real Claude API

**File:** `Integration/TranslationIntegrationTests.cs`

These call the **real** Anthropic API. Run manually, not in CI.

| Test | What it verifies |
|---|---|
| `Translate_RealSqlServerFile_ProducesValidPostgreSql` | Real API call — output contains LIMIT, not TOP |
| `Translate_RealPostgreSqlFile_ProducesValidMsSql` | Real API call — output contains TOP, not LIMIT |
| `Translate_StoredProcedure_FullyRestructured` | Procedure body correctly converted |
| `Translate_CreateTable_DataTypesConverted` | NVARCHAR→VARCHAR, BIT→BOOLEAN, IDENTITY→SERIAL |

```csharp
[Fact]
[Trait("Category", "Integration")]
public async Task Translate_RealSqlServerFile_ProducesValidPostgreSql()
{
    // Requires ANTHROPIC_API_KEY env variable set
    var service = new TranslationService(new AnthropicClient(apiKey), config);
    var sqlFile = LoadTestFile("mssql/create_table.sql");

    var result = await service.TranslateAsync(sqlFile);

    result.PostgreSqlVersion.Should().Contain("SERIAL").Or.Contain("GENERATED ALWAYS");
    result.PostgreSqlVersion.Should().NotContain("IDENTITY");
    result.PostgreSqlVersion.Should().NotContain("NVARCHAR");
    result.MsSqlVersion.Should().Contain("IDENTITY");
    result.MsSqlVersion.Should().NotContain("SERIAL");
}
```

---

## E2E Tests — Full Pipeline

**File:** `E2E/EndToEndTests.cs`

| Test | What it verifies |
|---|---|
| `FullPipeline_InputFolder_ProducesOutputFolders` | Both output folders created with correct files |
| `FullPipeline_50Files_CompletesWithinTimeout` | Batch API handles scale — completes under 3 min |
| `DryRun_NoOutputFilesCreated` | `--dry-run` lists files but writes nothing |

---

## Test Data Files

**`TestData/mssql/simple_select.sql`**
```sql
SELECT TOP 10 c.customer_id, c.full_name, ISNULL(c.phone, 'N/A') AS phone
FROM dbo.customer c
WHERE c.created_at < GETDATE()
ORDER BY c.customer_id DESC
```

**`TestData/postgresql/simple_select.sql`**
```sql
SELECT c.customer_id, c.full_name, COALESCE(c.phone, 'N/A') AS phone
FROM customer c
WHERE c.created_at < NOW()
ORDER BY c.customer_id DESC
LIMIT 10
```

**`TestData/mssql/create_table.sql`**
```sql
CREATE TABLE dbo.policy (
    policy_id    INT          IDENTITY(1,1) PRIMARY KEY,
    policy_number NVARCHAR(50) NOT NULL UNIQUE,
    customer_id  INT          NOT NULL,
    premium_amount DECIMAL(18,2) NOT NULL,
    is_active    BIT          NOT NULL DEFAULT 1,
    created_at   DATETIME2    NOT NULL DEFAULT GETDATE()
);
```

**`TestData/postgresql/create_table.sql`**
```sql
CREATE TABLE policy (
    policy_id     SERIAL         PRIMARY KEY,
    policy_number VARCHAR(50)    NOT NULL UNIQUE,
    customer_id   INTEGER        NOT NULL,
    premium_amount NUMERIC(18,2) NOT NULL,
    is_active     BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP      NOT NULL DEFAULT NOW()
);
```

---

## Running Tests

```bash
# Run only unit tests (fast — use during development)
dotnet test --filter "Category=Unit"

# Run unit + integration (needs ANTHROPIC_API_KEY set)
dotnet test --filter "Category=Unit|Category=Integration"

# Run everything including E2E
dotnet test

# Run with coverage report
dotnet test --collect:"XPlat Code Coverage"

# View coverage (after installing reportgenerator tool)
reportgenerator -reports:coverage.xml -targetdir:coverage-report -reporttypes:Html
```

---

## Target Coverage

| Component | Target |
|---|---|
| FileScanner | 90%+ |
| DialectDetector | 95%+ (core logic — must be accurate) |
| TranslationService | 85%+ |
| OutputWriter | 90%+ |
| Overall | 85%+ |

---

## Test Results Summary (example output)

```
Test run for SqlDialectTranslator.Tests
──────────────────────────────────────
Passed: 34
Failed:  0
Skipped: 0
──────────────────────────────────────
Category breakdown:
  Unit        : 28 passed
  Integration :  4 passed
  E2E         :  2 passed

Coverage: 87.3%

Build time: 2.4s | Test time: 8.1s
```
