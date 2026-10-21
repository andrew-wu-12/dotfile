# Dotfile

給 MOP 前端團隊的開發環境，一個指令裝到任何新機器上（macOS / Arch Linux）。三個重點：

1. **Claude Code skills — 從規格到上線的完整流程**：Jira 票券 → 規格 → 實作 → 瀏覽器驗證 → PR ready → prod 前檢查，每一步都有對應的 skill。
2. **即裝即用的設定檔**：zsh、nvim、tmux、WezTerm、Starship、VS Code、Claude Code，用 GNU Stow 一次連結到位。
3. **整合式 tmux 工作區**：一張票一個 worktree、一個視窗；`prefix w` 統一切換視窗、啟動 `yarn serve`、追蹤 Jenkins 建置、部署。學習曲線最陡，建議最後再上手。

---

## 安裝

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/andrew-wu-12/dotfile/main/install.sh)"
```

`install.sh` 會確認 git 可用（macOS 會開啟 Xcode Command Line Tools 安裝視窗，裝完請重跑同一行指令），把 repo 複製到 `~/dotfile`（可用 `DOTFILE_ROOT` 指定其他位置），再進入 `init.sh` 的互動選單：

| 選項 | 內容 |
|---|---|
| 1. 最小環境設定 | 基礎套件 + VS Code 設定 |
| 2. 個人環境設定 | 推薦 CLI 工具、tmux、nvim、Starship、WezTerm |
| 3. 最小專案初始化 | 專案路徑、SSH、憑證（Jira / Jenkins / GetData）、`gh` 登入、複製 MOP repo、Claude Code skills |
| 4. 個人工作區初始化 | `.workspace.conf`、工作區 SSH 身分、`gh` 登入 |
| 進階 / 個別步驟 | 單獨執行任一步驟 |

每個選項都會先跑基礎步驟（Homebrew、必要套件、Oh My Zsh、連結 `zsh` 與 `bin`）。已完成的步驟會自動略過，所以**隨時可以重跑**。結束時若在終端機中執行，會直接進入已套用新設定的 zsh。

已經複製過 repo 的話，直接執行 `~/dotfile/bin/init.sh`。

---

## ① Claude Code skills：從規格到上線

Skills 放在 `claude/.claude/skills/`，安裝選項 3 會安裝 Claude Code，並把每個 skill 個別連結到 `~/.claude/skills/<名稱>`，在任何 Claude Code session 輸入 `/<skill 名稱>` 即可使用。

**不會動到你自己的設定**：這個步驟只連結 skills，不碰 `~/.claude` 下的 `settings.json`、`CLAUDE.md`。你已經有的 skill 不受影響；如果名稱和這裡的 skill 重複，會保留你的版本並列出被略過的名稱。重跑會補上新增的 skill、清掉已移除的。

（進階選單的「Claude Code」步驟會連結整個 `claude/` 套件，包含作者個人的 `settings.json` 與 `CLAUDE.md`，只適合作者自己的機器。）

### 主流程（Jira 票券）

```
mop-spec-init ──► spec-sync ──► mop-spec-post ──► 實作
   建立規格          PM 討論後更新       推回 Jira          │
                     （可重複多輪）                          ▼
mop-spec-ready-prod ◄── mop-spec-feature-ready ◄── mop-spec-drift ◄── mop-spec-verify
   prod 前檢查            PR 轉 ready                 規格 vs 程式碼       瀏覽器跑測試情境
```

| 階段 | Skill | 做什麼 | 產出 |
|---|---|---|---|
| 開票 | `mop-spec-init MOP-XXXX` | 讀 Jira 票券與 monorepo 程式碼，逐一追問缺漏後寫出規格 | `Specs/MOP-XXXX.md` 規格筆記 + 私人待釐清清單 |
| 討論 | `spec-sync MOP-XXXX` | 貼上與 PM 的對話紀錄，抓出矛盾、合併新決定 | 更新後的規格 + 新一輪快照 |
| 發布 | `mop-spec-post MOP-XXXX` | 先自我挑戰規格漏洞，再覆寫 Jira 描述並留下本輪變更 | Jira 描述 + 變更留言 |
| 驗證 | `mop-spec-verify MOP-XXXX` | 在本機 `yarn serve` 上用瀏覽器逐條跑測試情境 | 每條情境 PASS / FAIL / INCONCLUSIVE |
| 對齊 | `mop-spec-drift MOP-XXXX` | 比對規格最近兩輪差異，找出已過時的程式碼 | 漂移清單（附信心程度） |
| 送審 | `mop-spec-feature-ready` | 檢查規格已發布、程式碼符合規格、瀏覽器驗證通過、沒有殘留的已移除識別字、diff 無缺陷 | 全部通過則把草稿 PR 轉為 ready |
| 上線 | `mop-spec-ready-prod MOP-XXXX` | 確認 uat 分支上每張票都是 UAT VERIFIED | 檢查報告（只提醒，不擋） |

### 需要準備的東西

- **Jira 憑證**：安裝選項 3 的「憑證」步驟會存進 Keychain / libsecret。
- **規格筆記資料夾**：規格寫在 Obsidian vault `~/personal/office-note/Specs/`，請先建立這個資料夾（或放你的 vault）。
- **`gh` 已登入**：PR 相關的 skill 都透過 GitHub CLI。
- **ego-browser**：`mop-spec-verify` 用它操作瀏覽器。
- **MOP monorepo worktree**：skill 在 `mwt` 建立的 worktree 裡執行效果最好（見 ③）。

### 其他常用 skill

| Skill | 用途 |
|---|---|
| `mop-check-privilege` | 找出功能需要的權限節點，並開 `mop_configuration_files` 的 `[DEV]` PR |
| `combine-branches` | 把多個 feature 分支合成一個可部署的整合分支 |
| `deploy-i18n` | 透過 Jenkins 部署翻譯到 dev / uat / prod |
| `create-deploy-plan` | 在 Confluence 建立 deploy plan 頁面 |
| `doc-common-component-changelog` | 為 `libs/**` 的共用元件變更產生 Confluence 變更紀錄 |
| `doc-field-spec` / `format-i18n-key` | 欄位規格與 i18n key 查找、命名 |
| `mop-frontend-document` | 撰寫或檢查 vault 中的前端功能說明 |
| `pr-review-markdown-summary` | 把 PR review 留言整理成表格，附修正狀態 |


---

## ② 即裝即用的設定檔

每個資料夾是一個 [GNU Stow](https://www.gnu.org/software/stow/) 套件，安裝時會被 symlink 到 `$HOME` 對應位置：

| 資料夾 | 連結到 | 內容 |
|---|---|---|
| `zsh/` | `~/.zshrc` | Oh My Zsh、別名、專案路徑變數、憑證讀取 |
| `bin/` | `~/bin/` | 所有腳本（`mwt`、`wtd`、`dev` 等指令的本體） |
| `nvim-stow/` | `~/.config/nvim/` | Neovim 設定 |
| `tmux/` | `~/.tmux.conf` | tmux 設定、外掛、session 自動存檔 |
| `wezterm/` | `~/.wezterm.lua` | WezTerm 終端機設定 |
| `starship/` | `~/.config/starship.toml` | Shell prompt |
| `vscode-stow/` | VS Code `settings.json` | VS Code 設定 |
| `claude/` | `~/.claude/` | Claude Code skills（選項 3 只連結 skills；完整設定僅供作者自用） |
| `raycast/` | 不連結 | `snippets.json`，從 Raycast 介面手動匯入 |

**修改設定**：直接改 repo 裡的檔案（例如 `~/dotfile/zsh/.zshrc`），因為 `$HOME` 下的是 symlink，改完立即生效。

**更新**：`cd ~/dotfile && git pull`，再執行 `bin/init.sh`。基礎步驟每次都會重新連結，新加入的腳本會自動出現在 `~/bin`。

**既有檔案衝突**：如果 `$HOME` 已經有同名的真實檔案，安裝程式會列出來並詢問是否保留。選擇不保留時，舊檔會備份成 `<檔名>.bak.<時間戳>`，不會直接刪除。

### 常用別名

| 別名 | 指令 |
|---|---|
| `gp` / `gpf` / `gP` | push / force push / pull 目前分支 |
| `gc` / `gco` / `gca` / `gs` | checkout / commit -m / amend / status |
| `gbc` | 複製目前分支名稱到剪貼簿 |
| `ys` / `yt` / `yb` / `yd` | `yarn serve` / `test` / `build-local` / `download-options` |
| `ygm` / `ygq` | 在目前目錄產生 Modal / Query Page |
| `crc MOP-XXXX` | 開 `mop_configuration_files` 的 `[DEV]` PR |
| `bws` | 把近兩週的 PR 以 JSON 複製到剪貼簿（雙週報告用） |
| `tbs` | 追蹤目前分支的 Jenkins 建置 |

完整清單見 `zsh/.zshrc`。

---

## ③ 整合式 tmux 工作區

由淺到深，建議一層一層上手。`prefix` 是 `Ctrl-B`。

### 第 1 層：開發視窗與切換

- `dev` — 在目前專案開一個 nvim + 指令列 + Claude 的三格視窗，視窗名稱為 `分支(專案)`。重複執行只會切換過去，不會重複開。
- `prefix w` — 直式視窗選單：列出目前 session 的所有視窗，`Enter` 切換。
- `prefix O` — 切換 session。
- `prefix Ctrl-G` / `prefix Ctrl-E` — 在彈出視窗開 lazygit / nvim。
- `Ctrl-h/j/k/l` — 在 tmux 窗格與 nvim 之間移動。

tmux session 每 5 分鐘自動存檔，重開機後執行 `tmux` 即可還原（`prefix Ctrl-S` / `prefix Ctrl-R` 手動存檔 / 還原）。

### 第 2 層：一張票一個 worktree

不用 `git stash`，每張票有自己的資料夾、分支與視窗，可以隨時切換：

```bash
mwt MOP-12345     # 查 Jira → 建立 uat/<parent> 與 feature/MOP-12345 分支 → 建 worktree → 開草稿 PR → 開 dev 視窗
wt my-branch      # 任何 repo 都能用：從預設分支建分支 + worktree（不推送、不開 PR）
wtd               # 在 worktree 裡執行：關視窗、移除 worktree、刪除已合併的分支
```

加 `-n` 會開新視窗而不是取代目前視窗。worktree 放在 `~/project/worktrees/<repo>/<票號>`，`node_modules` 以 APFS copy-on-write 複製，幾乎不佔空間，各票互不影響。

> MOP 的 `yarn serve` 埠號寫死，一次只能有一個 worktree 在 serve；測試、建置、lint 則可以同時跑。

### 第 3 層：在 `prefix w` 裡完成所有事

| 按鍵 | 功能 |
|---|---|
| `Tab` | 切換顯示：還沒建 worktree 的 Jira 票券。對票券按 `Enter` 會直接 `mwt` |
| `ctrl-s` / `ctrl-r` / `ctrl-x` / `ctrl-v` | 以選取的 worktree 啟動 / 重啟 / 停止 `yarn serve`，查看 log |
| `ctrl-g` | 即時追蹤該 worktree 的 Jenkins 建置進度 |
| `ctrl-p` | 部署該票券：選分支、選 job，然後追蹤 |
| `ctrl-n` | 開啟該票的筆記 |
| `ctrl-b` | 在瀏覽器開啟票券 |
| `ctrl-a` | 列出目前卡片所有可用動作 |

選到 MOP worktree 時，右側會顯示這張票的開發狀態檢查表（規格、PR、Jira 狀態、預覽網址、Jenkins 建置，epic 也一併列出）。

**Claude 通知**：在 worktree 裡跑的 Claude Code 需要你回應時，視窗名稱會加上 🔴，完成時加上 🟢，並發送 macOS 通知（你正在看那個視窗時不會通知）。開好幾張票平行讓 Claude 做事時，用 `prefix w` 一眼就能看出哪個在等你。

### 工作區設定（`.workspace.conf`）

serve 指令、session 分組、票券來源、筆記路徑等設定放在 `~/project/worktrees/<repo>/.workspace.conf`，安裝選項 4 會協助建立。可用變數：

| 變數 | 說明 |
|---|---|
| `SESSION_GROUP` | 讓多個專案共用同一個 tmux session（例如 monorepo 與設定檔 repo 都設成 `mop`） |
| `TASK_SOURCE_CMD` | `Tab` 列出的票券來源（MOP 為 `tmux-task-source-jira.sh`） |
| `WORKSPACE_SERVE_CMD` / `_LABEL` / `_PORT` | `yarn serve` 指令、顯示名稱、健康檢查埠號 |
| `WORKSPACE_PREVIEW_CMD` | 右側預覽窗格的指令 |
| `WORKSPACE_BUILD_CONF` | 設為 `1` 啟用建置追蹤（搭配同目錄的 `.tmux-build.conf`） |
| `NOTE_PATH` | `ctrl-n` 開啟的筆記路徑 |

基於安全考量，**repo 內部的 `.workspace.conf` / `.tmux-build.conf` 一律不讀取**，不是自己擁有或可被他人寫入的檔案也會略過。

---

## 憑證

Token 加密存放，不寫在任何檔案裡：macOS 用 Keychain，Arch 用 libsecret。執行 `~/bin/init-credentials.sh` 新增或更新，或手動存入：

```bash
# macOS
security add-generic-password -a "$USER" -s "<服務名稱>" -w "<token>" -U
# Arch
printf '%s' "<token>" | secret-tool store --label="<服務名稱>" service "<服務名稱>" account "$USER"
```

| 服務名稱 | 用途 |
|---|---|
| `morrisonexpress.atlassian.net` | Jira（`mwt`、spec skills） |
| `jenkins.morrison.express` | Jenkins 建置追蹤與部署 |
| `getdata.morrison.express` | `yarn download-options` |
| `openai.com` | Codex MCP（選用） |

`.zshrc` 在 shell 啟動時讀取 token 到**不 export** 的變數，子程序（Claude Code、npm scripts 等）不會繼承。

---

## 常見問題

**找不到 `mwt` / `dev` 等指令**：確認已開啟新的 zsh（或執行 `source ~/.zshrc`），且 `~/bin` 在 `PATH` 中。

**第一次讀取 Keychain 跳出授權視窗**：點「永遠允許」即可。

**Arch Linux 的限制**：桌面通知與 Claude 通知的「是否正在看這個視窗」判斷目前只支援 macOS。憑證需要桌面環境（GNOME / KDE）的 keyring。

---

## 平台支援

- **macOS**（主要）：Homebrew。
- **Arch Linux**：pacman + `yay`（AUR）。

所有腳本都相容 macOS 內建的 Bash 3.2。

---

## 授權

個人開發環境配置，僅供參考使用。
