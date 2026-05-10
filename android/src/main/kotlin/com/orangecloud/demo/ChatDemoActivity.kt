package com.orangecloud.demo

import com.orangecloud.im.ConnectionState
import com.orangecloud.im.IMMessageType
import com.orangecloud.im.OrangeCloudIMClient
import com.orangecloud.im.OrangeCloudIMClientListener
import org.json.JSONObject
import java.util.UUID

/**
 * OrangeCloud IM SDK - Android Activity Demo (伪代码)
 *
 * 演示如何在 Android Activity 中集成 OrangeCloudIMClient。
 * 此文件为参考代码，展示 Activity 中的集成模式。
 * 实际使用时需要配合 Android 项目的 layout XML。
 *
 * 关键集成点：
 * 1. 在 onCreate 中初始化 client 并设置 listener
 * 2. 在 onDestroy 中调用 dispose() 释放资源
 * 3. 使用 runOnUiThread 更新 UI
 * 4. 所有网络操作在后台线程执行
 */

/*
// ============================================================
// 以下为 Activity 集成示例代码（需要 Android 项目环境）
// ============================================================

class ChatDemoActivity : AppCompatActivity(), OrangeCloudIMClientListener {

    private lateinit var client: OrangeCloudIMClient
    private val messages = mutableListOf<ChatMessage>()
    private var currentRoomId: String? = null

    // 配置参数
    private val hubUrl = "https://signalr.example.com/hubs/live"
    private val appId = "demo_app"
    private val userId = "android_${(1000..9999).random()}"
    private val userSig = "demo_sig"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_chat_demo)

        // 初始化 SDK
        client = OrangeCloudIMClient()
        client.listener = this

        // 绑定 UI 事件
        findViewById<Button>(R.id.btnLogin).setOnClickListener { doLogin() }
        findViewById<Button>(R.id.btnLogout).setOnClickListener { doLogout() }
        findViewById<Button>(R.id.btnJoinRoom).setOnClickListener { doJoinRoom() }
        findViewById<Button>(R.id.btnLeaveRoom).setOnClickListener { doLeaveRoom() }
        findViewById<Button>(R.id.btnSend).setOnClickListener { doSendChat() }
        findViewById<Button>(R.id.btnGift).setOnClickListener { doSendGift() }
    }

    override fun onDestroy() {
        super.onDestroy()
        // 释放 SDK 资源
        client.dispose()
    }

    // ============================================================
    // 操作方法
    // ============================================================

    private fun doLogin() {
        Thread {
            client.login(hubUrl, appId, userId, userSig)
        }.start()
    }

    private fun doLogout() {
        Thread {
            client.logout()
            runOnUiThread {
                currentRoomId = null
                updateUI()
            }
        }.start()
    }

    private fun doJoinRoom() {
        val roomId = findViewById<EditText>(R.id.etRoomId).text.toString().trim()
        if (roomId.isEmpty()) return
        client.joinGroup(roomId)
        currentRoomId = roomId
        addMessage("已加入房间 $roomId", ChatMsgType.JOIN)
    }

    private fun doLeaveRoom() {
        currentRoomId?.let { room ->
            client.quitGroup(room)
            currentRoomId = null
            addMessage("已离开房间", ChatMsgType.LEAVE)
        }
    }

    private fun doSendChat() {
        val room = currentRoomId ?: return
        val text = findViewById<EditText>(R.id.etMessage).text.toString().trim()
        if (text.isEmpty()) return

        val msg = JSONObject().apply {
            put("Type", IMMessageType.PUBLIC_MSG)
            put("data", JSONObject().apply {
                put("content", JSONObject().put("word", text))
                put("user_info", JSONObject().apply {
                    put("uid", userId)
                    put("nick", "Android用户")
                    put("avatar", "")
                    put("level", "1")
                    put("isAdmin", "0")
                    put("isAnchor", "0")
                })
            })
        }
        client.sendGroupMsg(room, msg.toString())
        findViewById<EditText>(R.id.etMessage).text.clear()
    }

    private fun doSendGift() {
        val room = currentRoomId ?: return
        val msg = JSONObject().apply {
            put("MsgId", UUID.randomUUID().toString())
            put("Type", IMMessageType.SEND_GIFT)
            put("GiftInfo", JSONObject().apply {
                put("Id", 1); put("Name", "小星星"); put("CNName", "小星星")
                put("Profit", 10); put("Price", 20); put("Count", 1)
            })
            put("UserInfo", JSONObject().apply {
                put("UserId", 1); put("IMUserId", userId); put("NickName", "Android用户")
            })
            put("AnchorInfo", JSONObject().apply {
                put("UserId", 100); put("IMUserId", "anchor_001"); put("NickName", "主播")
            })
        }
        client.sendGroupMsg(room, msg.toString())
    }

    // ============================================================
    // OrangeCloudIMClientListener 回调
    // ============================================================

    override fun onMessageReceived(messageJson: String) {
        runOnUiThread {
            try {
                val msg = JSONObject(messageJson)
                when (msg.optString("Type")) {
                    IMMessageType.PUBLIC_MSG -> {
                        val nick = msg.optJSONObject("data")
                            ?.optJSONObject("user_info")
                            ?.optString("nick", "匿名") ?: "匿名"
                        val word = msg.optJSONObject("data")
                            ?.optJSONObject("content")
                            ?.optString("word", "") ?: ""
                        addMessage("$nick: $word", ChatMsgType.CHAT)
                    }
                    IMMessageType.SEND_GIFT, IMMessageType.SEND_BIG_GIFT -> {
                        val sender = msg.optJSONObject("UserInfo")?.optString("NickName", "匿名") ?: "匿名"
                        val gift = msg.optJSONObject("GiftInfo")?.optString("CNName", "礼物") ?: "礼物"
                        addMessage("🎁 $sender 送出 $gift", ChatMsgType.GIFT)
                    }
                    IMMessageType.SEND_BARRAGE -> {
                        val sender = msg.optJSONObject("UserInfo")?.optString("NickName", "匿名") ?: "匿名"
                        val text = msg.optJSONObject("GiftInfo")?.optString("Message", "弹幕") ?: "弹幕"
                        addMessage("💬 $sender: $text", ChatMsgType.BARRAGE)
                    }
                    IMMessageType.A_NOTICE -> {
                        val notice = msg.optJSONObject("data")?.optString("Notice", "公告") ?: "公告"
                        addMessage("📢 $notice", ChatMsgType.NOTICE)
                    }
                    IMMessageType.STOP_LIVE -> {
                        addMessage("🔴 直播已结束", ChatMsgType.SYSTEM)
                    }
                }
            } catch (_: Exception) {}
        }
    }

    override fun onUserJoined(userInfoJson: String) {
        runOnUiThread { addMessage("👋 用户加入", ChatMsgType.JOIN) }
    }

    override fun onUserLeft(userKey: String) {
        runOnUiThread { addMessage("👋 $userKey 离开", ChatMsgType.LEAVE) }
    }

    override fun onOnlineCountChanged(count: Int) {
        runOnUiThread {
            findViewById<TextView>(R.id.tvOnlineCount).text = "在线: $count"
        }
    }

    override fun onMuted(muteInfoJson: String) {
        runOnUiThread { addMessage("⚠️ 你已被禁言", ChatMsgType.SYSTEM) }
    }

    override fun onUnmuted(userKey: String) {
        runOnUiThread { addMessage("✅ 已解除禁言", ChatMsgType.SYSTEM) }
    }

    override fun onRoomClosed() {
        runOnUiThread {
            addMessage("🔴 房间已关闭", ChatMsgType.SYSTEM)
            currentRoomId = null
        }
    }

    override fun onConnectionStateChanged(state: ConnectionState) {
        runOnUiThread {
            val statusView = findViewById<TextView>(R.id.tvStatus)
            when (state) {
                ConnectionState.CONNECTING -> statusView.text = "连接中..."
                ConnectionState.CONNECTED -> statusView.text = "已连接"
                ConnectionState.DISCONNECTED -> statusView.text = "未连接"
                ConnectionState.RECONNECTING -> statusView.text = "重连中..."
            }
        }
    }

    // ============================================================
    // UI 辅助
    // ============================================================

    private fun addMessage(text: String, type: ChatMsgType) {
        messages.add(ChatMessage(text, type, System.currentTimeMillis()))
        // adapter.notifyItemInserted(messages.size - 1)
        // recyclerView.scrollToPosition(messages.size - 1)
        updateUI()
    }

    private fun updateUI() {
        // 更新 RecyclerView adapter
    }
}

enum class ChatMsgType { CHAT, GIFT, BARRAGE, NOTICE, JOIN, LEAVE, SYSTEM, ERROR }
data class ChatMessage(val text: String, val type: ChatMsgType, val timestamp: Long)
*/
