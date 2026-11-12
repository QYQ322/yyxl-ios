<#
  把 ios-port 推到 GitHub 并触发 CI 编译，产出 iPhone 可安装的 unsigned IPA。
  用法:
    .\push-to-ci.ps1 -User <GitHub用户名> -Repo <仓库名> -Token <ghp_xxx>
    可选: -Branch main  -Public
#>
param(
    [Parameter(Mandatory = $true)][string]$User,
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$Branch = 'main',
    [switch]$Public
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$root = $PSScriptRoot
Push-Location $root
try {
    if (-not (Test-Path '.git')) {
        git init -b $Branch | Out-Null
        git config user.name 'xiaohan'
        git config user.email 'xiaohan@local'
        git config core.autocrlf false
        git add -A
        git commit -m 'feat: 莹星路线 iOS 移植 (SwiftUI + MapKit + CoreNFC + 坐标纠偏)' | Out-Null
    }

    $remote = "https://$User`:$Token@github.com/$User/$Repo.git"
    git remote remove origin 2>$null | Out-Null
    git remote add origin $remote
    git branch -M $Branch

    Write-Host "[1/3] 推送 $Branch -> github.com/$User/$Repo" -ForegroundColor Cyan
    git push -u origin $Branch --force

    # 把 origin 换回不含 token 的形式，避免 token 留在 .git/config
    git remote set-url origin "https://github.com/$User/$Repo.git"

    Write-Host "[2/3] 触发 workflow build-ipa" -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    $headers = @{
        Authorization          = "token $Token"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$User/$Repo/actions/runs?per_page=3" -Headers $headers
    $run = $runs.workflow_runs | Select-Object -First 1
    if (-not $run) {
        Write-Host "   未发现 workflow 运行（push 触发的 workflow_dispatch 可能需要等几秒）" -ForegroundColor Yellow
    } else {
        Write-Host "   run #$($run.run_number)  status=$($run.status)" -ForegroundColor Green
    }

    $web = "https://github.com/$User/$Repo/actions"
    Write-Host "[3/3] 打开 Actions 页面: $web" -ForegroundColor Cyan
    Start-Process $web

    Write-Host @"

下一步:
  1) 等 3~5 分钟，Actions 跑完后在页面底部下载 Artifact: YingXingRoute-unsigned.zip
  2) 解压得到 YingXingRoute-unsigned.ipa
  3) 爱思助手 -> 工具箱 -> IPA 签名(Apple ID 用 App 专用密码) -> 安装到设备
  4) 手机 设置 -> 通用 -> VPN与设备管理 -> 信任你的 Apple ID
  5) 首次启动必须联网
"@ -ForegroundColor Green
}
finally { Pop-Location }
