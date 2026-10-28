[CmdletBinding()]
param(
    [Alias('dry-run')]
    [switch] $DryRun,

    [switch] $Plugins
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$userHome = if ($env:USERPROFILE) {
    $env:USERPROFILE
}
elseif ($env:HOME) {
    $env:HOME
}
else {
    [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
}
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $userHome '.codex' }
$agentsHome = if ($env:AGENTS_HOME) { $env:AGENTS_HOME } else { Join-Path $userHome '.agents' }
$codexHome = [System.IO.Path]::GetFullPath($codexHome)
$agentsHome = [System.IO.Path]::GetFullPath($agentsHome)
$userHome = [System.IO.Path]::GetFullPath($userHome)
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $codexHome "backups/titstack-$timestamp-$PID"
$pluginManifest = Join-Path $repoRoot 'codex-plugins.txt'
$configSource = Join-Path $repoRoot 'codex-home/config.toml'
$githubRoot = Join-Path $userHome 'github'

if ($Plugins) {
    if (-not (Test-Path -LiteralPath $pluginManifest -PathType Leaf)) {
        throw "Plugin manifest does not exist: $pluginManifest"
    }
    if (-not $DryRun -and -not (Get-Command codex -ErrorAction SilentlyContinue)) {
        throw 'Codex is required when using -Plugins.'
    }
}

function Write-DryRunCommand {
    param(
        [Parameter(Mandatory)]
        [string] $Command
    )

    if ($DryRun) {
        Write-Output "+ $Command"
    }
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return
    }

    if ($DryRun) {
        Write-DryRunCommand "New-Item -ItemType Directory -Path '$Path'"
        return
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-NormalizedPath {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Test-LinkTargetsSource {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo] $Item,

        [Parameter(Mandatory)]
        [string] $Source
    )

    if ($Item.LinkType -ne 'SymbolicLink' -or -not $Item.Target) {
        return $false
    }

    $linkTarget = [string] $Item.Target
    if (-not [System.IO.Path]::IsPathRooted($linkTarget)) {
        $linkTarget = Join-Path (Split-Path -Parent $Item.FullName) $linkTarget
    }

    return (Get-NormalizedPath $linkTarget) -eq (Get-NormalizedPath $Source)
}

function Get-BackupPath {
    param(
        [Parameter(Mandatory)]
        [string] $Target
    )

    $normalizedTarget = Get-NormalizedPath $Target
    $normalizedCodexHome = Get-NormalizedPath $codexHome
    $codexPrefix = $normalizedCodexHome + [System.IO.Path]::DirectorySeparatorChar

    if ($normalizedTarget.StartsWith($codexPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $normalizedTarget.Substring($codexPrefix.Length)
        return Join-Path $backupRoot $relative
    }

    $normalizedAgentsHome = Get-NormalizedPath $agentsHome
    $agentsPrefix = $normalizedAgentsHome + [System.IO.Path]::DirectorySeparatorChar
    if ($normalizedTarget.StartsWith($agentsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $normalizedTarget.Substring($agentsPrefix.Length)
        return Join-Path (Join-Path $backupRoot 'agents') $relative
    }

    throw "Managed target is outside CODEX_HOME and AGENTS_HOME: $Target"
}

function Link-ManagedPath {
    param(
        [Parameter(Mandatory)]
        [string] $Source,

        [Parameter(Mandatory)]
        [string] $Target
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Managed source does not exist: $Source"
    }

    Ensure-Directory (Split-Path -Parent $Target)

    $existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    if ($existing -and (Test-LinkTargetsSource -Item $existing -Source $Source)) {
        Write-Output "already linked: $Target"
        return
    }

    if ($existing) {
        $backup = Get-BackupPath $Target
        Ensure-Directory (Split-Path -Parent $backup)

        if ($DryRun) {
            Write-DryRunCommand "Move-Item -LiteralPath '$Target' -Destination '$backup'"
        }
        else {
            Move-Item -LiteralPath $Target -Destination $backup
        }
        Write-Output "backed up: $Target -> $backup"
    }

    if ($DryRun) {
        Write-DryRunCommand "New-Item -ItemType SymbolicLink -Path '$Target' -Target '$Source'"
    }
    else {
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
        }
        catch {
            throw "Failed to create symbolic link '$Target'. Enable Windows Developer Mode or run PowerShell as Administrator. $($_.Exception.Message)"
        }
    }
    Write-Output "linked: $Target -> $Source"
}

function ConvertTo-TomlBasicString {
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )

    if ($Value -match '[\x00-\x1F\x7F]') {
        throw "Project path contains unsupported control characters: $Value"
    }

    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Get-TrustedGitProjects {
    param(
        [Parameter(Mandatory)]
        [string] $Root
    )

    $projects = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    [void] $projects.Add([System.IO.Path]::GetFullPath($Root))

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return @($projects)
    }

    $excludedDirectories = @('.git', 'node_modules', '.venv', 'venv', 'target', 'build', 'dist')
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push([System.IO.Path]::GetFullPath($Root))

    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        if (Test-Path -LiteralPath (Join-Path $directory '.git')) {
            [void] $projects.Add($directory)
        }

        Get-ChildItem -LiteralPath $directory -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -notin $excludedDirectories -and
                -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
            } |
            ForEach-Object { $pending.Push($_.FullName) }
    }

    return @($projects | Sort-Object)
}

function Get-PreservedConfigContent {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    $preservedLines = [System.Collections.Generic.List[string]]::new()
    $preserve = $false

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*\[\[?') {
            $preserve = (
                $line -match '^\s*\[\[?(marketplaces|plugins|notice)(\.|\]\]?)' -or
                $line -match '^\s*\[\[?hooks\.state(\.|\]\]?)' -or
                $line -match '^\s*\[\[?mcp_servers\.node_repl(\.|\]\]?)' -or
                $line -match '^\s*\[\[?shell_environment_policy\.set(\.|\]\]?)'
            )
        }

        if ($preserve) {
            $preservedLines.Add($line)
        }
    }

    if ($preservedLines.Count -eq 0) {
        return ''
    }

    return "`n# Preserved machine-local Codex state.`n$($preservedLines -join "`n")`n"
}

function Get-PreservedTopLevelConfigContent {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    $preservedLines = [System.Collections.Generic.List[string]]::new()
    $captureNotify = $false

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*\[\[?') {
            break
        }

        if ($captureNotify -and $line -match '^\s*[A-Za-z0-9_.-]+\s*=') {
            break
        }

        if ($captureNotify) {
            $preservedLines.Add($line)
            continue
        }

        if ($line -match '^\s*notify\s*=') {
            $captureNotify = $true
            $preservedLines.Add($line)
        }
    }

    while (
        $preservedLines.Count -gt 0 -and
        [string]::IsNullOrWhiteSpace($preservedLines[$preservedLines.Count - 1])
    ) {
        $preservedLines.RemoveAt($preservedLines.Count - 1)
    }

    return $preservedLines -join "`n"
}

function Get-ManagedConfigContent {
    $content = [System.IO.File]::ReadAllText($configSource)
    $preservedTopLevel = Get-PreservedTopLevelConfigContent -Path (Join-Path $codexHome 'config.toml')
    if ($preservedTopLevel) {
        $firstTable = [regex]::Match($content, '(?m)^\s*\[')
        if ($firstTable.Success) {
            $content = $content.Insert($firstTable.Index, "$preservedTopLevel`n`n")
        }
        else {
            $content += "`n$preservedTopLevel`n"
        }
    }
    $content += "`n# Generated by the titstack installer. Rerun it after adding repositories.`n"

    foreach ($project in (Get-TrustedGitProjects -Root $githubRoot)) {
        $escapedProject = ConvertTo-TomlBasicString -Value $project
        $tableHeader = "[projects.`"$escapedProject`"]"
        $tablePattern = "(?m)^$([regex]::Escape($tableHeader))`r?$"

        if ($content -notmatch $tablePattern) {
            $content += "`n$tableHeader`ntrust_level = `"trusted`"`n"
        }
    }

    $content += Get-PreservedConfigContent -Path (Join-Path $codexHome 'config.toml')

    return $content
}

function Install-ManagedConfig {
    param(
        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [string] $Target
    )

    Ensure-Directory (Split-Path -Parent $Target)
    $existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue

    if (
        $existing -and
        $existing.LinkType -ne 'SymbolicLink' -and
        [System.IO.File]::ReadAllText($Target) -ceq $Content
    ) {
        Write-Output "already installed: $Target"
        return
    }

    if ($existing) {
        $backup = Get-BackupPath $Target
        Ensure-Directory (Split-Path -Parent $backup)

        if ($DryRun) {
            Write-DryRunCommand "Move-Item -LiteralPath '$Target' -Destination '$backup'"
        }
        else {
            Move-Item -LiteralPath $Target -Destination $backup
        }
        Write-Output "backed up: $Target -> $backup"
    }

    if ($DryRun) {
        Write-DryRunCommand "Write generated Codex configuration to '$Target'"
    }
    else {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($Target, $Content, $utf8WithoutBom)
    }
    Write-Output "installed: $Target"
}

function Install-RecommendedPlugins {
    Get-Content -LiteralPath $pluginManifest |
        ForEach-Object {
            $plugin = $_.Trim()
            if ($plugin) {
                if ($DryRun) {
                    Write-DryRunCommand "codex plugin add '$plugin'"
                }
                else {
                    $global:LASTEXITCODE = 0
                    & codex plugin add $plugin
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to install Codex plugin: $plugin"
                    }
                }
            }
        }
}

Link-ManagedPath (Join-Path $repoRoot 'codex-home/AGENTS.md') (Join-Path $codexHome 'AGENTS.md')
Install-ManagedConfig -Content (Get-ManagedConfigContent) -Target (Join-Path $codexHome 'config.toml')
Link-ManagedPath (Join-Path $repoRoot 'codex-home/rules') (Join-Path $codexHome 'rules')

Get-ChildItem -LiteralPath (Join-Path $repoRoot 'codex-home') -Filter '*.config.toml' -File |
    ForEach-Object {
        Link-ManagedPath $_.FullName (Join-Path $codexHome $_.Name)
    }

Get-ChildItem -LiteralPath (Join-Path $repoRoot '.agents/skills') -Directory |
    ForEach-Object {
        Link-ManagedPath $_.FullName (Join-Path (Join-Path $agentsHome 'skills') $_.Name)
    }

if ($Plugins) {
    Install-RecommendedPlugins
}

if ($DryRun) {
    Write-Output 'dry run complete'
}
else {
    Write-Output 'installation complete. Restart Codex to reload configuration.'
}
