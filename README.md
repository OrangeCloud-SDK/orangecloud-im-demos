# Live SignalR IM SDK - 测试 Demo

四端 IM SDK 的测试 Demo 集合，用于测试 SDK 功能、在线体验和源码学习。

## 项目结构

```
clients/demos/
├── web/                    # Web Demo（浏览器在线测试）
├── flutter/                # Flutter Demo（移动端测试）
│   └── live_signalr_demo/
├── ios/                    # iOS Demo（命令行测试）
│   └── LiveSignalRDemo/
└── android/                # Android Demo（命令行测试）
    └── live-signalr-demo/
```

## 功能覆盖

每个 Demo 都覆盖以下 SDK 功能：

| 功能 | Web | Flutter | iOS | Android |
|------|-----|---------|-----|---------|
| 登录连接 (login) | ✅ | ✅ | ✅ | ✅ |
| 断开连接 (logout) | ✅ | ✅ | ✅ | ✅ |
| 加入房间 (joinGroup) | ✅ | ✅ | ✅ | ✅ |
| 离开房间 (quitGroup) | ✅ | ✅ | ✅ | ✅ |
| 发送聊天消息 (public_msg) | ✅ | ✅ | ✅ | ✅ |
| 发送礼物 (SEND_GIFT) | ✅ | ✅ | ✅ | ✅ |
| 发送大礼物 (SEND_BIG_GIFT) | ✅ | ❌ | ❌ | ❌ |
| 发送弹幕 (SEND_BARRAGE) | ✅ | ✅ | ✅ | ✅ |
| 系统公告 (ANotice) | ✅ | ✅ | ✅ | ✅ |
| 关播通知 (stop_live) | ✅ | ❌ | ❌ | ❌ |
| 接收消息解析 | ✅ | ✅ | ✅ | ✅ |
| 用户加入/离开通知 | ✅ | ✅ | ✅ | ✅ |
| 在线人数变化 | ✅ | ✅ | ✅ | ✅ |
| 禁言/解禁事件 | ✅ | ✅ | ✅ | ✅ |
| 连接状态监控 | ✅ | ✅ | ✅ | ✅ |
| 自动重连 | ✅ | ✅ | ✅ | ✅ |
| 获取成员列表 | ✅ | ❌ | ✅ | ✅ |

---

## Web Demo

最适合在线测试和快速体验，提供完整的聊天室 UI。

### 运行方式

```bash
cd clients/demos/web
npm install
npm run dev
```

浏览器打开 `http://localhost:3000`。

### 特点
- 完整的聊天室 UI（消息列表、用户列表、输入框）
- 快捷测试按钮（礼物、弹幕、公告、关播）
- 实时 SDK 日志面板
- 连接状态指示器
- 响应式布局，支持移动端浏览器

---

## Flutter Demo

移动端测试 Demo，可在 iOS/Android 设备上运行。

### 运行方式

```bash
cd clients/demos/flutter/live_signalr_demo
flutter pub get
flutter run
```

### 特点
- Material 3 设计风格
- 可折叠的连接配置面板
- 消息类型颜色区分
- 快捷操作 Chip
- 侧边抽屉查看 SDK 日志

---

## iOS Demo

命令行测试 Demo，使用 Swift Package Manager。

### 运行方式

```bash
cd clients/demos/ios/LiveSignalRDemo
swift run LiveSignalRDemo
```

### 特点
- 自动执行完整测试流程（连接→加入→发消息→送礼→弹幕→公告→获取成员）
- 交互模式支持手动输入命令
- 完整的消息解析和展示
- Delegate 回调演示

### 交互命令
```
send <消息>  - 发送聊天消息
gift         - 发送礼物
leave        - 离开房间
quit         - 退出程序
```

---

## Android Demo

命令行测试 Demo，使用 Kotlin + Gradle。

### 运行方式

```bash
./gradlew :clients:demos:android:live-signalr-demo:run
```

### 特点
- 与 iOS Demo 功能对等
- 自动执行完整测试流程
- 交互模式支持手动输入命令
- Listener 接口回调演示

### 交互命令
```
send <消息>  - 发送聊天消息
gift         - 发送礼物
leave        - 离开房间
quit         - 退出程序
```

---

## 消息格式参考

### 聊天消息 (public_msg)
```json
{
  "Type": "public_msg",
  "data": {
    "content": { "word": "消息内容" },
    "user_info": {
      "uid": "用户ID",
      "nick": "昵称",
      "avatar": "头像URL",
      "level": "等级",
      "isAdmin": "0",
      "isAnchor": "0"
    }
  }
}
```

### 礼物消息 (SEND_GIFT / SEND_BIG_GIFT)
```json
{
  "MsgId": "GUID",
  "Type": "SEND_GIFT",
  "GiftInfo": {
    "Id": 1, "Name": "小星星", "CNName": "小星星",
    "Profit": 10, "Price": 20, "Count": 1
  },
  "UserInfo": {
    "UserId": 1, "IMUserId": "用户ID", "NickName": "昵称"
  },
  "AnchorInfo": {
    "UserId": 100, "IMUserId": "主播ID", "NickName": "主播昵称"
  }
}
```

### 弹幕消息 (SEND_BARRAGE)
```json
{
  "MsgId": "GUID",
  "Type": "SEND_BARRAGE",
  "GiftInfo": {
    "Id": 0, "Name": "弹幕", "Message": "弹幕内容",
    "Profit": 1, "Price": 2, "Count": 1
  },
  "UserInfo": { "UserId": 1, "IMUserId": "用户ID", "NickName": "昵称" },
  "AnchorInfo": { "UserId": 100, "IMUserId": "主播ID", "NickName": "主播昵称" }
}
```

### 系统公告 (ANotice)
```json
{
  "Type": "ANotice",
  "data": { "IsShow": true, "Notice": "公告内容" }
}
```

### 关播通知 (stop_live)
```json
{
  "Type": "stop_live",
  "data": { "is_forbidden": "0", "uid": "主播ID" }
}
```

---

## SDK API 速查

四端 SDK 提供统一的 API 接口：

| 方法 | 说明 | 参数 |
|------|------|------|
| `login` | 建立 SignalR 连接 | hubUrl, appId, userId, userSig |
| `logout` | 断开连接 | - |
| `joinGroup` | 加入房间 | groupId |
| `quitGroup` | 离开房间 | groupId |
| `sendGroupMsg` | 发送消息 | groupId, messageJson |
| `getGroupMemberList` | 获取成员列表 | groupId |

### 事件回调

| 事件 | 说明 | 回调参数 |
|------|------|----------|
| ReceiveMessage | 收到消息 | messageJson |
| UserJoined | 用户加入 | userInfoJson |
| UserLeft | 用户离开 | userKey |
| OnlineCountChanged | 在线人数变化 | count |
| OnMuted | 被禁言 | muteInfoJson |
| OnUnmuted | 被解禁 | userKey |
| RoomClosed | 房间关闭 | - |
| ConnectionStateChanged | 连接状态变化 | state |

### 连接状态

| 状态 | 说明 |
|------|------|
| connecting | 连接中 |
| connected | 已连接 |
| disconnected | 已断开 |
| reconnecting | 重连中（自动重连延迟: 0s, 2s, 10s, 30s） |
