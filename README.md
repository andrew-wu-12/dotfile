# Dotfile 專案說明文件

這是一個個人化的開發環境配置專案，包含 Zsh 設定檔和多個自動化腳本，用於簡化日常開發工作流程。

## 目錄結構

```
dotfile/
├── zsh/              # Zsh 配置檔案
│   └── .zshrc       # Zsh 主要配置檔
├── bin/              # 自動化腳本目錄
│   ├── init.sh
│   ├── checkout-ticket.sh
│   ├── checkout-config.sh
│   ├── deploy-console.sh
│   ├── deploy-one.sh
│   └── bi-weekly-report.sh
└── README.md
```

---

## Zsh 配置說明

### Alias 別名介紹

#### 自訂腳本別名

| 別名  | 完整指令                                                     | 說明                    |
| ----- | ------------------------------------------------------------ | ----------------------- |
| `crt` | `~/bin/checkout-ticket.sh`                                   | 快速切換到工作票券分支  |
| `crc` | `~/bin/checkout-config.sh`                                   | 快速切換配置檔分支      |
| `dpc` | `~/bin/deploy-console.sh $(git rev-parse --abbrev-ref HEAD)` | 部署當前分支到 Console  |
| `dpo` | `~/bin/deploy-one.sh $(git rev-parse --abbrev-ref HEAD)`     | 部署當前分支到 Monorepo |
| `bws` | `~/bin/bi-weekly-report.sh`                                  | 生成雙週工作報告        |

**參數說明：**

- `$(git rev-parse --abbrev-ref HEAD)` - 自動取得當前 Git 分支名稱

#### Git 相關別名

| 別名  | 完整指令                                                | 參數     | 說明                           |
| ----- | ------------------------------------------------------- | -------- | ------------------------------ |
| `gp`  | `git push origin $(git rev-parse --abbrev-ref HEAD)`    | 無       | 推送當前分支到遠端             |
| `gpf` | `git push -f origin $(git rev-parse --abbrev-ref HEAD)` | 無       | 強制推送當前分支               |
| `gP`  | `git pull origin $(git rev-parse --abbrev-ref HEAD)`    | 無       | 拉取當前分支最新代碼           |
| `gc`  | `git checkout`                                          | 分支名稱 | 切換分支                       |
| `gco` | `git commit -m`                                         | 提交訊息 | 提交變更                       |
| `gca` | `git commit --amend --no-edit`                          | 無       | 修改最後一次提交（不編輯訊息） |
| `gs`  | `git status`                                            | 無       | 查看 Git 狀態                  |
| `gbc` | `echo "$(git rev-parse --abbrev-ref HEAD)" \| pbcopy`   | 無       | 複製當前分支名稱到剪貼簿       |

**使用範例：**

```bash
# 推送當前分支
gp

# 強制推送當前分支（需謹慎使用）
gpf

# 切換到 develop 分支
gc develop

# 提交變更
gco "修復登入問題"

# 複製分支名稱
gbc
```

#### Yarn 相關別名

| 別名 | 完整指令                                          | 說明                 |
| ---- | ------------------------------------------------- | -------------------- |
| `ys` | `yarn serve`                                      | 啟動開發伺服器       |
| `yt` | `yarn test`                                       | 執行測試             |
| `yb` | `yarn build-local`                                | 本地建置             |
| `yg` | `yarn gen:modal "$(git rev-parse --show-prefix)"` | 在當前目錄生成 Modal |

#### Tmux 相關別名

| 別名  | 完整指令               | 參數     | 說明               |
| ----- | ---------------------- | -------- | ------------------ |
| `tpr` | `tmux select-pane -T`  | 面板標題 | 設定 Tmux 面板標題 |
| `tvs` | `tmux split-window -v` | 無       | 垂直分割視窗       |
| `ths` | `tmux split-window -h` | 無       | 水平分割視窗       |

---

### Export 環境變數介紹

#### 專案路徑變數

| 變數名稱                 | 預設值                                  | 說明                  |
| ------------------------ | --------------------------------------- | --------------------- |
| `MOP_CONFIGURATION_PATH` | `$HOME/project/mop_configuration_files` | MOP 配置檔案專案路徑  |
| `MOP_CONSOLE_PATH`       | `$HOME/project/mop_console`             | MOP Console 專案路徑  |
| `MOP_MONOREPO_PATH`      | `$HOME/project/mop-console-monorepo`    | MOP Monorepo 專案路徑 |
| `MOP_EPOD_PATH`          | `$HOME/project/mop_epod`                | MOP ePOD 專案路徑     |

#### 安全憑證變數

這些變數從 macOS Keychain 安全地讀取，不會直接暴露在環境變數中：

| 變數名稱        | 服務名稱                        | 說明                    |
| --------------- | ------------------------------- | ----------------------- |
| `JENKINS_TOKEN` | `jenkins.morrison.express`      | Jenkins CI/CD 訪問令牌  |
| `JIRA_TOKEN`    | `morrisonexpress.atlassian.net` | Atlassian JIRA API 令牌 |
| `GETDATATOKEN`  | `getdata.morrison.express`      | GetData API 令牌        |

**安全性說明：**

- 令牌儲存在 macOS Keychain 中
- 使用 `security find-generic-password` 命令動態讀取
- 避免明文儲存敏感資訊

#### 其他重要變數

| 變數名稱  | 說明                      |
| --------- | ------------------------- |
| `ZSH`     | Oh My Zsh 安裝路徑        |
| `NVM_DIR` | Node Version Manager 目錄 |

---

## Bin 目錄腳本介紹

### 1. init.sh - 環境初始化腳本

**功能說明：**
自動化設置開發環境，包含套件安裝、配置檔案連結、路徑驗證等。

**使用的環境變數：**

- `HOME` - 使用者家目錄
- `USER` - 當前使用者名稱
- `MOP_*_PATH` - 各專案路徑變數

**執行動作：**

1. **套件安裝** - 檢查並安裝必要工具：

   - `jq` - JSON 解析工具
   - `gh` - GitHub CLI
   - `curl` - 資料傳輸工具
   - `git` - 版本控制系統
   - `stow` - 符號連結管理工具
   - `nvm` - Node.js 版本管理器
   - `zoxide` - 智慧目錄跳轉工具

2. **Oh My Zsh 安裝** - 安裝 Zsh 框架

3. **配置檔案連結** - 使用 GNU Stow 建立符號連結：

   - 連結 `.zshrc` 到家目錄
   - 連結 `bin/` 目錄下的腳本到 `~/bin`

4. **路徑檢查與修正** - 驗證專案路徑：

   - 檢查 `MOP_*_PATH` 變數指向的目錄是否存在
   - 提供互動式修正選項
   - 自動建立不存在的目錄

5. **憑證設定** - 安全地儲存 API 令牌：

   - 將令牌儲存到 macOS Keychain
   - 在 `.zshrc` 中設定安全的憑證讀取方式
   - 支援三個服務：Jenkins、JIRA、GetData

6. **Git 專案複製** - 自動複製專案儲存庫：
   - GitHub 認證
   - 檢查專案是否已存在
   - 複製到配置的路徑

**使用案例：**

```bash
# 首次設定環境
cd ~/dotfile/bin
./init.sh

# 腳本會引導你完成：
# 1. 安裝缺少的套件
# 2. 設定 Oh My Zsh
# 3. 連結配置檔案
# 4. 驗證並建立專案目錄
# 5. 輸入 API 令牌（安全儲存到 Keychain）
# 6. 複製 Git 專案（如果需要）
```

---

### 2. checkout-ticket.sh - 工作票券分支切換

**參數：**

- `$1` - DEV 票券編號（例如：`MOP-1234`）

**使用的環境變數：**

- `JIRA_TOKEN` - JIRA API 認證令牌

**執行動作：**

1. 從 JIRA API 取得票券資訊（摘要、優先級等）
2. 根據票券編號自動建立分支名稱
3. 針對不同環境建立對應分支：
   - `feature/MOP-1234` - 開發環境
   - `uat/MOP-1234` - UAT 環境
   - `hotfix/MOP-1234` - 修補環境
4. 自動生成 Pull Request 內容
5. 建立 GitHub Pull Request

**使用案例：**

```bash
# 使用別名切換到票券分支
crt MOP-1234

# 或直接執行腳本
~/bin/checkout-ticket.sh MOP-1234

# 輸出示例：
# Creating branches for ticket MOP-1234...
# Branch feature/MOP-1234 created
# Creating PR for dev environment...
# PR created: https://github.com/...
```

---

### 3. checkout-config.sh - 配置檔分支切換

**參數：**

- `$1` - 票券編號

**使用的環境變數：**

- `MOP_CONFIGURATION_PATH` - 配置檔專案路徑
- `JIRA_TOKEN` - JIRA API 認證令牌

**執行動作：**

1. 切換到配置檔專案目錄
2. 暫存當前變更（使用 `git stash`）
3. 從 JIRA 取得票券摘要
4. 為每個環境建立配置分支：
   - `feature/MOP-1234-dev` - 開發環境配置
   - `feature/MOP-1234-uat` - UAT 環境配置
   - `feature/MOP-1234-prod` - 生產環境配置
5. 生成對應的 PR 標題和內容

**使用案例：**

```bash
# 使用別名
crc MOP-1234

# 直接執行
~/bin/checkout-config.sh MOP-1234

# 腳本會：
# 1. 保存當前工作
# 2. 為 dev、uat、prod 建立分支
# 3. 準備好讓你修改各環境的配置
```

---

### 4. deploy-console.sh - Console 專案部署

**參數：**

- `$1` - 分支名稱（自動傳入當前分支）
- `$2` - 覆蓋環境（選填，可選值：`feature` 或 `uat`）

**使用的環境變數：**

- `MOP_CONSOLE_PATH` - Console 專案路徑
- `JENKINS_TOKEN` - Jenkins 認證令牌

**執行動作：**

1. 解析分支名稱取得環境資訊
2. 根據環境選擇對應的 Jenkins Job：
   - Feature 環境：`mop_console_bulild_by_feature`
   - UAT/Hotfix 環境：`mop_console_bulild_by_epic_or_hotfix`
3. 呼叫 Jenkins API 觸發建置
4. 傳遞分支和票券資訊給 Jenkins

**使用案例：**

```bash
# 使用別名（自動使用當前分支）
dpc

# 或指定分支
~/bin/deploy-console.sh feature/MOP-1234

# 覆蓋環境部署
~/bin/deploy-console.sh feature/MOP-1234 uat

# 輸出示例：
# Deploying branch: feature/MOP-1234
# Environment: feature
# Triggering Jenkins job...
# Deploy Success!
```

---

### 5. deploy-one.sh - Monorepo 專案部署

**參數：**

- `$1` - 分支名稱（自動傳入當前分支）

**使用的環境變數：**

- `JENKINS_TOKEN` - Jenkins 認證令牌

**執行動作：**

1. 同時觸發多個 Jenkins Job：
   - `mop_console_monorepo_dev` - 開發環境
   - `mop_console_monorepo_uat` - UAT 環境
2. 使用 curl 呼叫 Jenkins buildWithParameters API
3. 傳遞分支參數給 Jenkins

**使用案例：**

```bash
# 使用別名（部署當前分支到兩個環境）
dpo

# 或指定分支
~/bin/deploy-one.sh feature/MOP-1234

# 輸出示例：
# Processing Jenkins Job: mop_console_monorepo_uat
# Processing Jenkins Job: mop_console_monorepo_dev
# Deploy Success!
```

---

### 6. bi-weekly-report.sh - 雙週工作報告生成

**參數：**
無（自動計算日期範圍）

**使用的環境變數：**

- `MOP_MONOREPO_PATH` - Monorepo 專案路徑

**執行動作：**

1. 計算日期範圍（過去 14 天到今天）
2. 使用 GitHub CLI (`gh`) 取得 PR 清單：
   - 進行中的 PR（狀態為 open）
   - 已完成的 PR（在日期範圍內關閉）
3. 過濾指派給當前使用者的 PR
4. 提取 PR 資訊（標題、內容、URL）
5. 組合成 JSON 格式
6. 自動複製到剪貼簿

**使用案例：**

```bash
# 使用別名生成報告
bws

# 或直接執行
~/bin/bi-weekly-report.sh

# 輸出示例：
# Start Date: 2026-01-06
# End Date: 2026-01-20
# Report copied to clipboard.

# 剪貼簿內容（JSON 格式）：
# {
#   "on_going": [
#     {
#       "title": "[DEV] MOP-1234: 新增登入功能",
#       "body": "...",
#       "url": "https://github.com/..."
#     }
#   ],
#   "closed": [
#     {
#       "title": "[UAT] MOP-1233: 修復支付問題",
#       "body": "...",
#       "url": "https://github.com/..."
#     }
#   ]
# }
```

---

## 安裝與使用

### 快速開始

1. **克隆專案**

   ```bash
   git clone https://github.com/andrew-wu-12/dotfile.git ~/dotfile
   ```

2. **執行初始化**

   ```bash
   cd ~/dotfile/bin
   chmod +x *.sh
   ./init.sh
   ```

3. **重新載入 Shell**
   ```bash
   source ~/.zshrc
   ```

### 手動設定憑證

如果需要更新 API 令牌：

```bash
# 儲存到 Keychain
security add-generic-password -a "$USER" -s "jenkins.morrison.express" -w "your-token-here" -U

# 驗證儲存
security find-generic-password -a "$USER" -s "jenkins.morrison.express" -w
```

---

## 常見問題

### Q: 腳本執行權限問題

```bash
# 賦予所有腳本執行權限
chmod +x ~/bin/*.sh
```

### Q: 找不到命令

確保 `~/bin` 已加入 PATH：

```bash
export PATH="$HOME/bin:$PATH"
```

### Q: Keychain 存取問題

首次使用可能需要授權存取 Keychain，點選「允許」即可。

### Q: Oh My Zsh 錯誤

如果在執行腳本時出現 Oh My Zsh 錯誤，這是正常的，因為腳本會選擇性載入環境變數而不初始化完整的 Oh My Zsh。

---

## 依賴項目

- macOS（使用 Keychain 功能）
- Homebrew
- Git
- GitHub CLI (`gh`)
- jq（JSON 處理）
- curl
- Node.js（透過 nvm 管理）

---

## 授權

此專案為個人開發環境配置，僅供參考使用。

---

## 更新日誌

### 2026-01-06

- 新增完整的中文文檔
- 優化環境變數載入機制
- 改進憑證安全儲存方式
