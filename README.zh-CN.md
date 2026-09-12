# agent-context-layers

> 一份**最小可跑**的参考实现：给长期运行的 AI agent 的**分层上下文**（身份 / 用户 / 记忆 / 指针），
> 外加一套让这些层不会腐烂的维护工具链。

本仓库里的内容**全部是虚构示例**：agent 叫 Alice，用户叫 Sam，主机是 `example-host`。
没有任何内容取自真实部署，见文末「范围」。

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
│   └── pitfalls.md              这套体系会腐烂的十种方式（附修法）
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
cd agent-context-layers
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

备份一律落在 `AGENT_BACKUP_DIR`（备份脚本会把路径打出来），**不落在被保护文件旁边**：
上下文目录里堆满 `.bak` 之后，扫描器就开始把备份当内容统计了。

意义不在于仪式感，而在于：**执行改动的 agent 不能同时是唯一的见证人。**

- `post-change-compare.py` 在「备份里的某行不再出现」**且**满足下列任一条时退出 **1**：结构化 token（路径/标识符/数字）在整个文件里没了、
  中文串没了、或者这一行的三词短语一条都没活下来。它是启发式判据，故意偏向误报：误报的代价是看一眼，静默丢内容的代价是内容没了。
  普通英文单词本身不算特征，所以改措辞仍然会通过。**不到 8 个字符的行不判**，报告最多列 40 条（并注明省略了多少）。
- `pointers-check.py` 只为自己那一组维度退出 **1**，并且打印 `文件:行号`；`index-audit.py` 只为自己那一组维度退出 **1**，打印路径。
  无论哪个，「检查是绿的」都是机器结论，不是感觉。
- `--pool DIR_OR_FILE` 告诉比对器：内容是被**搬走了**（进了某个 skill 或另一个文件），不是丢了。

完整规则（包括几条反直觉的）在 `docs/maintenance-workflow.md`。

## 设计规则（浓缩版）

1. **备份是第一个物理动作，不是第一个念头。** 「我记得要备份」不构成备份。
2. **注入是预算。** `IDENTITY.md` / `USER.md` / `MEMORY.md` 里每个字每轮都要付费；细节属于 skill，用指针引。
3. **没法被检查的指针一定会腐烂。** 指针登记在一处，并保证可解析。
4. **重要内容不许只活在 `MEMORY.md`。** 记忆会被压缩，流程属于 skill。
5. **同一条规则只有一个家。** 同一个判断写在两个脚本里必然漂移，第二处应该 import 第一处。
6. **脚本只新增，不覆盖。** 同一秒内重跑两次，不能吃掉上一份备份。
7. **给发现编号，并把编号冻结。** `[C]` 永远指同一个检查；重新编号是**有价签**的工程，不是收拾桌面。
   自有维度决定退出码，信息项永远不计。
8. **指针要三种结局，不是两种** —— 解析得了 / 可恢复（在归档里）/ 真断。
   把「归档了」折叠成「丢了」，等于扔掉报告里最有用的那半句。
9. **检查器要有自己的退出码**，但只算自己该管的维度，否则码天天报红就废了。
10. **两个方向都要自测。** 「改了措辞应当通过」和「真删了内容应当报警」是两个测试，不是一个。

## 范围

- 全部为示例内容：agent（Alice）、用户（Sam）、主机名、路径、skill 与 `example-agent/` 里的事实都是为演示编的。
- 脚本是某套工作流的自包含重写版，不含任何部署相关的配置，所有路径都从 `config.env`（由 `config.example.env` 拷贝而来）或环境变量读取。
- 仅在 Linux（bash 5、Python 3.8+）上测过。

## 许可

MIT，见 `LICENSE`。
