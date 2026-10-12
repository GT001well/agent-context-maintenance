# agent-context-maintenance

> 一份**最小可跑**的参考实现：给长期运行的 AI agent 的**分层上下文**（身份 / 用户 / 记忆 / 指针），
> 外加一套让这些层不会腐烂的维护工具链。

[English](README.md) · 本文件为中文版

本仓库里的内容**全部是虚构示例**：agent 叫 Alice，用户叫 Sam，主机是 `example-host`。
没有任何文件、路径或姓名取自真实部署；`docs/` 里的经验教训是唯一不是编的，且已剥掉一切能指认来源的信息。

## 适用于什么

三条同时成立时，一个 agent 才需要这套东西：（1）会话开始时会加载或注入一些文件；（2）它自己会写长期笔记；
（3）上下文塞满时会**压缩或总结**历史。第三条才是前两条变危险的原因：历史一旦被总结，只活在对话里的东西就变成了
「某一份对它的总结」，而写进文件的东西还是它自己。

最吃这一套的是**会自我维护**的 agent：自己写 skill、留笔记或日记，下个会话再读回来。对它来说，一次压缩丢的不只是
一段对话，是自己工作记忆的一部分。某一家的「自己写」行为看不出来的，下表就不替它写；三条条件本身才是判据。

这个形状不属于任何一家。撰写时的常见例子：

| agent | 会加载的长期笔记 | 自己会写笔记吗 | 上下文怎么被压缩 |
|---|---|---|---|
| Claude Code | `CLAUDE.md`，以及会话开始时加载的记忆文件 | — | 窗口将满时自动压缩 |
| Cline | `.clinerules` | — | 上下文窗口管理，总结较早的轮次 |
| Codex CLI | `AGENTS.md` | — | 到 token 阈值自动 compact |
| Cursor | `.cursor/rules`、保存的记忆 | 自己会存记忆 | 会话总结、记忆条目 |
| Gemini CLI | `GEMINI.md` | — | `/compress`，以及自动阈值 |
| GenericAgent | 磁盘上的笔记与种子代码 | 设计上就自我进化 | 压缩携带的内容，保住决策相关的信息密度 |
| Hermes Agent | `SOUL.md` 与策展过的记忆文件，每轮注入 | 自己维护 skill 与记忆 | 上下文压缩，之后从摘要 + 落盘状态续上 |
| OpenClaw | 工作区里的 `MEMORY.md` 加一棵 Markdown 文件树；每日日志在会话开始时读 | 自己写每日记忆与 skill | 窗口接近上限时压缩 |
| open-strix | memory blocks 与文件，全部提交进它自己的仓库 | 自己排活、自己复盘 | 交给它运行的 harness 管 |

这些名字只是例子，不是兼容性声明：产品比这个形状变得快，本仓库与它们任何一家都没有隶属关系。
拿上面三条对着你在用的东西核一遍：只满足第一条，四层拆分是杀鸡用牛刀；三条都满足，下面的分层就是最便宜的防腐手段。

## 为什么需要它

长期运行的 agent 会攒下四类文字上下文，而它们的腐烂方式各不相同：

| 层 | 文件 | 每轮注入？ | 会怎么烂 |
|---|---|---|---|
| 身份 | `IDENTITY.md` | 是 | 与真实行为逐渐脱节 |
| 用户 | `USER.md` | 是 | 膨胀，直到吃掉上下文预算 |
| 记忆 | `MEMORY.md` | 是 | 塞满本该写进任务 skill 的事实 |
| 指针 | `POINTERS.md` | **否**，按需读 | 静默失效 |

杀死这些文件的从来不是「忘了记」，而是两件事：

1. **静默的链接腐烂。** 一条指针指不到东西不会报错，agent 只是从此找不到内容，几周后才发现。
2. **没有验证的改动。** agent 重写文件、丢了三行本来要留的内容，然后报告「完成」。没有改前备份与改后比对，
   「看起来没问题」就是唯一的信号。

本仓库用最小的代价解决这两件事：四份有明确契约的上下文文件、一棵带索引约定的 skill 树、
六个让「改动」和「链接」变得**可检查**的脚本。

## 思路

1. **按「读的频率」分层，不按主题分层。** 注入的文件是预算，按需读的是索引。写一条之前先定级：
   **A** 每轮都要／**B** 一整类任务要用（进 skill + 一条指针）／**C** 能重算（只记怎么问，不记答案）。
2. **改动没被检查过就等于没做完。** 备份、改、与备份比对、跑检查。底下那条：执行改动的 agent 不能是唯一的见证人。
3. **检查只有在被信任时才有用。** 编号冻结；退出码只给自有维度；一条判据只住一个地方；
   两个方向都自测：改措辞要过、真丢内容要抓。
4. **指针要三种结局，不是两种**（解析得了／可恢复／真断）。把「归档」并进「丢了」，人就会学会什么都不敢归档。

细节（包括几条反直觉的）在 `docs/` 里。

## 目录结构

```
.
├── README.md                    英文版
├── README.zh-CN.md              本文件
├── LICENSE                      MIT
├── config.example.env           所有脚本读取的开关
├── docs/
│   ├── design.md                为什么分四层，每层该放什么
│   ├── maintenance-workflow.md  改动循环，以及让循环有效的规则
│   ├── check-dimensions.md      检查编号与指针自修复机制
│   └── pitfalls.md              这套体系会腐烂的十二种方式（附修法）
├── example-agent/               示例 agent home，脚本可直接作用于它
│   ├── IDENTITY.md  USER.md  MEMORY.md  POINTERS.md
│   └── skills/
│       ├── example-skill/{SKILL.md, references/INDEX.md, references/*.md}
│       └── another-skill/{SKILL.md, ...}
└── scripts/
    ├── _config.py               路径解析的唯一来源（shell 版是 _config.sh）
    ├── _config.sh
    ├── pre-change-backup.sh     改前备份（绝不覆盖旧备份）
    ├── post-change-compare.py   这次改动丢掉东西了吗
    ├── snapshot-context.sh      四份文件的时间戳快照
    ├── archive-baks.py          打包旧备份，每源只留最新 N 份
    ├── pointers-check.py        指针与互引边还指得到吗
    ├── index-audit.py           索引表与磁盘对得上吗
    └── selftest.sh              把示例树拷到 /tmp，把所有脚本空跑一遍
```

## 快速开始

除 `bash`、`python3`（3.8+）、coreutils 之外，还需要 `tar` 与 GNU `findutils`（快照脚本用了 `find -printf`）。

```bash
git clone <本仓库>
cd agent-context-maintenance
./scripts/selftest.sh          # 对 example-agent/ 的一次性副本跑全部脚本
```

指向你自己的 agent home：

```bash
export AGENT_HOME=/path/to/your/agent/home     # 放四份 .md 的目录
export AGENT_SKILLS_ROOT=$AGENT_HOME/skills    # skill 树
export AGENT_BACKUP_DIR=/path/outside/the/tree # 备份不要落在被保护对象内部
```

## 改动循环

```
备份 → 改 → 比对 → 检查 → 快照
```

```bash
./scripts/pre-change-backup.sh example-agent/MEMORY.md
$EDITOR example-agent/MEMORY.md
python3 scripts/post-change-compare.py .backups/MEMORY.md.bak.<时间戳> example-agent/MEMORY.md
python3 scripts/pointers-check.py
./scripts/snapshot-context.sh
```

备份落 `AGENT_BACKUP_DIR`（脚本会把路径打出来），不落在被保护文件旁边：上下文目录里的 `.bak` 会被各种扫描当成内容统计。

只有「比对」这一步需要人看：

- 它把消失的行、以及自己为什么这么判，一起打出来：

  ```
    L50: - A vector index for cross-session recall. Rejected for this deploym
           tokens gone: cross-session, deployment:, recall. | no phrase survives (14 checked)
  [!] 1 line(s) look lost — read them before trusting the edit
  ```

- 退出码 1 的意思是「读一遍这些」，不是「改动失败了」。这条判据故意偏向误报：误报的代价是看一眼，静默丢内容的代价是内容没了。
- 内容是搬走而不是消失时，用 `--pool DIR_OR_FILE` 指出搬去哪，同一行就会变回绿。

「检查」是两个各持退出码、各打 `文件:行号` 的脚本；「快照」给四份文件留一份带时间戳的副本。
完整规则（包括几条反直觉的）在 `docs/maintenance-workflow.md`。

## 出处说明

这不是任何现成框架的移植。四层结构、改动循环和检查编号，都来自一套**在实战里长出来的**维护工作流
（围绕一个长期运行的 agent），然后把所有部署相关的东西剥掉。

它借用的都是通用做法，且都在其本来的意义上使用：改前先写的写前备份、golden/快照测试、
自己持有退出码的 linter、破坏性操作分 `plan` 与 `apply` 两段、只新增不覆盖、
把文档当作「会被检查读取的数据」、以及**带着上一轮修复清单来**的复审方式。

## 许可

MIT，见 `LICENSE`。
