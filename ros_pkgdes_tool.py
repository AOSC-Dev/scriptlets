#!/usr/bin/env python3

# Note: This script is written with Google Gemini Pro 3.1
#
# Prompt:   
#   "Create a Python script to automate the extraction, 
#    cleaning, and application of ROS 2 package descriptions (PKGDES) 
#    for new packages introduced in AOSC OS ABBS."

import os
import sys
import subprocess
import re
import json

TODO_FILE = "pkgdes_todo.json"

def run_cmd(cmd, check=True):
    """运行 Shell 命令并返回输出"""
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and res.returncode != 0:
        print(f"❌ 命令执行失败: {cmd}\n错误信息: {res.stderr}")
        sys.exit(1)
    return res.stdout.strip()

def get_repo_root():
    return run_cmd("git rev-parse --show-toplevel")

def print_usage():
    print("ROS 2 包描述自动化处理工具")
    print("用法: 将该脚本放置在TREE目录下，执行以下命令：")
    print("  python3 ros_pkgdes_tool.py extract <commit_范围>  - 按 Commit ID 提取新增包的 PKGDES")
    print("  python3 ros_pkgdes_tool.py clean                 - 自动清洗和精简提取出的包描述")
    print("  python3 ros_pkgdes_tool.py apply                 - 将修改后的描述写回文件并生成 Git 提交")
    print("\n示例:")
    print("  python3 ros_pkgdes_tool.py extract stable..HEAD")
    print("  python3 ros_pkgdes_tool.py extract HEAD~20..HEAD")
    print("  python3 ros_pkgdes_tool.py extract 163dd87..HEAD")

def extract(commit_range):
    os.chdir(get_repo_root())
    print(f"🔍 正在从提交范围 {commit_range} 中检索包...")
    
    # 获取范围内所有的 commit 标题
    log_out = run_cmd(f'git log --format="%s" {commit_range}', check=False)
    if not log_out:
        print("未找到任何提交历史。请检查你输入的范围是否正确。")
        return

    pkgs = []
    for line in log_out.splitlines():
        m = re.match(r'^(ros-jazzy-[^:]+):\s*new', line, re.IGNORECASE)
        if m:
            pkgs.append(m.group(1))
    
    pkgs = sorted(list(set(pkgs)))
    if not pkgs:
        print("没有在指定的提交范围内找到符合 'ros-jazzy-*: new' 的新包。")
        return

    print(f"📦 找到 {len(pkgs)} 个引入的新包。正在提取 PKGDES...")
    
    data = {}
    for pkg in pkgs:
        # 利用 git ls-files 动态寻找该包在 abbs-tree 中的具体位置
        path_out = run_cmd(f'git ls-files | grep -E "/?{pkg}/autobuild/defines$"', check=False)
        if not path_out:
            print(f"⚠️ 警告：无法在当前分支树中找到 {pkg} 的 defines 文件，跳过。")
            continue
            
        def_path = path_out.splitlines()[0]
        
        with open(def_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("PKGDES="):
                    raw_desc = line[len("PKGDES="):].strip()
                    # 彻底剥离原始可能存在的所有类型的引号
                    if raw_desc.startswith(('"', "'")): raw_desc = raw_desc[1:]
                    if raw_desc.endswith(('"', "'")): raw_desc = raw_desc[:-1]
                    data[pkg] = raw_desc
                    break

    # 以标准 JSON 格式导出，缩进为 4 空格，方便编辑器查看和修改
    with open(TODO_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        
    print(f"✅ 已成功将 {len(data)} 个包的描述提取至 {TODO_FILE}")
    print("你可以直接用代码编辑器打开该文件进行集中修改，然后再执行 clean 或 apply。")

def clean():
    if not os.path.exists(TODO_FILE):
        print(f"❌ 找不到 {TODO_FILE}，请先执行 extract 命令。")
        return
        
    with open(TODO_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    cleaned_data = {}
    for pkg, text in data.items():
        # 1. 移除无用的前缀
        prefixes = [
            r"^[Aa]?\s*[Pp]ackage\s+containing\s+",
            r"^[Aa]?\s*[Pp]ackage\s+providing\s+",
            r"^[Aa]?\s*[Pp]ackage\s+to\s+",
            r"^[Aa]?\s*[Pp]ackage\s+",
            r"^[Aa]?\s*[Tt]ool\s+to\s+",
            r"^[Aa]?\s*[Ss]et\s+of\s+",
            r"^[Tt]his\s+package\s+defines\s+",
            r"^[Tt]his\s+package\s+provides\s+",
            r"^[Tt]his\s+package\s+",
            r"^[Tt]he\s+[a-zA-Z0-9_\-]+\s+package\s+provides\s+",
            r"^[Tt]he\s+[a-zA-Z0-9_\-]+\s+package\s+"
        ]
        for p in prefixes:
            text = re.sub(p, "", text, flags=re.IGNORECASE)
            
        # 2. 移除独立冠词 (a, an)
        text = re.sub(r'(?i)\b(?:a|an)\b\s+', '', text)
        
        # 3. 优化 Vendor 包描述
        def replace_vendor(match):
            return f"ROS 2 wrapper for {match.group(1).strip()}"
        text = re.sub(r'(?i)^([a-zA-Z0-9_\-]+)\s+vendor\s+package$', replace_vendor, text)
        text = re.sub(r'(?i)^vendor\s+package\s+for\s+([a-zA-Z0-9_\-]+)$', replace_vendor, text)
        
        # 4. 统一标准化 ROS 2
        text = re.sub(r'\bROS2\b', 'ROS 2', text)
        text = re.sub(r'\bROS\b(?!\s*\d)', 'ROS 2', text)
        
        # 5. 清除多余空格，并首字母大写
        text = re.sub(r'\s+', ' ', text).strip()
        if text:
            text = text[0].upper() + text[1:]
            
        cleaned_data[pkg] = text
        
    clean_file = "pkgdes_todo_clean.json"
    with open(clean_file, "w", encoding="utf-8") as f:
        json.dump(cleaned_data, f, indent=4, ensure_ascii=False)
        
    print(f"✨ 自动化清洗已完成！结果已保存至 {clean_file}")
    print("你可以对比检查一下，如果没问题，只需将其重命名为 pkgdes_todo.json 然后运行 apply 即可。")

def apply():
    os.chdir(get_repo_root())
    if not os.path.exists(TODO_FILE):
        print(f"❌ 找不到 {TODO_FILE}，请先配置好要写入的文件。")
        return
        
    with open(TODO_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    applied_count = 0
    msg_file = "tmp_msg.txt"

    for pkg, new_pkgdes in data.items():
        path_out = run_cmd(f'git ls-files | grep -E "/?{pkg}/autobuild/defines$"', check=False)
        if not path_out:
            print(f"⚠️ 找不到 {pkg} 的 defines 文件，跳过。")
            continue
            
        def_path = path_out.splitlines()[0]
        
        with open(def_path, "r", encoding="utf-8") as df:
            lines = df.readlines()
            
        # 安全转义重音符：如果 ` 前面没有 \，则替换为 \`
        escaped_pkgdes = re.sub(r'(?<!\\)`', r'\\`', new_pkgdes)
        
        with open(def_path, "w", encoding="utf-8") as df:
            for line in lines:
                if line.startswith("PKGDES="):
                    df.write(f'PKGDES="{escaped_pkgdes}"\n')
                else:
                    df.write(line)
                    
        # 触发 Git 提交
        run_cmd(f'git add "{def_path}"')
        status = subprocess.run(["git", "diff", "--cached", "--quiet"])
        
        if status.returncode != 0:
            commit_msg = f"{pkg}: improve PKGDES\n\nCo-authored-by: Mingcong Bai <jeffbai@aosc.io>"
            with open(msg_file, "w", encoding="utf-8") as mf:
                mf.write(commit_msg)
                
            run_cmd(f'git commit -F {msg_file}')
            applied_count += 1
            print(f"✅ 已提交: {pkg}")
        else:
            print(f"⚠️ 跳过: {pkg} (覆写后文件内容无实际变化)")
            
    if os.path.exists(msg_file):
        os.remove(msg_file)
        
    print(f"\n🎉 全部处理完成！本次共自动化提交了 {applied_count} 个修改。")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)
        
    action = sys.argv[1]
    
    if action == "extract":
        if len(sys.argv) != 3:
            print("❌ 错误: extract 需要提供 Git Commit 范围。")
            print("示例: python3 ros_pkgdes_tool.py extract HEAD~10..HEAD")
            sys.exit(1)
        extract(sys.argv[2])
    elif action == "clean":
        clean()
    elif action == "apply":
        apply()
    else:
        print("❌ 错误: 未知指令。")
        print_usage()
