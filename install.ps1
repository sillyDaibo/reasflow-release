# reasflow Windows 安装器（PowerShell）。
# 用法（用户侧）：
#   irm https://raw.githubusercontent.com/sillyDaibo/reasflow-release/main/install.ps1 | iex
#
# 自定义安装目录：
#   & ([scriptblock]::Create((irm https://.../install.ps1)) -InstallDir "D:\tools\reasflow")
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\reasflow",
    [string]$ReleaseRepo = $(if ($env:RELEASE_REPO) { $env:RELEASE_REPO } else { "sillyDaibo/reasflow-release" })
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"  # 关掉 Invoke-WebRequest 的进度条（拖慢下载）

Write-Host "==> reasflow 安装器 (Windows)"
Write-Host "    目标: $InstallDir"

# ── 经 /releases/latest 重定向取最新 tag（不走 api.github.com，不受限流影响）
function Resolve-LatestTag {
    param([string]$Repo)
    $url = "https://github.com/$Repo/releases/latest"
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.AllowAutoRedirect = $false
    $req.Method = "HEAD"
    try {
        $resp = $req.GetResponse()
        $loc  = $resp.Headers["Location"]
        $resp.Close()
    } catch [System.Net.WebException] {
        # 某些 .NET 实现会对 3xx 抛异常，异常里仍带响应
        if ($_.Exception.Response) {
            $loc = $_.Exception.Response.Headers["Location"]
            $_.Exception.Response.Close()
        } else { throw }
    }
    if (-not $loc) { throw "无法解析最新 tag（$url 未返回 Location）" }
    return ($loc.TrimEnd('/') -split '/')[-1]
}

$tag = Resolve-LatestTag -Repo $ReleaseRepo
Write-Host "    最新版本: $tag"

# ── 当前只提供 x86_64-windows 产物
$asset = "reasflow-$tag-x86_64-windows.zip"
$base  = "https://github.com/$ReleaseRepo/releases/download/$tag"
$zipUrl = "$base/$asset"
Write-Host "    下载: $asset"

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("reasflow-install-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
$zip = Join-Path $tmp $asset
Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing

# ── sha256 校验
try {
    $sums = (Invoke-WebRequest -Uri "$base/sha256sums.txt" -UseBasicParsing).Content
    $expected = ($sums -split "`n" |
        Where-Object { $_ -match "$asset`$" } |
        ForEach-Object { ($_ -split '\s+')[0].Trim() } |
        Select-Object -First 1)
    if ($expected) {
        $actual = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $expected.ToLower()) {
            throw "sha256 校验失败：预期 $expected 实得 $actual"
        }
        Write-Host "    sha256 校验通过"
    } else {
        Write-Host "    (sha256sums 中未找到 $asset，跳过校验)"
    }
} catch {
    Write-Host "    (跳过 sha256 校验：$($_.Exception.Message))"
}

# ── 解压
$staging = Join-Path $tmp "extract"
Expand-Archive -Path $zip -DestinationPath $staging -Force
$exe = Get-ChildItem -Path $staging -Recurse -Filter "reasflow.exe" | Select-Object -First 1
if (-not $exe) { throw "解压后未找到 reasflow.exe" }

# ── 安装
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$dest = Join-Path $InstallDir "reasflow.exe"
Copy-Item -Path $exe.FullName -Destination $dest -Force

# ── 加入用户 PATH（若不在）
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -and ($userPath.Split(';') -contains $InstallDir)) {
    # 已在 PATH
} elseif ($userPath) {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallDir", "User")
    Write-Host "    已将 $InstallDir 加入用户 PATH（新开终端生效）"
} else {
    [Environment]::SetEnvironmentVariable("Path", $InstallDir, "User")
    Write-Host "    已设置用户 PATH = $InstallDir（新开终端生效）"
}

# ── 清理
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==> 已安装：$dest"
Write-Host "==> 验证（新开终端）："
Write-Host "    reasflow --version"
Write-Host "    cd <你的项目>; reasflow init"
