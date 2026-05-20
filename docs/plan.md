# Plan: Build PS.DCU PowerShell Module

Scaffold a new module that wraps `dcu-cli.exe` (Dell Command Update CLI) following the team's advanced-functions standard, with the same root-level repo layout and psake-driven staging build used by [`johnsarie27/SecurityTools`](https://github.com/johnsarie27/SecurityTools). First release covers discovery, scanning, applying updates, configuration, install history, and report generation/parsing. Idiomatic PowerShell wrapper: typed params, `ValidateSet`, parsed `[PSCustomObject]` output. Targets PS 5.1 minimum with PS 7.4+ enhancements where they apply.

## Repo layout (root-level)

The manifest and root module live at the repo root; everything else sits as a sibling. Only `Public/`, `Private/`, `README.md`, `.psd1`, and `.psm1` are copied into `Staging/PS.DCU/` and zipped to `Artifacts/PS.DCU-v<version>.zip` — `Build/`, `Tests/`, `Documentation/`, `docs/`, `.github/`, `.vscode/` are excluded from the published artifact.

```
PS.DCU/                           (repo root)
├── PS.DCU.psd1
├── PS.DCU.psm1
├── Public/
├── Private/
├── Tests/Common/
├── Build/
├── Documentation/
├── docs/                         (planning + design notes, not shipped)
├── .github/                      (CI later)
├── .vscode/
├── CONTRIBUTING.md
├── README.md
└── LICENSE
```

## Phase 1 — Module scaffold (no dependencies)

1. Create `PS.DCU.psd1` at repo root.
   - `PowerShellVersion = '5.1'`, new GUID, `Author = 'johnsarie27'`, `ProjectUri = 'https://github.com/johnsarie27/PS.DCU'`, semantic version `0.1.0`.
   - Explicit `FunctionsToExport` listing all 8 public functions; `CmdletsToExport = @()`, `AliasesToExport = @()`, `VariablesToExport = @()`.
2. Create `PS.DCU.psm1` at repo root that dot-sources `Public/*.ps1` and `Private/*.ps1`, declares module constants, calls `Export-ModuleMember -Variable * -Alias *`.
3. Create `Public/`, `Private/`, `Documentation/`, `Tests/Common/`, `Build/` directories at repo root.
4. Add `CONTRIBUTING.md`; expand `README.md` with install/usage stub.
5. Add `.gitignore` entries for `Staging/`, `Artifacts/`.

## Phase 2 — Build pipeline (parallel with Phase 1)

Mirror the SecurityTools `Build/` setup so contributors run the same commands.

1. `Build/depend.psd1` — PSDepend manifest pinning `Pester = '5.7.1'`, `psake = '4.9.1'`, `PSScriptAnalyzer = '1.24.0'`. `PSDependOptions` target `CurrentUser`, repo `PSGallery`, `SkipPublisherCheck = $true`.
2. `Build/build.ps1` — entrypoint.
   - Params: `[ValidateSet] $TaskList = 'Default'` (allowed: `Default, Init, Setup, CombineFunctionsAndStage, ImportStagingModule, Analyze, Test, CreateBuildArtifact, Cleanup`), `[Hashtable] $Parameters`, `[Hashtable] $Properties`, `[Switch] $ResolveDependency`.
   - When `-ResolveDependency` is set, bootstrap NuGet provider, install PSDepend if missing, then `Invoke-PSDepend` against `depend.psd1`.
   - Set `$env:BHProjectPath`, `$env:BHProjectName`, `$env:BHPSModuleManifest` from the root manifest.
   - Invoke `psake` with `Build/build.psake.ps1`. Exit with `[int](-not $psake.build_success)`.
3. `Build/build.psake.ps1` — task definitions.
   - **Properties**: `$ProjectRoot`, `$ArtifactFolder = $ProjectRoot/Artifacts`, `$StagingFolder = $ProjectRoot/Staging`, `$StagingModulePath = $StagingFolder/$env:BHProjectName`, `$StagingModuleManifestPath = $StagingModulePath/$env:BHProjectName.psd1`, `$TestScripts = Get-ChildItem "$ProjectRoot/Tests/*/*Tests.ps1"`, `$ScriptAnalyzerSettingsPath = $ProjectRoot/Build/PSScriptAnalyzerSettings.psd1`, `$ScriptAnalysisFailBuildOnSeverityLevel = 'Error'`.
   - **`Default`** depends on `Test`.
   - **`Init`** — print `$env:BH*` and PowerShell version.
   - **`Setup`** — remove and recreate `Artifacts/` and `Staging/`.
   - **`CombineFunctionsAndStage`** — recreate `$StagingModulePath`; copy only:
     - `Public/`, `Private/`, `README.md`, `PS.DCU.psd1`, `PS.DCU.psm1`
     into `$StagingModulePath`. **`Build/`, `Tests/`, `Documentation/`, `docs/`, `.github/`, `.vscode/`** are explicitly excluded.
   - **`ImportStagingModule`** — `Remove-Module` if loaded, then `Import-Module $StagingModulePath -Force`.
   - **`Analyze`** — run `Invoke-ScriptAnalyzer -Path $StagingModulePath -Recurse -Settings $ScriptAnalyzerSettingsPath`; fail on `Error` per `$ScriptAnalysisFailBuildOnSeverityLevel`.
   - **`Test`** — build a `New-PesterConfiguration` with `TestResult.OutputFormat = 'NUnitXML'`, `OutputPath = $ArtifactFolder/Test-Unit_<timestamp>.xml`, `Run.Path = $TestScripts`; fail build on `FailedCount -gt 0`.
   - **`CreateBuildArtifact`** — read version from `Test-ModuleManifest $StagingModuleManifestPath`; `Compress-Archive -Path "$StagingFolder/*" -DestinationPath "$ArtifactFolder/PS.DCU-v<version>.zip"`.
   - **`Cleanup`** — remove `Staging/` and `Artifacts/`.
4. `Build/PSScriptAnalyzerSettings.psd1` — base rules; excluded rules `PSAvoidGlobalVars` (module constants), `PSAvoidUsingConvertToSecureStringWithPlainText` (per skill).

## Phase 3 — Standard tests

Land in `Tests/Common/` so the psake `Tests/*/*Tests.ps1` glob picks them up.

1. `Tests/Common/Manifest.Tests.ps1` — `Test-ModuleManifest` passes; required fields populated; `FunctionsToExport` matches `Public/*.ps1` filenames; no wildcards.
2. `Tests/Common/Help.Tests.ps1` — every exported function has `.SYNOPSIS`, `.DESCRIPTION`, at least one `.EXAMPLE`, and a `.PARAMETER` entry per parameter; mandatory-flag alignment.
3. `Tests/Common/Meta.Tests.ps1` — every `.ps1`/`.psm1`/`.psd1` is UTF-8 without BOM and contains no tab characters.

## Phase 4 — Private helpers

Single source of truth for invoking the CLI and parsing results. All `Public/*` functions call into these.

1. `Private/Get-DCUExecutable.ps1` — locates `dcu-cli.exe` (checks `Program Files\Dell\CommandUpdate\` and `Program Files (x86)\...`); returns `[System.IO.FileInfo]`; caches in a module-scope variable; `Write-Error -ErrorAction Stop` if not installed.
2. `Private/Invoke-DCU.ps1` — internal launcher. Params: `[System.String[]] $Arguments`, `[System.Management.Automation.SwitchParameter] $RequireElevation`. Runs the CLI via `Start-Process -Wait -PassThru -NoNewWindow` with redirected stdout/stderr to temp files; returns `[PSCustomObject]` with `ExitCode`, `StdOut`, `StdErr`, `Arguments`, `Duration`. Maps known exit codes (0 success, 1 reboot required, 5 reboot pending, 500 no updates, 1000+ error codes) into a friendly `Status` string.
3. `Private/Test-DCUElevation.ps1` — returns `[System.Boolean]`; used by mutating cmdlets' `Begin{}` to assert admin.
4. `Private/ConvertFrom-DCUReport.ps1` — parses DCU XML report (default location `%ProgramData%\Dell\CommandUpdate\Reports\`) into `[PSCustomObject]` collection with fields like `Name`, `Release`, `Category`, `Severity`, `Type`, `Reboot`, `InstalledDateTime`, `ReleaseDate`, `Size`.
5. Module constants in `PS.DCU.psm1`: `$dcu_default_install_paths`, `$dcu_report_path`, `$dcu_exit_codes` (hashtable).

## Phase 5 — Public functions (parallel; each in own file under `Public/`)

Each function: `[CmdletBinding()]`, full comment-based help, full .NET type names, splatting, single-quote + `-f`, `Begin{}` verbose start, `Process{}` logic, validation attributes. Mutating verbs add `SupportsShouldProcess` + `ConfirmImpact`.

| # | Function | ConfirmImpact | Purpose / key params |
|---|---|---|---|
| 1 | `Get-DCUVersion` | n/a | Returns `[PSCustomObject]` with `ProductVersion`, `ExecutablePath`, `FileVersion`. Calls `Get-DCUExecutable`. |
| 2 | `Get-DCUUpdate` | n/a | Wraps `/scan -report=<tempDir>`. Params: `[System.String] $Name` (filter), `[ValidateSet] $UpdateType` (bios/firmware/driver/application/utility/others), `[ValidateSet] $Severity` (security/critical/recommended/optional), `[ValidateSet] $DeviceCategory` (audio/video/network/storage/input/chipset/other). Returns parsed update objects via `ConvertFrom-DCUReport`. |
| 3 | `Install-DCUUpdate` | High | Wraps `/applyUpdates`. Params: `$Name` (accepts `[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]` so `Get-DCUUpdate | Install-DCUUpdate` works — names accumulated in `Process{}`, single CLI invocation in `End{}`), `$UpdateType`, `$Severity`, `$DeviceCategory`, `[Switch] $Reboot`, `[Switch] $AutoSuspendBitLocker`, `[ValidateSet('Enable','Disable')] $ForceUpdate`. Elevation required; `ShouldProcess` guard. Returns exit-code object. |
| 4 | `Set-DCUConfiguration` | Medium | Wraps `/configure`. Params: schedule weekly/monthly/manual, `[ValidateSet] $UpdatesNotification`, `$ImportSettings` (path), `$ExportSettings` (path), `$AdvancedDriverRestore`, `$SystemRestartDeferral`, `$DeferralRestartInterval`, `$DeferralInstallInterval`, `$LockSettings`. Elevation required. |
| 5 | `Get-DCUConfiguration` | n/a | Wraps `/configure -exportSettings=<tempfile>`, parses XML into `[PSCustomObject]`. |
| 6 | `Get-DCUDriverHistory` | n/a | Wraps `/driverInstall -report=<tempDir>` (or parses install-history report); returns inventory of previously installed updates. |
| 7 | `Invoke-DCUScan` | n/a | Thin wrapper around `/scan`. Param: `[System.String] $OutputPath` (optional file/directory for the report; defaults to a temp path). Returns `[PSCustomObject]` with `ExitCode`, `Status`, `ReportPath`, `Duration`, `Arguments`. |
| 8 | `Get-DCUReport` | n/a | Reads existing report XML files from `%ProgramData%\Dell\CommandUpdate\Reports\` (or `-Path`); returns parsed objects. |

## Phase 6 — Verification

1. `Import-Module ./PS.DCU.psd1 -Force` succeeds; `Get-Command -Module PS.DCU` lists exactly the 8 functions in `FunctionsToExport`.
2. `./Build/build.ps1 -ResolveDependency -TaskList Analyze` — zero `Error` severity findings.
3. `./Build/build.ps1 -ResolveDependency -TaskList Test` — `Help`, `Manifest`, `Meta` tests pass.
4. `./Build/build.ps1 -TaskList CreateBuildArtifact` — produces `Artifacts/PS.DCU-v0.1.0.zip` containing **only** `PS.DCU/{PS.DCU.psd1, PS.DCU.psm1, Public/, Private/, README.md}` and **no** `Build/`, `Tests/`, `docs/`, `.github/`, `.vscode/`.
5. Manual smoke on a Dell host with DCU installed: `Get-DCUVersion`, `Get-DCUUpdate -Severity security`, `Get-DCUConfiguration` return parsed objects.
6. Manual smoke on a non-elevated session: `Install-DCUUpdate -WhatIf` emits a `ShouldProcess` preview; without `-WhatIf` it errors via `Test-DCUElevation`.
7. Manual smoke on a non-Dell host (or with DCU removed): `Get-DCUVersion` returns a clear `Write-Error` indicating `dcu-cli.exe` was not found.

## Relevant files (to be created)

- `PS.DCU.psd1` — manifest at repo root, lists 8 exported functions
- `PS.DCU.psm1` — root module, dot-sources Public/Private, declares constants
- `Public/Get-DCUVersion.ps1`
- `Public/Get-DCUUpdate.ps1`
- `Public/Install-DCUUpdate.ps1`
- `Public/Set-DCUConfiguration.ps1`
- `Public/Get-DCUConfiguration.ps1`
- `Public/Get-DCUDriverHistory.ps1`
- `Public/Invoke-DCUScan.ps1`
- `Public/Get-DCUReport.ps1`
- `Private/Get-DCUExecutable.ps1`
- `Private/Invoke-DCU.ps1`
- `Private/Test-DCUElevation.ps1`
- `Private/ConvertFrom-DCUReport.ps1`
- `Build/build.ps1`
- `Build/build.psake.ps1`
- `Build/depend.psd1`
- `Build/PSScriptAnalyzerSettings.psd1`
- `Tests/Common/Help.Tests.ps1`
- `Tests/Common/Manifest.Tests.ps1`
- `Tests/Common/Meta.Tests.ps1`
- `.gitignore` (add `Staging/`, `Artifacts/`)
- `.github/workflows/ci.yml` — GitHub Actions: on push/PR run `./Build/build.ps1 -ResolveDependency -TaskList Analyze,Test` on `windows-latest`; upload `Artifacts/Test-Unit_*.xml` as a workflow artifact
- `.github/dependabot.yml` — weekly GitHub Actions updates (matches SecurityTools)
- `.devcontainer/devcontainer.json` + `Dockerfile` — PowerShell 7.4 base image, pre-installs PSDepend; `postCreateCommand` runs `./Build/build.ps1 -ResolveDependency -TaskList Init`
- `CONTRIBUTING.md`, updated `README.md`

## Decisions

- **Layout**: root-level (manifest/psm1 at repo root, no `PS.DCU/` subfolder). Matches `SecurityTools`. Staging step assembles a clean `Staging/PS.DCU/` for analysis, import, and packaging.
- **Build**: psake task pipeline `Init → Setup → CombineFunctionsAndStage → ImportStagingModule → Analyze → Test → CreateBuildArtifact → Cleanup`. Staged artifact contains only shipping files.
- **Scope (confirmed)**: discovery, scan, apply, configure, history, report parsing. Out of scope for v0.1.0: BitLocker orchestration beyond passing `-autoSuspendBitLocker`, custom catalog management, scheduled-task creation.
- **Style**: idiomatic — typed params, `ValidateSet`, parsed `[PSCustomObject]` output.
- **PS target**: 5.1 minimum; module doesn't handle secrets, so no `Clean {}` block needed.
- **Elevation**: detected in `Begin{}` for `Install-DCUUpdate` and `Set-DCUConfiguration`; non-mutating cmdlets do not require admin.
- **Pipeline input**: `Install-DCUUpdate` accepts update names from `Get-DCUUpdate` via the pipeline; `Process{}` accumulates into a `[List[String]]`, `End{}` makes one CLI call.
- **CI**: GitHub Actions workflow on `windows-latest` runs `Analyze` + `Test` on every push and PR; uploads NUnit test results.
- **Dev container**: provided for contributors (PowerShell 7.4 image with PSDepend pre-installed).
- **Author**: `johnsarie27`.
