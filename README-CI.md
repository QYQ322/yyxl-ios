# 一条命令推上 CI 出 iPhone 安装包（Windows）

> 本仓库已 `git init` + 首次 commit 完成，只差推到你的 GitHub。
> 前提：有 GitHub 账号（免费即可，macOS runner 每月免费额度够跑 20+ 次）。

## 方式 A：命令行（推荐，1 分钟）

1. 打开 https://github.com/new → Repository name 填 `yyxl-ios` → **Private 或 Public 都行** → Create repository（**不要**勾选 Add README/.gitignore）
2. 生成 token：https://github.com/settings/tokens → **Generate new token (classic)** → 勾 `repo` + `workflow` → 生成后复制（只显示一次）
3. 在本目录执行：

```powershell
cd C:\Users\ZYQ\Documents\deepseek-harness\default-workspace\apk2ipa\ios-port
.\push-to-ci.ps1 -User 你的GitHub用户名 -Repo yyxl-ios -Token ghp_xxxxxxxxxxxx
```

脚本会：推代码 → 触发 `build-ipa` workflow → 打开 Actions 页面。

4. Actions 页面等 3~5 分钟 → 页面底部 **Artifacts** → 下载 `YingXingRoute-unsigned.zip` → 解压得 `YingXingRoute-unsigned.ipa`
5. 爱思助手 → 工具箱 → IPA 签名 → 签这个 ipa → 安装

## 方式 B：纯网页（不想给 token 时，2 分钟）

1. 新建空仓库（同上）
2. GitHub 仓库页 → **Add file → Upload files** → 把本目录（`ios-port`）里的
   `YingXingRoute/`、`YingXingRoute.xcodeproj/`、`build-ipa-macos.sh`、`project.yml`、`.gitignore`
   全部拖进去 → Commit
3. 仓库页 → **Actions** → 若提示没有 workflow：点 **set up a workflow yourself** →
   把本目录 `.github/workflows/build-ipa.yml` 的内容整段粘贴 → Commit changes
4. 点 **Run workflow** → 等 4 分钟 → 下载 Artifact

## 出包之后

```
unsigned ipa  ->  爱思助手 工具箱 → IPA 签名（Apple ID 用 App 专用密码）
              ->  安装到设备
              ->  手机 设置 → 通用 → VPN与设备管理 → 信任
              ->  首次启动必须联网
```

免费 Apple ID 限制：7 天有效期 / 同时 3 个 App / NFC 不可用（workflow 已默认 `NO_NFC=1`）。
有付费开发者账号（¥688/年）可去掉 `NO_NFC=1` 并拿 1 年有效期 + NFC 扫描。

## 不想用 GitHub 的两条替代

```bash
# 有任意一台 Mac（含借用的）
cd ios-port && chmod +x build-ipa-macos.sh
MODE=unsigned NO_NFC=1 ./build-ipa-macos.sh     # 产物在 build/ipa/
```

云 Mac 按小时租（MacinCloud / MacStadium），远程桌面里跑上面两条命令，同样 5 分钟出包。
