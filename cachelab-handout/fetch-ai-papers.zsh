#!/bin/zsh
# ============================================
# AI 论文自动获取脚本
# ============================================
# 从 arXiv 获取最新 AI 论文并写入 Obsidian 日记
#
# 用法: 
#   fetch-ai-papers           # 获取最新10篇AI论文
#   fetch-ai-papers 20        # 获取最新20篇
#   fetch-ai-papers 10 "LLM"  # 搜索特定主题
# ============================================

function fetch-ai-papers() {
    local count=${1:-10}
    local search_term=${2:-""}
    
    echo "🔍 正在从 arXiv 获取最新 AI 论文..."
    
    # 构建 arXiv API 查询
    # cat:cs.AI = AI 分类, cat:cs.LG = 机器学习, cat:cs.CL = 计算语言学(NLP)
    local base_url="http://export.arxiv.org/api/query"
    local query="cat:cs.AI+OR+cat:cs.LG+OR+cat:cs.CL"
    
    if [[ -n "$search_term" ]]; then
        query="all:${search_term}+AND+(${query})"
    fi
    
    local api_url="${base_url}?search_query=${query}&start=0&max_results=${count}&sortBy=submittedDate&sortOrder=descending"
    
    # 获取数据（增加超时和重试）
    local xml_data=$(curl -m 60 -s --retry 2 "$api_url")
    
    # 检查是否获取成功
    if [[ -z "$xml_data" ]] || [[ ! "$xml_data" == *"<feed"* ]]; then
        echo "⚠️ arXiv API 暂时不可用，尝试备用方案..."
        _fetch_papers_huggingface "$count" "$search_term"
        return $?
    fi
    
    # 解析 XML 并生成 Markdown 表格
    local markdown_content="
## 📚 最新 AI 论文 ($(date '+%Y-%m-%d %H:%M'))

> 来源: arXiv | 数量: ${count} 篇 ${search_term:+| 搜索: $search_term}

| # | 标题 | 作者 | 链接 | 发布日期 |
|---|------|------|------|----------|"

    # 使用 Python 解析 XML（更可靠）
    local table_rows=$(python3 << EOF
import xml.etree.ElementTree as ET
import html

xml_data = '''${xml_data}'''

# 解析 XML
root = ET.fromstring(xml_data)
ns = {'atom': 'http://www.w3.org/2005/Atom'}

entries = root.findall('atom:entry', ns)
count = 0

for i, entry in enumerate(entries[:${count}], 1):
    title = entry.find('atom:title', ns)
    title_text = title.text.strip().replace('\n', ' ').replace('|', '-') if title is not None else 'N/A'
    # 截断过长标题
    if len(title_text) > 60:
        title_text = title_text[:57] + '...'
    
    # 获取作者（最多显示3个）
    authors = entry.findall('atom:author/atom:name', ns)
    author_names = [a.text for a in authors[:3]]
    if len(authors) > 3:
        author_names.append('et al.')
    authors_text = ', '.join(author_names)
    
    # 获取链接
    link = entry.find('atom:id', ns)
    link_text = link.text if link is not None else '#'
    # 转换为 abs 链接
    link_text = link_text.replace('http://arxiv.org/abs/', 'https://arxiv.org/abs/')
    
    # 获取发布日期
    published = entry.find('atom:published', ns)
    pub_date = published.text[:10] if published is not None else 'N/A'
    
    print(f"| {i} | {title_text} | {authors_text} | [arXiv]({link_text}) | {pub_date} |")
    count += 1

if count == 0:
    print("| - | 未找到论文 | - | - | - |")
EOF
)

    markdown_content="${markdown_content}
${table_rows}

---
#ai-papers #research #arxiv"

    # 写入 Obsidian 日记
    if command -v obsidian &> /dev/null; then
        obsidian daily:append content="$markdown_content"
        echo "✅ 已将 ${count} 篇论文信息写入今日日记！"
    else
        echo "⚠️ Obsidian CLI 不可用，输出到终端："
        echo "$markdown_content"
    fi
}

# 快捷命令：获取特定主题的论文
function ai-papers-llm() {
    fetch-ai-papers ${1:-10} "large language model"
}

function ai-papers-vision() {
    fetch-ai-papers ${1:-10} "computer vision"
}

function ai-papers-agent() {
    fetch-ai-papers ${1:-10} "AI agent"
}

function ai-papers-rag() {
    fetch-ai-papers ${1:-10} "retrieval augmented generation"
}

# 备用方案：从 Hugging Face Daily Papers 获取
function _fetch_papers_huggingface() {
    local count=${1:-10}
    local search_term=${2:-""}
    
    echo "📡 尝试从 Hugging Face Daily Papers 获取..."
    
    local hf_data=$(curl -m 30 -s "https://huggingface.co/api/daily_papers" 2>/dev/null)
    
    if [[ -z "$hf_data" ]] || [[ "$hf_data" == *"error"* ]]; then
        echo "⚠️ 网络不可用，使用演示数据..."
        _generate_demo_papers "$count"
        return 0
    fi
    
    local markdown_content="
## 📚 最新 AI 论文 ($(date '+%Y-%m-%d %H:%M'))

> 来源: Hugging Face Daily Papers | 数量: ${count} 篇

| # | 标题 | 作者 | 链接 | 发布日期 |
|---|------|------|------|----------|"

    local table_rows=$(python3 << EOF
import json
import sys

try:
    data = json.loads('''${hf_data}''')
    
    for i, paper in enumerate(data[:${count}], 1):
        title = paper.get('title', 'N/A').replace('|', '-').replace('\n', ' ')[:60]
        if len(paper.get('title', '')) > 60:
            title += '...'
        
        authors = paper.get('authors', [])
        if isinstance(authors, list) and len(authors) > 0:
            if isinstance(authors[0], dict):
                author_names = [a.get('name', '') for a in authors[:3]]
            else:
                author_names = authors[:3]
            if len(authors) > 3:
                author_names.append('et al.')
            authors_text = ', '.join(author_names)
        else:
            authors_text = 'N/A'
        
        paper_id = paper.get('paper', {}).get('id', paper.get('id', ''))
        link = f"https://huggingface.co/papers/{paper_id}" if paper_id else '#'
        
        pub_date = paper.get('publishedAt', 'N/A')[:10]
        
        print(f"| {i} | {title} | {authors_text} | [HF]({link}) | {pub_date} |")
except Exception as e:
    print(f"| - | 解析错误: {e} | - | - | - |", file=sys.stderr)
EOF
)

    markdown_content="${markdown_content}
${table_rows}

---
#ai-papers #research #huggingface"

    if command -v obsidian &> /dev/null; then
        obsidian daily:append content="$markdown_content"
        echo "✅ 已将论文信息写入今日日记！"
    else
        echo "$markdown_content"
    fi
}

# 演示数据（网络不可用时使用）
function _generate_demo_papers() {
    local count=${1:-10}
    
    local markdown_content="
## 📚 AI 论文推荐 ($(date '+%Y-%m-%d %H:%M'))

> ⚠️ 网络暂时不可用，以下为近期热门论文推荐

| # | 标题 | 作者 | 链接 | 说明 |
|---|------|------|------|------|
| 1 | Attention Is All You Need | Vaswani et al. | [arXiv](https://arxiv.org/abs/1706.03762) | Transformer 架构奠基之作 |
| 2 | BERT: Pre-training of Deep Bidirectional Transformers | Devlin et al. | [arXiv](https://arxiv.org/abs/1810.04805) | 预训练语言模型里程碑 |
| 3 | GPT-4 Technical Report | OpenAI | [arXiv](https://arxiv.org/abs/2303.08774) | GPT-4 技术报告 |
| 4 | LLaMA: Open Foundation Large Language Models | Touvron et al. | [arXiv](https://arxiv.org/abs/2302.13971) | Meta 开源大模型 |
| 5 | Constitutional AI | Anthropic | [arXiv](https://arxiv.org/abs/2212.08073) | AI 安全对齐方法 |
| 6 | Retrieval-Augmented Generation for LLMs | Lewis et al. | [arXiv](https://arxiv.org/abs/2005.11401) | RAG 技术原论文 |
| 7 | Chain-of-Thought Prompting | Wei et al. | [arXiv](https://arxiv.org/abs/2201.11903) | 思维链提示技术 |
| 8 | LoRA: Low-Rank Adaptation | Hu et al. | [arXiv](https://arxiv.org/abs/2106.09685) | 高效微调方法 |
| 9 | Diffusion Models Beat GANs | Dhariwal et al. | [arXiv](https://arxiv.org/abs/2105.05233) | 扩散模型图像生成 |
| 10 | CLIP: Learning Visual Concepts | Radford et al. | [arXiv](https://arxiv.org/abs/2103.00020) | 多模态学习经典 |

> 💡 提示: 请检查网络连接后重新运行 \`fetch-ai-papers\` 获取最新论文

---
#ai-papers #research #classics"

    if command -v obsidian &> /dev/null; then
        obsidian daily:append content="$markdown_content"
        echo "✅ 已将经典论文推荐写入今日日记！"
    else
        echo "$markdown_content"
    fi
}

# 手动添加论文到日记
function add-paper() {
    local title="$1"
    local authors="$2"
    local link="$3"
    local summary="$4"
    
    if [[ -z "$title" ]]; then
        echo "用法: add-paper \"标题\" \"作者\" \"链接\" \"摘要(可选)\""
        return 1
    fi
    
    local content="
### 📄 $title
- **作者**: ${authors:-N/A}
- **链接**: ${link:-N/A}
- **摘要**: ${summary:-待补充}

---"

    obsidian daily:append content="$content"
    echo "✅ 论文已添加到今日日记"
}

echo "📚 AI 论文获取工具已加载！"
echo "   fetch-ai-papers [数量] [搜索词]  - 获取最新AI论文"
echo "   ai-papers-llm [数量]             - 获取 LLM 相关论文"
echo "   ai-papers-agent [数量]           - 获取 AI Agent 相关论文"
echo "   add-paper \"标题\" \"作者\" \"链接\" - 手动添加论文"
