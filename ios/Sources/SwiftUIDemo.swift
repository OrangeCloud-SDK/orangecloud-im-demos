import Foundation
import OrangeCloudIMClient

#if canImport(SwiftUI)
import SwiftUI

// ============================================================
// OrangeCloud IM SDK - iOS SwiftUI Demo
//
// 在 SwiftUI App 中集成 OrangeCloudIMClient 的完整示例。
// 可直接复制到 Xcode 项目中使用。
// ============================================================

/// ViewModel：封装 OCIMClient 的所有交互逻辑
@MainActor
class ChatViewModel: ObservableObject {
    private let client = OCIMClient()
    private var delegateHandler: ChatDelegateHandler?

    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMsg] = []
    @Published var onlineCount: Int = 0
    @Published var logs: [String] = []

    // 配置
    @Published var hubUrl = "https://signalr.example.com/hubs/live"
    @Published var appId = "demo_app"
    @Published var userId = "ios_\(Int.random(in: 1000...9999))"
    @Published var userSig = "demo_sig"
    @Published var roomId = "test_room_001"
    @Published var inputText = ""

    var isConnected: Bool { connectionState == .connected }
    var currentRoomId: String?

    init() {
        delegateHandler = ChatDelegateHandler(vm: self)
        client.delegate = delegateHandler
    }

    func login() {
        addLog("正在连接...")
        client.login(hubUrl: hubUrl, appId: appId, userId: userId, userSig: userSig)
    }

    func logout() {
        client.logout()
        currentRoomId = nil
        onlineCount = 0
        addMsg("已断开连接", type: .system)
    }

    func joinRoom() {
        guard !roomId.isEmpty else { return }
        client.joinGroup(roomId)
        currentRoomId = roomId
        addMsg("已加入房间 \(roomId)", type: .join)
    }

    func leaveRoom() {
        guard let room = currentRoomId else { return }
        client.quitGroup(room)
        currentRoomId = nil
        onlineCount = 0
        addMsg("已离开房间", type: .leave)
    }

    func sendChat() {
        guard let room = currentRoomId, !inputText.isEmpty else { return }
        let msg: [String: Any] = [
            "Type": IMMessageType.publicMsg,
            "data": [
                "content": ["word": inputText],
                "user_info": ["uid": userId, "nick": "iOS用户", "avatar": "", "level": "1", "isAdmin": "0", "isAnchor": "0"]
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: msg),
           let json = String(data: data, encoding: .utf8) {
            client.sendGroupMsg(groupId: room, messageJson: json)
            inputText = ""
        }
    }

    func sendGift() {
        guard let room = currentRoomId else { return }
        let msg: [String: Any] = [
            "MsgId": UUID().uuidString,
            "Type": IMMessageType.sendGift,
            "GiftInfo": ["Id": 1, "Name": "小星星", "CNName": "小星星", "Profit": 10, "Price": 20, "Count": 1],
            "UserInfo": ["UserId": 1, "IMUserId": userId, "NickName": "iOS用户"],
            "AnchorInfo": ["UserId": 100, "IMUserId": "anchor_001", "NickName": "主播"],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: msg),
           let json = String(data: data, encoding: .utf8) {
            client.sendGroupMsg(groupId: room, messageJson: json)
        }
    }

    func addMsg(_ text: String, type: ChatMsgType) {
        messages.append(ChatMsg(text: text, type: type, time: Date()))
    }

    func addLog(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        logs.append("[\(formatter.string(from: Date()))] \(text)")
        if logs.count > 200 { logs.removeFirst() }
    }
}

/// Delegate 处理器（桥接到 ViewModel）
class ChatDelegateHandler: OCIMClientDelegate {
    weak var vm: ChatViewModel?
    init(vm: ChatViewModel) { self.vm = vm }

    func didReceiveMessage(_ client: OCIMClient, messageJson: String) {
        Task { @MainActor in
            vm?.addLog("收到消息")
            guard let data = messageJson.data(using: .utf8),
                  let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = msg["Type"] as? String else { return }

            switch type {
            case IMMessageType.publicMsg:
                let nick = (msg["data"] as? [String: Any])?["user_info"]?["nick"] as? String ?? "匿名"
                let word = (msg["data"] as? [String: Any])?["content"]?["word"] as? String ?? ""
                vm?.addMsg("\(nick): \(word)", type: .chat)
            case IMMessageType.sendGift:
                let sender = (msg["UserInfo"] as? [String: Any])?["NickName"] as? String ?? "匿名"
                let gift = (msg["GiftInfo"] as? [String: Any])?["CNName"] as? String ?? "礼物"
                vm?.addMsg("🎁 \(sender) 送出 \(gift)", type: .gift)
            case IMMessageType.sendBarrage:
                let sender = (msg["UserInfo"] as? [String: Any])?["NickName"] as? String ?? "匿名"
                let text = (msg["GiftInfo"] as? [String: Any])?["Message"] as? String ?? "弹幕"
                vm?.addMsg("💬 \(sender): \(text)", type: .barrage)
            case IMMessageType.aNotice:
                let notice = (msg["data"] as? [String: Any])?["Notice"] as? String ?? "公告"
                vm?.addMsg("📢 \(notice)", type: .notice)
            case IMMessageType.stopLive:
                vm?.addMsg("🔴 直播已结束", type: .system)
            default:
                vm?.addMsg("未知消息: \(type)", type: .system)
            }
        }
    }

    func didUserJoin(_ client: OCIMClient, userInfoJson: String) {
        Task { @MainActor in vm?.addMsg("👋 用户加入", type: .join) }
    }

    func didUserLeave(_ client: OCIMClient, userKey: String) {
        Task { @MainActor in vm?.addMsg("👋 \(userKey) 离开", type: .leave) }
    }

    func didOnlineCountChange(_ client: OCIMClient, count: Int) {
        Task { @MainActor in vm?.onlineCount = count }
    }

    func didGetMuted(_ client: OCIMClient, muteInfoJson: String) {
        Task { @MainActor in vm?.addMsg("⚠️ 你已被禁言", type: .system) }
    }

    func didGetUnmuted(_ client: OCIMClient, userKey: String) {
        Task { @MainActor in vm?.addMsg("✅ 已解除禁言", type: .system) }
    }

    func didRoomClose(_ client: OCIMClient) {
        Task { @MainActor in vm?.addMsg("🔴 房间已关闭", type: .system) }
    }

    func didConnectionStateChange(_ client: OCIMClient, state: ConnectionState) {
        Task { @MainActor in
            vm?.connectionState = state
            vm?.addLog("连接状态: \(state.rawValue)")
        }
    }
}

/// 消息类型
enum ChatMsgType { case chat, gift, barrage, notice, join, leave, system, error }

/// 消息模型
struct ChatMsg: Identifiable {
    let id = UUID()
    let text: String
    let type: ChatMsgType
    let time: Date
}

// ============================================================
// SwiftUI 视图
// ============================================================

/// 聊天室主视图
struct ChatDemoView: View {
    @StateObject private var vm = ChatViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(vm.messages) { msg in
                                MessageRow(msg: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        if let last = vm.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // 快捷操作
                if vm.currentRoomId != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("🎁 礼物") { vm.sendGift() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }

                // 输入框
                HStack {
                    TextField("输入消息...", text: $vm.inputText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(vm.currentRoomId == nil)
                        .onSubmit { vm.sendChat() }
                    Button("发送") { vm.sendChat() }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.currentRoomId == nil || vm.inputText.isEmpty)
                }
                .padding(8)
            }
            .navigationTitle("OrangeCloud IM Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(vm.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(vm.isConnected ? "已连接" : "未连接")
                            .font(.caption)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vm.currentRoomId != nil {
                        Text("在线: \(vm.onlineCount)")
                            .font(.caption)
                    }
                }
            }
            .sheet(isPresented: .constant(false)) {
                // 连接配置 Sheet（可扩展）
            }
            .onAppear {
                // 可在此自动连接
            }
        }
    }
}

/// 消息行视图
struct MessageRow: View {
    let msg: ChatMsg

    var body: some View {
        HStack {
            Text(msg.text)
                .font(.system(size: 13))
                .foregroundColor(textColor)
            Spacer()
            Text(timeString)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bgColor)
        .cornerRadius(8)
    }

    private var bgColor: Color {
        switch msg.type {
        case .chat: return Color(.systemGray6)
        case .gift: return Color.pink.opacity(0.1)
        case .barrage: return Color.blue.opacity(0.1)
        case .notice: return Color.orange.opacity(0.1)
        case .join: return Color.green.opacity(0.1)
        case .leave: return Color.red.opacity(0.1)
        case .system: return Color.orange.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        }
    }

    private var textColor: Color {
        switch msg.type {
        case .chat: return .primary
        case .gift: return .pink
        case .barrage: return .blue
        case .notice: return .orange
        case .join: return .green
        case .leave: return .red
        case .system: return .orange
        case .error: return .red
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: msg.time)
    }
}

#endif
