/**
 * OrangeCloud IM SDK - Web Demo
 * 
 * 演示如何使用 @orangecloud/im-client 进行：
 * 1. 连接/断开 SignalR Hub
 * 2. 加入/离开房间
 * 3. 发送/接收聊天消息
 * 4. 发送/接收礼物消息
 * 5. 发送/接收弹幕
 * 6. 系统公告
 * 7. 关播通知
 * 8. 在线用户管理
 * 9. 禁言/解禁事件
 * 10. 连接状态监控与自动重连
 */

import { OrangeCloudIMClient, IMMessageType } from '@orangecloud/im-client';

// ============================================================
// 全局状态
// ============================================================
let client = null;
let currentRoomId = null;
let currentUserId = null;
let currentNickName = null;
let onlineUsers = [];

// ============================================================
// 工具函数
// ============================================================
function generateId() {
  return "user_" + Math.random().toString(36).substring(2, 8);
}

function timeStr() {
  return new Date().toLocaleTimeString("zh-CN", { hour12: false });
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// ============================================================
// UI 操作
// ============================================================
function addMessage(html, cls = "msg-system") {
  const list = document.getElementById("messageList");
  const item = document.createElement("div");
  item.className = `msg-item ${cls}`;
  item.innerHTML = html + `<span class="msg-time">${timeStr()}</span>`;
  list.appendChild(item);
  list.scrollTop = list.scrollHeight;
}

function addLog(text, cls = "") {
  const list = document.getElementById("logList");
  const item = document.createElement("div");
  item.className = `log-item ${cls}`;
  item.textContent = `[${timeStr()}] ${text}`;
  list.appendChild(item);
  list.scrollTop = list.scrollHeight;
  while (list.children.length > 200) list.removeChild(list.firstChild);
}

function updateStatus(state) {
  const dot = document.getElementById("statusDot");
  const text = document.getElementById("statusText");
  dot.className = `status-dot ${state}`;
  const labels = {
    disconnected: "未连接",
    connecting: "连接中...",
    connected: "已连接",
    reconnecting: "重连中...",
  };
  text.textContent = labels[state] || state;
}

function updateOnlineCount(count) {
  document.getElementById("onlineCount").textContent = `在线: ${count}`;
}

function updateUserList(users) {
  const list = document.getElementById("userList");
  if (!users || users.length === 0) {
    list.innerHTML = '<div style="text-align:center;color:#999;font-size:12px;padding:20px;">暂无用户</div>';
    return;
  }
  list.innerHTML = users
    .map((u) => {
      const badges = [];
      if (u.IsAdmin || u.isAdmin) badges.push('<span class="user-badge badge-admin">管理</span>');
      if (u.IsAnchor || u.isAnchor) badges.push('<span class="user-badge badge-anchor">主播</span>');
      const nick = u.NickName || u.nickName || u.UserKey || u.userKey || "匿名";
      const initial = nick.charAt(0).toUpperCase();
      return `<div class="user-item">
        <div class="user-avatar">${escapeHtml(initial)}</div>
        <span class="user-name">${escapeHtml(nick)}</span>
        ${badges.join("")}
      </div>`;
    })
    .join("");
}

function setRoomButtonsEnabled(enabled) {
  document.getElementById("btnJoin").disabled = !enabled;
  document.getElementById("btnLeave").disabled = !enabled;
  document.getElementById("btnMembers").disabled = !enabled;
  document.getElementById("msgInput").disabled = !enabled;
  document.getElementById("btnSend").disabled = !enabled;
  document.getElementById("btnGift").disabled = !enabled;
  document.getElementById("btnBigGift").disabled = !enabled;
  document.getElementById("btnBarrage").disabled = !enabled;
  document.getElementById("btnNotice").disabled = !enabled;
  document.getElementById("btnStop").disabled = !enabled;
}

// ============================================================
// 核心功能：登录连接
// ============================================================

window.doLogin = async function () {
  const hubUrl = document.getElementById("hubUrl").value.trim();
  const appId = document.getElementById("appId").value.trim();
  let userId = document.getElementById("userId").value.trim();
  const userSig = document.getElementById("userSig").value.trim();
  let nickName = document.getElementById("nickName").value.trim();

  if (!hubUrl) return alert("请输入 Hub URL");
  if (!appId) return alert("请输入 App ID");
  if (!userSig) return alert("请输入 UserSig（需通过业务API获取）");

  if (!userId) {
    userId = generateId();
    document.getElementById("userId").value = userId;
  }
  if (!nickName) {
    nickName = "用户" + userId.substring(userId.length - 4);
    document.getElementById("nickName").value = nickName;
  }

  currentUserId = userId;
  currentNickName = nickName;

  addLog(`正在连接 ${hubUrl} ...`, "log-info");
  updateStatus("connecting");

  client = new OrangeCloudIMClient({
    hubUrl,
    appId,
    userId,
    userSig,
  });

  // 注册服务端回调
  registerCallbacks();
  registerConnectionEvents();

  try {
    await client.connect();
    updateStatus("connected");
    addLog("✅ 连接成功", "log-info");
    addMessage("已连接到 IM Hub");

    document.getElementById("btnLogin").disabled = true;
    document.getElementById("btnLogout").disabled = false;
    setRoomButtonsEnabled(true);
  } catch (err) {
    updateStatus("disconnected");
    addLog(`❌ 连接失败: ${err.message}`, "log-error");
    addMessage(`连接失败: ${escapeHtml(err.message)}`, "msg-error");
  }
};

// ============================================================
// 核心功能：断开连接
// ============================================================
window.doLogout = async function () {
  if (client) {
    addLog("正在断开连接...", "log-info");
    await client.disconnect();
    client = null;
  }
  currentRoomId = null;
  onlineUsers = [];
  updateStatus("disconnected");
  updateOnlineCount(0);
  updateUserList([]);
  addMessage("已断开连接");
  addLog("已断开连接", "log-info");

  document.getElementById("btnLogin").disabled = false;
  document.getElementById("btnLogout").disabled = true;
  setRoomButtonsEnabled(false);
};

// ============================================================
// 核心功能：加入房间
// ============================================================
window.doJoinRoom = async function () {
  const roomId = document.getElementById("roomId").value.trim();
  if (!roomId) return alert("请输入房间ID");
  if (!client) return alert("请先连接");

  try {
    addLog(`加入房间: ${roomId}`, "log-send");
    await client.joinRoom(roomId);
    currentRoomId = roomId;
    addMessage(`你已加入房间 ${escapeHtml(roomId)}`, "msg-join");
    addLog(`✅ 已加入房间 ${roomId}`, "log-info");
  } catch (err) {
    addLog(`❌ 加入房间失败: ${err.message}`, "log-error");
    addMessage(`加入房间失败: ${escapeHtml(err.message)}`, "msg-error");
  }
};

// ============================================================
// 核心功能：离开房间
// ============================================================
window.doLeaveRoom = async function () {
  if (!currentRoomId || !client) return;

  try {
    addLog(`离开房间: ${currentRoomId}`, "log-send");
    await client.leaveRoom(currentRoomId);
    addMessage(`你已离开房间 ${escapeHtml(currentRoomId)}`, "msg-leave");
    addLog(`✅ 已离开房间`, "log-info");
    currentRoomId = null;
    onlineUsers = [];
    updateOnlineCount(0);
    updateUserList([]);
  } catch (err) {
    addLog(`❌ 离开房间失败: ${err.message}`, "log-error");
  }
};

// ============================================================
// 核心功能：获取成员列表
// ============================================================
window.doGetMembers = async function () {
  if (!currentRoomId || !client) return;
  try {
    addLog(`获取成员列表: ${currentRoomId}`, "log-send");
    await client.getMembers(currentRoomId);
  } catch (err) {
    addLog(`❌ 获取成员失败: ${err.message}`, "log-error");
  }
};

// ============================================================
// 核心功能：发送聊天消息
// ============================================================
window.doSendChat = async function () {
  const input = document.getElementById("msgInput");
  const text = input.value.trim();
  if (!text || !currentRoomId || !client) return;

  const msgData = {
    Type: IMMessageType.publicMsg,
    data: {
      content: { word: text },
      user_info: {
        uid: currentUserId,
        nick: currentNickName,
        avatar: "",
        level: "1",
        isAdmin: "0",
        isAnchor: "0",
        isOfficial: "0",
        gender: "男",
      },
    },
  };

  try {
    addLog(`发送消息: ${text}`, "log-send");
    await client.sendMessage(currentRoomId, msgData);
    input.value = "";
  } catch (err) {
    addLog(`❌ 发送失败: ${err.message}`, "log-error");
    addMessage(`发送失败: ${escapeHtml(err.message)}`, "msg-error");
  }
};

// ============================================================
// 快捷测试：送礼物
// ============================================================
window.doSendGift = async function () {
  if (!currentRoomId || !client) return;

  const giftMsg = {
    MsgId: crypto.randomUUID(),
    Type: IMMessageType.sendGift,
    GiftInfo: {
      Id: 1, Name: "小星星", CNName: "小星星", TWName: "小星星",
      USName: "Little Star", VNName: "Ngôi sao nhỏ",
      Profit: 10, Price: 20, Count: 1,
    },
    UserInfo: {
      UserId: 1, IMUserId: currentUserId, NickName: currentNickName,
      FaceUrl: "", Sex: "男", IsAdmin: false, IsAnchor: false,
    },
    AnchorInfo: {
      UserId: 100, IMUserId: "anchor_001", NickName: "主播小姐姐",
      FaceUrl: "", LiveLevel: "5", UserLevel: "3",
    },
  };

  try {
    addLog("发送礼物: 小星星 x1", "log-send");
    await client.sendMessage(currentRoomId, giftMsg);
  } catch (err) {
    addLog(`❌ 送礼失败: ${err.message}`, "log-error");
  }
};

// ============================================================
// 快捷测试：大礼物
// ============================================================
window.doSendBigGift = async function () {
  if (!currentRoomId || !client) return;

  const giftMsg = {
    MsgId: crypto.randomUUID(),
    Type: IMMessageType.sendBigGift,
    GiftInfo: {
      Id: 99, Name: "火箭", CNName: "火箭", TWName: "火箭",
      USName: "Rocket", VNName: "Tên lửa",
      Profit: 5000, Price: 9999, Count: 1,
    },
    UserInfo: {
      UserId: 1, IMUserId: currentUserId, NickName: currentNickName,
      FaceUrl: "", Sex: "男", IsAdmin: false, IsAnchor: false,
    },
    AnchorInfo: {
      UserId: 100, IMUserId: "anchor_001", NickName: "主播小姐姐",
      FaceUrl: "", LiveLevel: "5", UserLevel: "3",
    },
  };

  try {
    addLog("发送大礼物: 火箭 🚀", "log-send");
    await client.sendMessage(currentRoomId, giftMsg);
  } catch (err) {
    addLog(`❌ 送礼失败: ${err.message}`, "log-error");
  }
};

// ============================================================
// 快捷测试：弹幕
// ============================================================
window.doSendBarrage = async function () {
  if (!currentRoomId || !client) return;

  const barrageMsg = {
    MsgId: crypto.randomUUID(),
    Type: IMMessageType.sendBarrage,
    GiftInfo: {
      Id: 0, Name: "弹幕", Message: "这是一条弹幕消息 🎉",
      Profit: 1, Price: 2, Count: 1,
    },
    UserInfo: {
      UserId: 1, IMUserId: currentUserId, NickName: currentNickName,
      FaceUrl: "", Sex: "男", IsAdmin: false, IsAnchor: false,
    },
    AnchorInfo: {
      UserId: 100, IMUserId: "anchor_001", NickName: "主播小姐姐",
    },
  };

  try {
    addLog("发送弹幕", "log-send");
    await client.sendMessage(currentRoomId, barrageMsg);
  } catch (err) {
    addLog(`❌ 弹幕失败: ${err.message}`, "log-error");
  }
};

// ============================================================
// 快捷测试：系统公告
// ============================================================
window.doSendNotice = async function () {
  if (!currentRoomId || !client) return;

  const noticeMsg = {
    Type: IMMessageType.aNotice,
    data: { IsShow: true, Notice: "这是一条系统公告测试消息" },
  };

  try {
    addLog("发送系统公告", "log-send");
    await client.sendMessage(currentRoomId, noticeMsg);
  } catch (err) {
    addLog(`❌ 公告失败: ${err.message}`, "log-error");
  }
};

// ============================================================
// 快捷测试：关播通知
// ============================================================
window.doSendStopLive = async function () {
  if (!currentRoomId || !client) return;

  const stopMsg = {
    Type: IMMessageType.stopLive,
    data: { is_forbidden: "0", uid: currentUserId },
  };

  try {
    addLog("发送关播通知", "log-send");
    await client.sendMessage(currentRoomId, stopMsg);
  } catch (err) {
    addLog(`❌ 关播失败: ${err.message}`, "log-error");
  }
};

// ============================================================
// 注册服务端回调
// ============================================================
function registerCallbacks() {
  client.on("ReceiveMessage", (messageJson) => {
    addLog(`收到消息: ${messageJson.substring(0, 100)}...`, "log-recv");
    try {
      const msg = JSON.parse(messageJson);
      handleMessage(msg);
    } catch {
      addMessage(`收到原始消息: ${escapeHtml(messageJson)}`, "msg-chat");
    }
  });

  client.on("UserJoined", (userInfoJson) => {
    addLog(`用户加入: ${userInfoJson}`, "log-recv");
    try {
      const user = JSON.parse(userInfoJson);
      const nick = user.NickName || user.UserKey || "匿名";
      addMessage(`${escapeHtml(nick)} 进入了房间 👋`, "msg-join");
      if (!onlineUsers.find((u) => (u.UserKey || u.userKey) === (user.UserKey || user.userKey))) {
        onlineUsers.push(user);
        updateUserList(onlineUsers);
      }
    } catch {
      addMessage(`用户加入: ${escapeHtml(userInfoJson)}`, "msg-join");
    }
  });

  client.on("UserLeft", (userKey) => {
    addLog(`用户离开: ${userKey}`, "log-recv");
    const idx = onlineUsers.findIndex((u) => (u.UserKey || u.userKey) === userKey);
    let nick = userKey;
    if (idx >= 0) {
      nick = onlineUsers[idx].NickName || onlineUsers[idx].nickName || userKey;
      onlineUsers.splice(idx, 1);
      updateUserList(onlineUsers);
    }
    addMessage(`${escapeHtml(nick)} 离开了房间 👋`, "msg-leave");
  });

  client.on("OnlineCountChanged", (count) => {
    addLog(`在线人数: ${count}`, "log-recv");
    updateOnlineCount(count);
  });

  client.on("OnMuted", (muteInfoJson) => {
    addLog(`被禁言: ${muteInfoJson}`, "log-recv");
    addMessage("⚠️ 你已被禁言", "msg-mute");
  });

  client.on("OnUnmuted", (userKey) => {
    addLog(`被解禁: ${userKey}`, "log-recv");
    addMessage("✅ 你已被解除禁言", "msg-join");
  });

  client.on("RoomClosed", () => {
    addLog("房间已关闭", "log-recv");
    addMessage("🔴 房间已关闭", "msg-system");
    currentRoomId = null;
  });

  client.on("Error", (message) => {
    addLog(`错误: ${message}`, "log-error");
    addMessage(`❌ ${escapeHtml(message)}`, "msg-error");
  });
}

// ============================================================
// 注册连接事件
// ============================================================
function registerConnectionEvents() {
  client.on("disconnected", () => {
    updateStatus("disconnected");
    addLog("连接已关闭", "log-error");
  });

  client.on("reconnecting", () => {
    updateStatus("reconnecting");
    addLog("正在重连...", "log-info");
    addMessage("正在重连...", "msg-system");
  });

  client.on("reconnected", () => {
    updateStatus("connected");
    addLog("✅ 重连成功", "log-info");
    addMessage("重连成功", "msg-system");
    if (currentRoomId) {
      client.joinRoom(currentRoomId).catch(() => {});
      addLog(`重连后自动加入房间: ${currentRoomId}`, "log-info");
    }
  });
}

// ============================================================
// 消息解析与展示
// ============================================================
function handleMessage(msg) {
  const type = msg.Type || msg.type;

  switch (type) {
    case IMMessageType.publicMsg: {
      const nick = msg.data?.user_info?.nick || "匿名";
      const word = msg.data?.content?.word || "";
      addMessage(
        `<span class="msg-nick">${escapeHtml(nick)}</span>${escapeHtml(word)}`,
        "msg-chat"
      );
      break;
    }

    case IMMessageType.sendGift: {
      const sender = msg.UserInfo?.NickName || "匿名";
      const giftName = msg.GiftInfo?.CNName || msg.GiftInfo?.Name || "礼物";
      const count = msg.GiftInfo?.Count || 1;
      addMessage(
        `<span class="gift-icon">🎁</span>${escapeHtml(sender)} 送出 ${escapeHtml(giftName)} x${count}`,
        "msg-gift"
      );
      break;
    }

    case IMMessageType.sendBigGift: {
      const sender = msg.UserInfo?.NickName || "匿名";
      const giftName = msg.GiftInfo?.CNName || msg.GiftInfo?.Name || "大礼物";
      const count = msg.GiftInfo?.Count || 1;
      addMessage(
        `<span class="gift-icon">🎆</span>${escapeHtml(sender)} 送出 ${escapeHtml(giftName)} x${count} 🚀`,
        "msg-gift"
      );
      break;
    }

    case IMMessageType.sendBarrage: {
      const sender = msg.UserInfo?.NickName || "匿名";
      const text = msg.GiftInfo?.Message || "弹幕";
      addMessage(
        `💬 ${escapeHtml(sender)}: ${escapeHtml(text)}`,
        "msg-barrage"
      );
      break;
    }

    case IMMessageType.aNotice: {
      const notice = msg.data?.Notice || "系统公告";
      addMessage(`📢 ${escapeHtml(notice)}`, "msg-notice");
      break;
    }

    case IMMessageType.stopLive: {
      addMessage("🔴 直播已结束", "msg-system");
      break;
    }

    default:
      addMessage(`未知消息类型 [${escapeHtml(type || "null")}]: ${JSON.stringify(msg).substring(0, 100)}`, "msg-system");
  }
}
