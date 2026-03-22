# Rime User Dictionary Sync

This directory is managed by Rime's built-in sync mechanism.

When you trigger "Sync User Data" in Fcitx5's Rime menu, user dictionaries
(`*.userdb.txt`) are exported here as plaintext files.

These files contain learned words with their pinyin and usage frequency.
They do **not** contain full sentences.

## Cross-machine sync

1. On the source machine: Rime menu → "Sync User Data"
2. `git add rime-sync/ && git commit -m "sync rime user dict" && git push`
3. On the target machine: `git pull`, then Rime menu → "Sync User Data"
