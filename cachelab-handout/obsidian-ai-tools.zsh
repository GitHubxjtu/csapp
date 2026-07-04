#!/bin/zsh
# ============================================
# Obsidian + GitHub Copilot AI 工具集
# ============================================
# 
# 安装方法:
# 1. 将此文件放到你喜欢的位置
# 2. 在 ~/.zshrc 中添加: source /path/to/obsidian-ai-tools.zsh
# 3. 重启终端或运行: source ~/.zshrc
#
# 前提条件:
# - 安装并配置 GitHub CLI: gh auth login
# - 安装 Copilot CLI 扩展: gh extension install github/gh-copilot
# - Obsidian CLI 已启用并添加到 PATH
# - Obsidian 应用正在运行
# ============================================

# ==================== 配置 ====================
# 你可以修改这些默认值
OBSIDIAN_VAULT=""  # 留空使用当前活动的 vault，或指定 vault 名称
AI_NOTES_FOLDER="AI-Notes"  # AI 生成笔记的默认文件夹

# ==================== 核心函数 ====================

# 检查依赖是否可用
function _check_deps() {
    if ! command -v gh &> /dev/null; then
        echo "❌ 错误: 未找到 GitHub CLI (gh)，请先安装"
        return 1
    fi
    if ! command -v obsidian &> /dev/null; then
        echo "❌ 错误: 未找到 Obsidian CLI，请在 Obsidian 设置中启用"
        return 1
    fi
    return 0
}

# ==================== 快速笔记 ====================

# 快速添加想法到今日日记
# 用法: idea "你的想法"
function idea() {
    _check_deps || return 1
    local content="- 💡 **想法** ($(date +%H:%M)): $*"
    obsidian daily:append content="$content"
    echo "✅ 想法已添加到今日日记"
}

# 快速添加任务到今日日记
# 用法: task "任务内容"
function task() {
    _check_deps || return 1
    local content="- [ ] $*"
    obsidian daily:append content="$content"
    echo "✅ 任务已添加到今日日记"
}

# ==================== AI 辅助笔记 ====================

# 让 AI 解释概念并保存到笔记
# 用法: ai-explain "什么是量子计算"
function ai-explain() {
    _check_deps || return 1
    echo "🤖 AI 正在思考..."
    
    local query="$*"
    local response=$(gh copilot explain "$query" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        echo "❌ AI 未返回结果"
        return 1
    fi
    
    local filename="Explain-$(echo $query | tr ' ' '-' | head -c 30)-$(date +%Y%m%d%H%M)"
    local note_content="# $query

> 🤖 AI 生成于 $(date '+%Y-%m-%d %H:%M')

$response

---
#ai-generated #explanation"

    obsidian create name="$AI_NOTES_FOLDER/$filename" content="$note_content"
    echo "✅ 笔记已创建: $AI_NOTES_FOLDER/$filename"
}

# 让 AI 给出建议并保存
# 用法: ai-suggest "如何提高工作效率"
function ai-suggest() {
    _check_deps || return 1
    echo "🤖 AI 正在生成建议..."
    
    local query="$*"
    local response=$(gh copilot suggest "$query" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        echo "❌ AI 未返回结果"
        return 1
    fi
    
    local filename="Suggest-$(echo $query | tr ' ' '-' | head -c 30)-$(date +%Y%m%d%H%M)"
    local note_content="# 建议: $query

> 🤖 AI 生成于 $(date '+%Y-%m-%d %H:%M')

$response

---
#ai-generated #suggestion"

    obsidian create name="$AI_NOTES_FOLDER/$filename" content="$note_content"
    echo "✅ 建议笔记已创建: $AI_NOTES_FOLDER/$filename"
}

# AI 解释并追加到今日日记
# 用法: ai-daily "解释一下 REST API"
function ai-daily() {
    _check_deps || return 1
    echo "🤖 AI 正在思考..."
    
    local query="$*"
    local response=$(gh copilot explain "$query" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        echo "❌ AI 未返回结果"
        return 1
    fi
    
    local content="
## 🤖 AI: $query
> $(date '+%H:%M')

$response
"
    obsidian daily:append content="$content"
    echo "✅ AI 回复已添加到今日日记"
}

# ==================== 代码相关 ====================

# 解释代码/命令并保存笔记
# 用法: code-explain "git rebase -i HEAD~3"
function code-explain() {
    _check_deps || return 1
    echo "🤖 AI 正在解释代码..."
    
    local code="$*"
    local response=$(gh copilot explain "$code" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        echo "❌ AI 未返回结果"
        return 1
    fi
    
    local safe_name=$(echo $code | tr -cd '[:alnum:]-' | head -c 20)
    local filename="Code-$safe_name-$(date +%Y%m%d%H%M)"
    local note_content="# 代码解释

## 代码/命令
\`\`\`
$code
\`\`\`

## AI 解释
> 🤖 生成于 $(date '+%Y-%m-%d %H:%M')

$response

---
#ai-generated #code #reference"

    obsidian create name="$AI_NOTES_FOLDER/$filename" content="$note_content"
    echo "✅ 代码笔记已创建: $AI_NOTES_FOLDER/$filename"
}

# 解释当前目录的项目结构
# 用法: explain-project
function explain-project() {
    _check_deps || return 1
    echo "🤖 AI 正在分析项目结构..."
    
    local structure=$(ls -la 2>/dev/null | head -30)
    local response=$(gh copilot explain "这是一个项目目录，请分析其结构和用途: $structure" 2>/dev/null)
    
    local project_name=$(basename $(pwd))
    local filename="Project-$project_name-$(date +%Y%m%d)"
    local note_content="# 项目分析: $project_name

## 目录结构
\`\`\`
$structure
\`\`\`

## AI 分析
> 🤖 生成于 $(date '+%Y-%m-%d %H:%M')
> 📁 路径: $(pwd)

$response

---
#ai-generated #project #analysis"

    obsidian create name="$AI_NOTES_FOLDER/$filename" content="$note_content"
    echo "✅ 项目分析笔记已创建: $AI_NOTES_FOLDER/$filename"
}

# ==================== 搜索和查询 ====================

# 搜索 Obsidian 笔记
# 用法: note-search "关键词"
function note-search() {
    _check_deps || return 1
    obsidian search query="$*"
}

# 查看今日任务
# 用法: today-tasks
function today-tasks() {
    _check_deps || return 1
    obsidian tasks daily
}

# 查看所有标签
# 用法: note-tags
function note-tags() {
    _check_deps || return 1
    obsidian tags counts
}

# ==================== 快捷操作 ====================

# 打开今日日记
# 用法: today
function today() {
    _check_deps || return 1
    obsidian daily open
}

# 创建快速笔记
# 用法: quick-note "标题" "内容"
function quick-note() {
    _check_deps || return 1
    local title="$1"
    local content="$2"
    
    if [[ -z "$title" ]]; then
        echo "用法: quick-note \"标题\" \"内容(可选)\""
        return 1
    fi
    
    local note_content="# $title

> 创建于 $(date '+%Y-%m-%d %H:%M')

$content

---
#quick-note"

    obsidian create name="$title" content="$note_content"
    echo "✅ 笔记已创建: $title"
}

# ==================== 高级功能 ====================

# 每日回顾提示 (AI 生成反思问题)
# 用法: daily-reflect
function daily-reflect() {
    _check_deps || return 1
    echo "🤖 AI 正在生成今日反思问题..."
    
    local response=$(gh copilot suggest "Generate 3 thoughtful reflection questions for end of day journaling, in Chinese" 2>/dev/null)
    
    local content="
## 📝 今日反思 ($(date +%H:%M))

$response
"
    obsidian daily:append content="$content"
    echo "✅ 反思问题已添加到今日日记"
}

# 会议笔记快速创建
# 用法: meeting "会议主题"
function meeting() {
    _check_deps || return 1
    local topic="$1"
    
    if [[ -z "$topic" ]]; then
        echo "用法: meeting \"会议主题\""
        return 1
    fi
    
    local filename="Meeting-$topic-$(date +%Y%m%d)"
    local note_content="# 📅 会议: $topic

- **日期**: $(date '+%Y-%m-%d')
- **时间**: $(date '+%H:%M')
- **参与者**: 

## 议题

- 

## 讨论内容



## 行动项

- [ ] 

## 备注



---
#meeting"

    obsidian create name="Meetings/$filename" content="$note_content" open
    echo "✅ 会议笔记已创建并打开: Meetings/$filename"
}

# ==================== 帮助 ====================

# 显示所有可用命令
function ai-help() {
    echo "
╔══════════════════════════════════════════════════════════════╗
║          🤖 Obsidian + AI 工具集 - 命令列表                    ║
╠══════════════════════════════════════════════════════════════╣
║ 📝 快速笔记                                                   ║
║   idea \"想法\"          - 添加想法到今日日记                   ║
║   task \"任务\"          - 添加任务到今日日记                   ║
║   quick-note \"标题\"    - 创建快速笔记                        ║
║   today                - 打开今日日记                         ║
║                                                              ║
║ 🤖 AI 辅助                                                    ║
║   ai-explain \"问题\"    - AI 解释并保存为笔记                  ║
║   ai-suggest \"问题\"    - AI 建议并保存为笔记                  ║
║   ai-daily \"问题\"      - AI 回复追加到今日日记                ║
║   code-explain \"代码\"  - 解释代码并保存笔记                   ║
║   explain-project      - 分析当前项目结构                     ║
║   daily-reflect        - 生成每日反思问题                     ║
║                                                              ║
║ 🔍 搜索查询                                                   ║
║   note-search \"关键词\"  - 搜索笔记                           ║
║   today-tasks          - 查看今日任务                         ║
║   note-tags            - 查看所有标签                         ║
║                                                              ║
║ 📅 其他                                                       ║
║   meeting \"主题\"       - 创建会议笔记                        ║
║   ai-help              - 显示此帮助信息                       ║
╚══════════════════════════════════════════════════════════════╝
"
}

# 加载完成提示
echo "✅ Obsidian + AI 工具集已加载！输入 ai-help 查看所有命令"
