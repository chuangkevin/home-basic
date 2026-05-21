# home-basic

HomeProject 的 **基底 template**：開新專案、或從零搭一台 homelab 服務時的起點。內含三種東西，**請先看自己屬於哪一類**：

| 你要做什麼 | 看哪裡 |
|---|---|
| 在 homelab 起一個 OpenCode provider container（HomeProject 各服務共用的 AI 後端）| → [Quick start: opencode server](#quick-start-opencode-server) |
| 在新專案沿用 HomeProject 的 AI 工作流規則 / OpenSpec / skills | → [`CLAUDE.md`](./CLAUDE.md) + [`skills/`](./skills/) + [`openspec/`](./openspec/) |
| 改 home-basic 本身 | → [Repo 結構](#repo-結構)、再讀 `CLAUDE.md` 的 workflow rules |

---

## Quick start: opencode server

`opencode/` 是一個現成的 docker-compose service — 起來就是 [OpenCode](https://opencode.ai) provider session API + 一個瀏覽器 chat UI。HomeProject 旗下 sheet-to-car、project-bridge、mind-diary 等服務會把它當共用 AI backend 呼叫。

```bash
cd opencode
docker compose up -d
```

| Service | Port | URL |
|---|---|---|
| OpenCode session API | **4096** | http://localhost:4096 |
| OAuth callback（固定）| **1455** | http://localhost:1455 |
| 瀏覽器 chat UI | **3000** | http://localhost:3000 |

驗證：

```bash
curl http://localhost:4096/global/health    # 應回 {"healthy":true}
```

正式機已部在 Manjaro `100.73.52.37:4096`，公開 URL 是 <https://provider-amd.sisihome.org>。**不要** 用 `opencode-amd.sisihome.org`（不在 deployment 契約裡）。

⚠️ 部署 / 整合上的常見坑、API 契約、verify 步驟 — 詳見 [`opencode/README.md`](./opencode/README.md)。

---

## Repo 結構

```
home-basic/
├── README.md              ← 你正在讀的這份（入口）
├── CLAUDE.md              ← AI 助手的 workflow rules + skill 啟用清單
├── opencode/              ← 可部署的 OpenCode provider container
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   ├── web/               ← 瀏覽器 chat UI 靜態檔案
│   └── README.md          ← OpenCode 部署 / API 契約 / 踩坑筆記
├── openspec/              ← OpenSpec 規格驅動開發的方法論資料夾
│   ├── config.yaml
│   ├── changes/           ← 進行中的 spec proposal
│   └── specs/             ← 已 archive 的正式 spec
├── skills/                ← HomeProject 跨專案共用的 workflow skill
│   ├── execution-style/
│   ├── plan-before-build/
│   ├── project-stack-standard/
│   ├── completion-checklist/
│   ├── deployment/
│   ├── frontend-design/
│   ├── integration-robustness/
│   ├── key-pool-standard/
│   ├── root-cause-debugging/
│   ├── verification-and-evidence/
│   ├── agent-design/
│   └── skill-creator/
├── .github/               ← GitHub Copilot 用的 skill mirror（同 skills/ 內容）
├── .claude/               ← Claude Code 用的 skill mirror
├── .gemini/               ← Gemini CLI 用的 skill mirror
└── .opencode/             ← opencode CLI 用的 skill mirror
```

**所有 `.*/skills/` 與 `.github/skills/`** 都是同一批 skill 的不同 host 對應 — canonical source 是 `skills/`，這裡列的四個 dot-folder 是 mirror，讓不同 AI host 都能就近找到。

---

## 當作 GitHub template 使用

這個 repo 是 GitHub template。新專案從 template 建出來後：

1. 第一個 commit 就會帶這份 `CLAUDE.md` + `skills/` + `openspec/` — workflow 規則立刻生效
2. 編輯 `CLAUDE.md` 加你自己 stack / domain / team 的規則（保留 Skill Activation section）
3. 不需要的 skill 可以刪掉（`CLAUDE.md` 末段「When To Remove Or Replace Skills」有清單）
4. 用不到 OpenCode container 的專案就直接 `rm -rf opencode/`

---

## URL

- Repo：<https://github.com/chuangkevin/home-basic>
- 正式 OpenCode provider：<https://provider-amd.sisihome.org>
