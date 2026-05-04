
# SKILLS

> 自己蒸自己, 赛博永生！

## Install with Codex

In Codex, ask the built-in `skill-installer` to install the skill from this repository:

```text
使用 skill-installer 安装 https://github.com/xuzhougeng/skills/tree/main/skills/persistent-analysis-session
```

Or run the installer script directly:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
python "$CODEX_HOME/skills/.system/skill-installer/scripts/install-skill-from-github.py" \
  --url https://github.com/xuzhougeng/skills/tree/main/skills/persistent-analysis-session
```

Restart Codex after installation so the new skill is loaded.

## Skills

skills/persistent-analysis-session

> 这个对象很大，不要反复加载，用常驻 session 做探索分析
