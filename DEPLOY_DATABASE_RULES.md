# 部署 Firebase Database Rules 指南

## 📋 前置条件

1. 已安装 Firebase CLI（如果没有，运行：`npm install -g firebase-tools`）
2. 有 Firebase 项目访问权限

---

## 🚀 部署步骤

### 方法 1: 命令行部署（推荐）

#### 1. 打开终端，进入项目目录
```bash
cd /Users/lizihao/Desktop/Modo-ai/modo-firebase-functions
```

#### 2. 登录 Firebase（如果还没登录）
```bash
firebase login
```
- 会打开浏览器进行登录
- 选择你的 Google 账号
- 授权 Firebase CLI

#### 3. 检查当前项目
```bash
firebase use
```
- 应该显示你的项目名称
- 如果不是正确的项目，运行：`firebase use <project-id>`

#### 4. 部署 Database Rules
```bash
firebase deploy --only database
```

#### 5. 验证部署
- 登录 [Firebase Console](https://console.firebase.google.com/)
- 选择你的项目
- 进入 **Realtime Database** > **Rules**
- 检查规则是否更新

---

### 方法 2: Firebase Console 手动更新

#### 1. 登录 Firebase Console
访问：https://console.firebase.google.com/

#### 2. 选择项目
选择 Modo 项目

#### 3. 进入 Database Rules
- 左侧菜单：**Build** > **Realtime Database**
- 点击顶部的 **Rules** 标签

#### 4. 复制新规则
打开文件：`/Users/lizihao/Desktop/Modo-ai/modo-firebase-functions/database.rules.json`

复制内容（从 `{` 到 `}`，包括所有内容）

#### 5. 粘贴并发布
- 在 Firebase Console 中，删除旧规则
- 粘贴新规则
- 点击 **Publish** 按钮
- 确认发布

---

## ✅ 验证部署成功

### 1. 检查 Console
在 Firebase Console 的 Rules 页面，你应该看到：
```json
{
  "rules": {
    "users": {
      "$userId": {
        ".read": "$userId === auth.uid",
        ".write": "$userId === auth.uid",
        
        "profile": {
          ".validate": "newData.hasChildren(['createdAt'])"
        },
        
        "tasks": {
          "$dateKey": {
            ".validate": "$dateKey.matches(/^\\d{4}-\\d{2}-\\d{2}$/)",
            // ... 更多验证规则
          }
        }
      }
    }
  }
}
```

### 2. 测试 App
- 打开 Modo App
- 尝试创建/更新任务
- 检查是否正常工作
- 检查 Xcode Console，应该没有权限错误

---

## 🔧 常见问题

### 问题 1: `firebase: command not found`
**解决方案**：
```bash
# 重新安装 Firebase CLI
npm install -g firebase-tools

# 或者使用 npx
npx firebase-tools deploy --only database
```

### 问题 2: 权限错误
**解决方案**：
```bash
# 重新登录
firebase logout
firebase login
```

### 问题 3: 项目未选择
**解决方案**：
```bash
# 列出所有项目
firebase projects:list

# 选择项目
firebase use <project-id>
```

### 问题 4: Rules 验证失败
**检查**：
- JSON 格式是否正确（没有多余的逗号）
- 正则表达式是否正确转义（`\\d` 而不是 `\d`）
- 引号是否配对

---

## 📝 新 Rules 的改进

相比旧规则，新规则增加了：

1. **日期格式验证**
   - 确保日期键格式为 `YYYY-MM-DD`

2. **必须字段验证**
   - Task 必须包含：id, title, time, category, isDone, createdAt

3. **字段类型验证**
   - `title`: String，长度 1-200
   - `category`: 只能是 3 个预定义值
   - `isDone`: Boolean
   - `createdAt`/`updatedAt`: Number, <= now

4. **数据完整性**
   - 防止提交无效数据
   - 防止时间戳造假

---

## ⚠️ 回滚步骤（如果需要）

如果新规则导致问题，可以快速回滚：

### 旧规则（简单版本）
```json
{
  "rules": {
    "users": {
      "$userId": {
        ".read": "$userId === auth.uid",
        ".write": "$userId === auth.uid"
      }
    }
  }
}
```

在 Firebase Console 中：
1. 复制上面的旧规则
2. 粘贴到 Rules 编辑器
3. 点击 **Publish**

---

## 📞 需要帮助？

如果遇到问题：
1. 检查 Firebase Console 的错误消息
2. 查看 Xcode Console 的日志
3. 确认用户已登录（Firebase Auth）
4. 测试简单的读写操作

---

**最后更新**: 2024-11-17  
**版本**: 1.0

