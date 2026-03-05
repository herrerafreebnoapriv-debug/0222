# 比对本机与服务器 0222 源码是否一致

比较 **api、admin-test-UI、deploy** 三个目录下的文件列表和文件大小。连接远程：`ssh root@89.223.95.18`。

---

## 步骤一：本机生成清单

在 **PowerShell** 项目根目录执行（会生成 `deploy/local-list.txt`）：

```powershell
cd c:\Users\robot\Documents\0222
Get-ChildItem -Path api, admin-test-UI, deploy -Recurse -File | ForEach-Object { $rel = $_.FullName.Replace((Get-Location).Path + '\', '').Replace('\','/'); "$($_.Length) $rel" } | Sort-Object | Set-Content -Path deploy/local-list.txt -Encoding UTF8
```

（本机已生成过可跳过。）

---

## 步骤二：远程机生成清单并拷回本机

1. 连接远程：`ssh root@89.223.95.18`
2. 在远程执行（生成 `deploy/remote-list.txt`）：

```bash
cd /opt/0222 && find api admin-test-UI deploy -type f -exec stat -c '%s %n' {} \; | sed 's|/opt/0222/||' | sort > deploy/remote-list.txt
```

3. 在本机 **Git Bash** 把远程文件拷到本机 `deploy/`：

```bash
cd /c/Users/robot/Documents/0222
scp root@89.223.95.18:/opt/0222/deploy/remote-list.txt deploy/
```

---

## 步骤三：比对

本机 **PowerShell** 项目根目录执行：

```powershell
cd c:\Users\robot\Documents\0222
.\deploy\compare-with-remote.ps1
```

或本机 **Git Bash** 执行：

```bash
cd /c/Users/robot/Documents/0222
diff deploy/local-list.txt deploy/remote-list.txt
```

- **无输出**：两边一致。
- **有输出**：仅本机有 / 仅远程有 / 大小不同的文件。
