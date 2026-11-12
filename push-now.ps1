<#
  莹星路线 IPA 云编译 —— 一键推送脚本
  流程: 验证 token -> 自动建仓库(不存在时) -> 推送 -> 清理 token -> 触发并跟踪 Actions -> 取产物信息
  用法: powershell -NoProfile -ExecutionPolicy Bypass -File .\push-now.ps1
        可脚本化: -Token ghp_xxx [-Repo yyxl-ios]
#>
param(
    [string]$Token = '',
    [string]$Repo  = ''
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

$repo_dir = $PSScriptRoot
if (-not $repo_dir) { $repo_dir = (Get-Location).Path }
if (-not (Test-Path (Join-Path $repo_dir '.git'))) { throw "不是 git 仓库: $repo_dir" }
Push-Location $repo_dir

try {
    Say "`n=== 莹星路线 -> IPA：云编译一键推送 ===" Cyan
    Say "仓库目录: $repo_dir"

    # ---------- 1. token ----------
    if ([string]::IsNullOrWhiteSpace($Token)) {
        Say "`n[1/6] 粘贴 GitHub token（不回显），回车确认" Cyan
        Say "      没有就开 https://github.com/settings/tokens 生成，勾 repo + workflow" DarkYellow
        $sec = Read-Host -AsSecureString "Token"
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    else {
        Say "`n[1/6] 使用命令行传入的 token" Cyan
        $token = $Token
    }
    $token = $token.Trim()
    if ($token.Length -lt 20) { throw "token 长度异常（$($token.Length)），疑似没复制全" }

    $H = @{
        Authorization          = "token $token"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent'           = 'yyxl-push'
    }

    # ---------- 2. 验证 token ----------
    Say "`n[2/6] 验证 token" Cyan
    try { $me = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $H -TimeoutSec 20 }
    catch { throw "token 无效或网络不通: $($_.Exception.Message)" }
    $user = $me.login
    Say "      OK 账号: $user" Green

    # ---------- 3. 仓库名 ----------
    if ([string]::IsNullOrWhiteSpace($Repo)) {
        Say "`n[3/6] 仓库名（直接回车用默认 yyxl-ios）" Cyan
        $repo = Read-Host "Repo"
    }
    else {
        Say "`n[3/6] 仓库名: $Repo" Cyan
        $repo = $Repo
    }
    if ([string]::IsNullOrWhiteSpace($repo)) { $repo = 'yyxl-ios' }
    $repo = $repo.Trim()

    # ---------- 4. 建仓库 ----------
    Say "`n[4/6] 检查仓库 $user/$repo" Cyan
    $exists = $true
    try { $null = Invoke-RestMethod -Uri "https://api.github.com/repos/$user/$repo" -Headers $H -TimeoutSec 20 }
    catch { $exists = $false }

    if (-not $exists) {
        $body = @{
            name        = $repo
            private     = $false
            auto_init   = $false
            description = '莹星路线 iOS 移植 (SwiftUI + MapKit + CoreNFC)'
        } | ConvertTo-Json
        try {
            $null = Invoke-RestMethod -Method Post -Uri 'https://api.github.com/user/repos' -Headers $H `
                -Body $body -ContentType 'application/json' -TimeoutSec 30
            Say "      已创建公开仓库（Actions 免费不限分钟）" Green
        }
        catch { throw "创建仓库失败（token 需要 repo 权限）: $($_.Exception.Message)" }
    }
    else { Say "      仓库已存在，直接推" Green }

    # ---------- 5. push ----------
    Say "`n[5/6] 推送代码" Cyan
    git remote remove origin 2>$null | Out-Null
    git remote add origin "https://${user}:${token}@github.com/${user}/${repo}.git"
    git push -u origin main --force
    if ($LASTEXITCODE -ne 0) { throw "git push 失败，退出码 $LASTEXITCODE" }
    git remote set-url origin "https://github.com/$user/$repo.git"
    Say "      推送完成，token 已从 .git/config 清除" Green

    # ---------- 6. 跟踪 ----------
    Say "`n[6/6] 跟踪 Actions 构建（最多 10 分钟，每 15 秒轮询）" Cyan
    $actionsUrl = "https://github.com/$user/$repo/actions"
    Start-Process $actionsUrl
    Start-Sleep -Seconds 5

    $deadline = (Get-Date).AddMinutes(10)
    $run = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$user/$repo/actions/runs?per_page=1" -Headers $H -TimeoutSec 20
            $run = $runs.workflow_runs | Select-Object -First 1
        }
        catch { }
        if ($run) {
            $concl = if ($run.conclusion) { $run.conclusion } else { '-' }
            Say ("      run #{0}  status={1}  conclusion={2}" -f $run.run_number, $run.status, $concl)
            if ($run.status -eq 'completed') { break }
        }
        else { Say "      等待 workflow 被创建…" DarkGray }
        Start-Sleep -Seconds 15
    }

    if ($run -and $run.conclusion -eq 'success') {
        Say "`n构建成功" Green
        try {
            $art = Invoke-RestMethod -Uri "https://api.github.com/repos/$user/$repo/actions/runs/$($run.id)/artifacts" -Headers $H -TimeoutSec 20
            $a = $art.artifacts | Select-Object -First 1
            if ($a) { Say ("产物: {0}  {1:N1} KB" -f $a.name, ($a.size_in_bytes / 1KB)) }
        }
        catch { }
        Say "下载: $($run.html_url)  -> 页面底部 Artifacts" Cyan
        Say "下一步: 解压 YingXingRoute-unsigned.zip 得 .ipa -> 爱思助手 工具箱 -> IPA 签名 -> 安装 -> 手机信任证书" Cyan
        Start-Process $run.html_url
    }
    elseif ($run) {
        Say "`n构建未通过: conclusion=$($run.conclusion)" Red
        Say "看日志: $($run.html_url)" Yellow
        Start-Process $run.html_url
    }
    else {
        Say "`n未取到 run 记录，手工看: $actionsUrl" Yellow
    }
}
finally {
    Pop-Location
}
