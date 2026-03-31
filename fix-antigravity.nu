#!/usr/bin/env nu

# Antigravity IDE 会话修复脚本
# 问题：崩溃后所有历史会话无法加载 (无限 spinning)
# 原因：state.vscdb (SQLite) 和 shared_proto_db (LevelDB) 中的
#       conversation → agent state 映射在非正常退出时损坏
# 
# 此脚本会：
# 1. 备份关键数据库文件
# 2. 删除损坏的状态数据库（不影响聊天记录）
# 3. IDE 重启后会从服务端重新同步会话状态
#
# ⚠️ 必须在 IDE 完全关闭后运行！

let config_dir = $"($env.HOME)/.config/Antigravity"
let backup_dir = $"($env.HOME)/.config/Antigravity/_repair_backup_(date now | format date '%Y%m%d_%H%M%S')"

# 检查 IDE 是否还在运行
let ide_procs = (ps | where name =~ "antigravity|Antigravity" | where name !~ "nu")
if ($ide_procs | length) > 0 {
    print "❌ Antigravity IDE 仍在运行！请先完全关闭 IDE 再运行此脚本。"
    print $"检测到进程：($ide_procs | select pid name | to text)"
    exit 1
}

print $"📁 创建备份目录：($backup_dir)"
mkdir $backup_dir

# 1. 备份并删除 globalStorage 的 state.vscdb
let global_vscdb = $"($config_dir)/User/globalStorage/state.vscdb"
let global_vscdb_backup = $"($config_dir)/User/globalStorage/state.vscdb.backup"
if ($global_vscdb | path exists) {
    print "📦 备份 globalStorage/state.vscdb ..."
    cp $global_vscdb $"($backup_dir)/globalStorage_state.vscdb"
    rm $global_vscdb
    print "   ✅ 已删除损坏的 globalStorage/state.vscdb"
}
if ($global_vscdb_backup | path exists) {
    cp $global_vscdb_backup $"($backup_dir)/globalStorage_state.vscdb.backup"
    rm $global_vscdb_backup
    print "   ✅ 已删除 globalStorage/state.vscdb.backup"
}

# 2. 备份并删除 workspaceStorage 的 state.vscdb
let ws_dirs = (ls $"($config_dir)/User/workspaceStorage" | where type == dir)
for ws in $ws_dirs {
    let ws_name = ($ws.name | path basename)
    let ws_vscdb = $"($ws.name)/state.vscdb"
    let ws_vscdb_backup = $"($ws.name)/state.vscdb.backup"
    if ($ws_vscdb | path exists) {
        print $"📦 备份 workspaceStorage/($ws_name)/state.vscdb ..."
        cp $ws_vscdb $"($backup_dir)/ws_($ws_name)_state.vscdb"
        rm $ws_vscdb
        print $"   ✅ 已删除损坏的 workspaceStorage state.vscdb"
    }
    if ($ws_vscdb_backup | path exists) {
        cp $ws_vscdb_backup $"($backup_dir)/ws_($ws_name)_state.vscdb.backup"
        rm $ws_vscdb_backup
        print $"   ✅ 已删除 workspaceStorage state.vscdb.backup"
    }
}

# 3. 备份并清理 shared_proto_db (LevelDB - 存储序列化的 agent state)
let proto_db = $"($config_dir)/shared_proto_db"
if ($proto_db | path exists) {
    print "📦 备份 shared_proto_db ..."
    cp -r $proto_db $"($backup_dir)/shared_proto_db"
    rm -rf $proto_db
    print "   ✅ 已删除损坏的 shared_proto_db"
}

# 4. 清理 DIPS 数据库和 WAL 文件
for f in ["DIPS" "DIPS-wal" "DIPS-journal" "SharedStorage" "SharedStorage-wal" "SharedStorage-journal"] {
    let fpath = $"($config_dir)/($f)"
    if ($fpath | path exists) {
        cp $fpath $"($backup_dir)/($f)"
        rm $fpath
        print $"   ✅ 已清理 ($f)"
    }
}

# 5. 清理残留的 code.lock
let lock_file = $"($config_dir)/code.lock"
if ($lock_file | path exists) {
    cp $lock_file $"($backup_dir)/code.lock"
    rm $lock_file
    print "   ✅ 已清理 code.lock"
}

# 6. 清理 Session Storage 和 Local Storage 的 LOCK 文件
for db_dir in ["Session Storage" "Local Storage/leveldb" "shared_proto_db/metadata"] {
    let lock = $"($config_dir)/($db_dir)/LOCK"
    if ($lock | path exists) {
        rm $lock
        print $"   ✅ 已清理 ($db_dir)/LOCK"
    }
}

print ""
print "══════════════════════════════════════════════════════"
print "✅ 修复完成！"
print ""
print $"📁 备份保存在: ($backup_dir)"
print ""
print "📝 你的聊天记录安全保存在："
print $"   ($env.HOME)/.gemini/antigravity/brain/"
print "   （此脚本没有动这些文件）"
print ""
print "🔄 现在可以重启 Antigravity IDE 了。"
print "   IDE 会重建状态数据库，历史会话应该能正常加载。"
print "══════════════════════════════════════════════════════"
