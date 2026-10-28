[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "titstack-install-test-$([guid]::NewGuid())"
$testCodexHome = Join-Path $taskTestRoot 'codex home'
$testAgentsHome = Join-Path $taskTestRoot 'agents home'
$testUserHome = Join-Path $taskTestRoot 'user home'
$testGitHubRepo = Join-Path (Join-Path (Join-Path $testUserHome 'github') 'nested') 'project'
$previousCodexHome = [Environment]::GetEnvironmentVariable('CODEX_HOME', 'Process')
$previousAgentsHome = [Environment]::GetEnvironmentVariable('AGENTS_HOME', 'Process')
$previousPluginTestLog = [Environment]::GetEnvironmentVariable('CODEX_PLUGIN_TEST_LOG', 'Process')
$previousUserProfile = [Environment]::GetEnvironmentVariable('USERPROFILE', 'Process')

function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [bool] $Condition,

        [Parameter(Mandatory)]
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Link {
    param(
        [Parameter(Mandatory)]
        [string] $Target,

        [Parameter(Mandatory)]
        [string] $Source
    )

    $item = Get-Item -LiteralPath $Target -Force
    Assert-Condition ($item.LinkType -eq 'SymbolicLink') "Expected symbolic link: $Target"

    $linkTarget = [string] $item.Target
    if (-not [System.IO.Path]::IsPathRooted($linkTarget)) {
        $linkTarget = Join-Path (Split-Path -Parent $item.FullName) $linkTarget
    }

    $actual = [System.IO.Path]::GetFullPath($linkTarget)
    $expected = [System.IO.Path]::GetFullPath($Source)
    Assert-Condition ($actual -eq $expected) "Unexpected link target: $Target"
}

try {
    New-Item -ItemType Directory -Path $testCodexHome -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testGitHubRepo '.git') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $testCodexHome 'AGENTS.md') -Value 'original global instructions'
    Set-Content -LiteralPath (Join-Path $testCodexHome 'config.toml') -Value @'
# Personal settings and formatting must survive upgrades.
model = "personal-model"
model_reasoning_effort = "low"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

notify = [
  "example-notifier",
  "turn-ended",
]

[plugins."example@personal"]
enabled = true

[marketplaces.personal]
source = "example"

[hooks.state]

[hooks.state."example"]
trusted_hash = "sha256:example"

[notice]
hide_example = true

[mcp_servers.node_repl]
command = "node"

[shell_environment_policy.set]
EXAMPLE_RUNTIME_PATH = "example"

[mcp_servers.photocraft]
command = "my-photocraft-wrapper"
args = ["mcp"]

[mcp_servers.custom]
command = "custom-server"

[projects."/personal/project"]
trust_level = "untrusted"

[features]
fast_mode = true
'@
    $originalConfigHash = (Get-FileHash -LiteralPath (Join-Path $testCodexHome 'config.toml')).Hash

    $env:USERPROFILE = $testUserHome
    $env:CODEX_HOME = $testCodexHome
    $env:AGENTS_HOME = $testAgentsHome
    & (Join-Path $repoRoot 'scripts/install.ps1') | Out-Null

    Assert-Link (Join-Path $testCodexHome 'AGENTS.md') (Join-Path $repoRoot 'codex-home/AGENTS.md')
    $installedConfigPath = Join-Path $testCodexHome 'config.toml'
    $installedConfig = Get-Item -LiteralPath $installedConfigPath -Force
    Assert-Condition ($installedConfig.LinkType -ne 'SymbolicLink') "Expected generated config file: $installedConfigPath"
    Assert-Condition (
        (Get-FileHash -LiteralPath $installedConfigPath).Hash -eq $originalConfigHash
    ) 'Installation changed existing config'
    Assert-Link (Join-Path $testCodexHome 'rules') (Join-Path $repoRoot 'codex-home/rules')
    Assert-Link (Join-Path $testCodexHome 'ollama.config.toml') (Join-Path $repoRoot 'codex-home/ollama.config.toml')
    Assert-Link (Join-Path $testCodexHome 'llamacpp.config.toml') (Join-Path $repoRoot 'codex-home/llamacpp.config.toml')
    Assert-Link (Join-Path $testCodexHome 'photocraft.config.toml') (Join-Path $repoRoot 'codex-home/photocraft.config.toml')

    Get-ChildItem -LiteralPath (Join-Path $repoRoot '.agents/skills') -Directory |
        ForEach-Object {
            Assert-Link (Join-Path (Join-Path $testAgentsHome 'skills') $_.Name) $_.FullName
        }

    $instructionBackups = @(
        Get-ChildItem -LiteralPath (Join-Path $testCodexHome 'backups') -Filter 'AGENTS.md' -File -Recurse
    )
    Assert-Condition ($instructionBackups.Count -eq 1) "Expected one AGENTS.md backup, found $($instructionBackups.Count)"
    $backupContent = Get-Content -LiteralPath $instructionBackups[0].FullName -Raw
    Assert-Condition ($backupContent.Trim() -eq 'original global instructions') 'AGENTS.md backup content changed'
    $configBackups = @(
        Get-ChildItem -LiteralPath (Join-Path $testCodexHome 'backups') -Filter 'config.toml' -File -Recurse
    )
    Assert-Condition ($configBackups.Count -eq 0) "Expected no config.toml backups, found $($configBackups.Count)"

    & (Join-Path $repoRoot 'scripts/install.ps1') | Out-Null
    Assert-Link (Join-Path $testCodexHome 'AGENTS.md') (Join-Path $repoRoot 'codex-home/AGENTS.md')
    $instructionBackups = @(
        Get-ChildItem -LiteralPath (Join-Path $testCodexHome 'backups') -Filter 'AGENTS.md' -File -Recurse
    )
    Assert-Condition ($instructionBackups.Count -eq 1) 'Idempotent install created another AGENTS.md backup'
    $configBackups = @(
        Get-ChildItem -LiteralPath (Join-Path $testCodexHome 'backups') -Filter 'config.toml' -File -Recurse
    )
    Assert-Condition ($configBackups.Count -eq 0) 'Idempotent install created another config.toml backup'
    Assert-Condition (
        (Get-FileHash -LiteralPath $installedConfigPath).Hash -eq $originalConfigHash
    ) 'Repeat installation changed existing config'
    & (Join-Path $repoRoot 'scripts/install.ps1') -DryRun | Out-Null
    Assert-Condition (
        (Get-FileHash -LiteralPath $installedConfigPath).Hash -eq $originalConfigHash
    ) 'Dry-run changed existing config'

    $linkedConfig = Join-Path $taskTestRoot 'personal-config.toml'
    Move-Item -LiteralPath $installedConfigPath -Destination $linkedConfig
    New-Item -ItemType SymbolicLink -Path $installedConfigPath -Target $linkedConfig | Out-Null
    & (Join-Path $repoRoot 'scripts/install.ps1') | Out-Null
    Assert-Link $installedConfigPath $linkedConfig
    Assert-Condition (
        (Get-FileHash -LiteralPath $linkedConfig).Hash -eq $originalConfigHash
    ) 'Installation changed linked config'

    Remove-Item -LiteralPath $installedConfigPath
    New-Item -ItemType HardLink -Path $installedConfigPath -Target $linkedConfig | Out-Null
    & (Join-Path $repoRoot 'scripts/install.ps1') | Out-Null
    Assert-Condition ((Get-Item -LiteralPath $installedConfigPath).LinkType -eq 'HardLink') 'Installation replaced hard-linked config'
    Assert-Condition ((Get-FileHash -LiteralPath $installedConfigPath).Hash -eq $originalConfigHash) 'Installation changed hard-linked config'

    $pluginLog = Join-Path $taskTestRoot 'plugin-calls.log'
    $env:CODEX_PLUGIN_TEST_LOG = $pluginLog
    function global:codex {
        Add-Content -LiteralPath $env:CODEX_PLUGIN_TEST_LOG -Value ($args -join ' ')
        $global:LASTEXITCODE = 0
    }

    $env:CODEX_HOME = Join-Path $taskTestRoot 'plugin codex'
    $env:AGENTS_HOME = Join-Path $taskTestRoot 'plugin agents'
    & (Join-Path $repoRoot 'scripts/install.ps1') -Plugins | Out-Null

    $freshConfigPath = Join-Path $env:CODEX_HOME 'config.toml'
    $freshContent = [System.IO.File]::ReadAllText($freshConfigPath)
    $escapedGitHubRoot = (Join-Path $testUserHome 'github').Replace('\', '\\')
    $escapedGitHubRepo = $testGitHubRepo.Replace('\', '\\')
    Assert-Condition ($freshContent.Contains("[projects.`"$escapedGitHubRoot`"]")) 'Fresh config lacks GitHub root'
    Assert-Condition ($freshContent.Contains("[projects.`"$escapedGitHubRepo`"]")) 'Fresh config lacks nested repository'
    Assert-Condition ($freshContent.Contains('fast_mode = false')) 'Fresh config lacks defaults'
    $freshHash = (Get-FileHash -LiteralPath $freshConfigPath).Hash
    & (Join-Path $repoRoot 'scripts/install.ps1') | Out-Null
    Assert-Condition ((Get-FileHash -LiteralPath $freshConfigPath).Hash -eq $freshHash) 'Repeat installation changed initialized config'

    $expectedPluginCalls = @(
        Get-Content -LiteralPath (Join-Path $repoRoot 'codex-plugins.txt') |
            ForEach-Object { "plugin add $($_.Trim())" }
    )
    $actualPluginCalls = @(Get-Content -LiteralPath $pluginLog)
    Assert-Condition (
        ($actualPluginCalls.Count -eq $expectedPluginCalls.Count) -and
        (($actualPluginCalls -join "`n") -eq ($expectedPluginCalls -join "`n"))
    ) 'Installer did not install the expected Codex plugins'

    $dryRunCodexHome = Join-Path $taskTestRoot 'dry run codex'
    $dryRunAgentsHome = Join-Path $taskTestRoot 'dry run agents'
    $dryRunPluginLog = Join-Path $taskTestRoot 'dry-run-plugin-calls.log'
    $env:CODEX_PLUGIN_TEST_LOG = $dryRunPluginLog
    $env:CODEX_HOME = $dryRunCodexHome
    $env:AGENTS_HOME = $dryRunAgentsHome
    & (Join-Path $repoRoot 'scripts/install.ps1') -DryRun -Plugins | Out-Null
    Assert-Condition (-not (Test-Path -LiteralPath $dryRunCodexHome)) 'Dry-run created CODEX_HOME'
    Assert-Condition (-not (Test-Path -LiteralPath $dryRunAgentsHome)) 'Dry-run created AGENTS_HOME'
    Assert-Condition (-not (Test-Path -LiteralPath $dryRunPluginLog)) 'Dry-run invoked Codex plugin installation'

    foreach ($kind in @('directory', 'dangling')) {
        $invalidHome = Join-Path $taskTestRoot "invalid $kind"
        New-Item -ItemType Directory -Path $invalidHome | Out-Null
        $instructionsPath = Join-Path $invalidHome 'AGENTS.md'
        Set-Content -LiteralPath $instructionsPath -Value 'keep instructions'
        $invalidConfig = Join-Path $invalidHome 'config.toml'
        if ($kind -eq 'directory') {
            New-Item -ItemType Directory -Path $invalidConfig | Out-Null
        }
        else {
            New-Item -ItemType SymbolicLink -Path $invalidConfig -Target (Join-Path $invalidHome 'missing.toml') | Out-Null
        }
        $env:CODEX_HOME = $invalidHome
        $rejected = $false
        try {
            & (Join-Path $repoRoot 'scripts/install.ps1') | Out-Null
        }
        catch {
            $rejected = $_.Exception.Message -like '*config.toml must be a regular file or a link to one*'
        }
        Assert-Condition $rejected "Installer did not reject $kind config target"
        Assert-Condition (
            (Get-Content -LiteralPath $instructionsPath -Raw).Trim() -eq 'keep instructions' -and
            (Get-Item -LiteralPath $instructionsPath).LinkType -ne 'SymbolicLink'
        ) 'Invalid config target changed instructions'
    }

    Write-Output 'installer integration test passed'
}
finally {
    if ($null -eq $previousCodexHome) {
        Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:CODEX_HOME = $previousCodexHome
    }

    if ($null -eq $previousAgentsHome) {
        Remove-Item Env:AGENTS_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:AGENTS_HOME = $previousAgentsHome
    }

    if ($null -eq $previousPluginTestLog) {
        Remove-Item Env:CODEX_PLUGIN_TEST_LOG -ErrorAction SilentlyContinue
    }
    else {
        $env:CODEX_PLUGIN_TEST_LOG = $previousPluginTestLog
    }

    if ($null -eq $previousUserProfile) {
        Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue
    }
    else {
        $env:USERPROFILE = $previousUserProfile
    }

    Remove-Item Function:\codex -ErrorAction SilentlyContinue

    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $normalizedTestRoot = [System.IO.Path]::GetFullPath($taskTestRoot)
    if (
        $normalizedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $normalizedTestRoot).StartsWith('titstack-install-test-')
    ) {
        Remove-Item -LiteralPath $normalizedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
