import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:orangecloud_im_client/orangecloud_im_client.dart';

/// 聊天室 Demo 页面
///
/// 演示 OrangeCloudIMClient v1.0.0 全部功能：
/// - login / logout（连接管理）
/// - joinGroup / quitGroup（房间操作）
/// - sendTextMessage / sendGiftMessage / sendCustomMessage（类型安全发送）
/// - 类型安全事件流监听（TextMessage, GiftMessage, SystemNotice, CustomMessage）
/// - 可靠性：序列号、断线重连状态恢复、批量消息
class ChatDemoPage extends StatefulWidget {
  const ChatDemoPage({super.key});

  @override
  State<ChatDemoPage> createState() => _ChatDemoPageState();
}

class _ChatDemoPageState extends State<ChatDemoPage> {
  final OrangeCloudIMClient _client = OrangeCloudIMClient();
  final TextEditingController _hubUrlCtrl = TextEditingController(text: 'https://signalr.example.com/hubs/live');
  final TextEditingController _appIdCtrl = TextEditingController(text: 'demo_app');
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _userSigCtrl = TextEditingController(text: 'demo_sig');
  final TextEditingController _roomIdCtrl = TextEditingController(text: 'test_room_001');
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = [];
  final List<String> _logs = [];
  IMConnectionState _connState = IMConnectionState.disconnected;
  int _onlineCount = 0;
  String? _currentRoomId;
  String _userId = '';

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _userId = 'user_${Random().nextInt(9999).toString().padLeft(4, '0')}';
    _userIdCtrl.text = _userId;
    _setupListeners();
  }

  void _setupListeners() {
    // 连接状态
    _subs.add(_client.onConnectionStateChanged.listen((state) {
      setState(() => _connState = state);
      _addLog('连接状态: ${state.name}');
    }));

    // 类型安全消息监听
    _subs.add(_client.onTextMessageReceived.listen((msg) {
      _addLog('收到文本: ${msg.content}');
      _addMsg('${msg.senderInfo.nickName}: ${msg.content}', _MsgType.chat);
    }));

    _subs.add(_client.onGiftMessageReceived.listen((msg) {
      _addLog('收到礼物: ${msg.giftInfo.giftName}');
      _addMsg('🎁 ${msg.senderInfo.nickName} 送出 ${msg.giftInfo.giftName} x${msg.giftInfo.giftCount}', _MsgType.gift);
    }));

    _subs.add(_client.onSystemNoticeReceived.listen((msg) {
      _addLog('系统公告: ${msg.content}');
      _addMsg('📢 ${msg.content}', _MsgType.notice);
    }));

    _subs.add(_client.onCustomMessageReceived.listen((msg) {
      _addLog('自定义消息: ${msg.customType}');
      _addMsg('💬 [${msg.customType}] ${msg.payload}', _MsgType.barrage);
    }));

    // 广播消息（全服通知等）
    _subs.add(_client.onBroadcastReceived.listen((msg) {
      _addLog('广播: ${msg.messageTypeString}');
      _addMsg('📡 收到广播消息', _MsgType.system);
    }));

    // 批量消息（断线重连后补发）
    _subs.add(_client.onBatchMessageReceived.listen((messages) {
      _addLog('批量消息: ${messages.length} 条');
      _addMsg('📦 收到 ${messages.length} 条补发消息', _MsgType.system);
    }));

    // 状态恢复
    _subs.add(_client.onStateRestored.listen((info) {
      _addLog('状态恢复: ${info.restoredGroups}');
      _addMsg('✅ 连接恢复，已自动重新加入房间', _MsgType.system);
    }));

    // 重连尝试
    _subs.add(_client.onReconnectAttempt.listen((info) {
      _addLog('重连尝试 #${info.attempt}, 延迟 ${info.delayMs}ms');
    }));

    // 用户进出
    _subs.add(_client.onUserJoined.listen((json) {
      _addMsg('👋 用户加入', _MsgType.join);
    }));
    _subs.add(_client.onUserLeft.listen((key) {
      _addMsg('👋 $key 离开', _MsgType.leave);
    }));
    _subs.add(_client.onOnlineCountChanged.listen((count) {
      setState(() => _onlineCount = count);
    }));
    _subs.add(_client.onMuted.listen((_) {
      _addMsg('⚠️ 你已被禁言', _MsgType.system);
    }));
    _subs.add(_client.onUnmuted.listen((_) {
      _addMsg('✅ 已解除禁言', _MsgType.system);
    }));
    _subs.add(_client.onRoomClosed.listen((_) {
      _addMsg('🔴 房间已关闭', _MsgType.system);
      setState(() => _currentRoomId = null);
    }));
  }

  @override
  void dispose() {
    for (final sub in _subs) sub.cancel();
    _client.dispose();
    super.dispose();
  }

  void _addMsg(String text, _MsgType type) {
    setState(() => _messages.add(_ChatMessage(text: text, type: type, time: DateTime.now())));
    _scrollToBottom();
  }

  void _addLog(String text) {
    setState(() {
      _logs.add('[${_timeStr()}] $text');
      if (_logs.length > 200) _logs.removeAt(0);
    });
  }

  String _timeStr() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // === 操作方法 ===

  Future<void> _doLogin() async {
    _userId = _userIdCtrl.text.trim().isEmpty
        ? 'user_${Random().nextInt(9999).toString().padLeft(4, '0')}'
        : _userIdCtrl.text.trim();
    _userIdCtrl.text = _userId;
    try {
      await _client.login(_hubUrlCtrl.text.trim(), _appIdCtrl.text.trim(), _userId, _userSigCtrl.text.trim());
      _addMsg('已连接', _MsgType.system);
    } catch (e) {
      _addMsg('连接失败: $e', _MsgType.error);
    }
  }

  Future<void> _doLogout() async {
    await _client.logout();
    setState(() { _currentRoomId = null; _onlineCount = 0; });
    _addMsg('已断开', _MsgType.system);
  }

  Future<void> _doJoinRoom() async {
    final roomId = _roomIdCtrl.text.trim();
    if (roomId.isEmpty) return;
    try {
      await _client.joinGroup(roomId);
      setState(() => _currentRoomId = roomId);
      _addMsg('已加入房间 $roomId', _MsgType.join);
    } catch (e) {
      _addMsg('加入失败: $e', _MsgType.error);
    }
  }

  Future<void> _doLeaveRoom() async {
    if (_currentRoomId == null) return;
    await _client.quitGroup(_currentRoomId!);
    _addMsg('已离开房间', _MsgType.leave);
    setState(() { _currentRoomId = null; _onlineCount = 0; });
  }

  /// 使用新的类型安全 API 发送文本消息
  Future<void> _doSendChat() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _currentRoomId == null) return;
    try {
      await _client.sendTextMessage(_currentRoomId!, text);
      _msgCtrl.clear();
    } catch (e) {
      _addMsg('发送失败: $e', _MsgType.error);
    }
  }

  /// 使用新的类型安全 API 发送礼物
  Future<void> _doSendGift() async {
    if (_currentRoomId == null) return;
    try {
      await _client.sendGiftMessage(
        _currentRoomId!,
        GiftInfo(giftId: '1', giftName: '小星星', giftCount: 1, giftPrice: 20),
      );
    } catch (e) {
      _addMsg('送礼失败: $e', _MsgType.error);
    }
  }

  /// 使用新的类型安全 API 发送自定义消息（弹幕）
  Future<void> _doSendBarrage() async {
    if (_currentRoomId == null) return;
    try {
      await _client.sendCustomMessage(
        _currentRoomId!,
        'barrage',
        {'text': '这是一条弹幕 🎉', 'color': '#FF6600'},
      );
    } catch (e) {
      _addMsg('弹幕失败: $e', _MsgType.error);
    }
  }

  // === UI ===

  @override
  Widget build(BuildContext context) {
    final isConnected = _connState == IMConnectionState.connected;
    final inRoom = _currentRoomId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OrangeCloud IM Demo'),
        actions: [
          _buildStatusChip(),
          const SizedBox(width: 8),
          if (inRoom) Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(label: Text('在线: $_onlineCount'), visualDensity: VisualDensity.compact),
          ),
        ],
      ),
      body: Column(
        children: [
          ExpansionTile(
            title: const Text('🔌 连接配置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  _buildInput('Hub URL', _hubUrlCtrl),
                  _buildInput('App ID', _appIdCtrl),
                  _buildInput('User ID', _userIdCtrl, hint: '留空自动生成'),
                  _buildInput('User Sig', _userSigCtrl),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: FilledButton(onPressed: isConnected ? null : _doLogin, child: const Text('登录'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.tonal(onPressed: isConnected ? _doLogout : null, child: const Text('断开'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _buildInput('房间ID', _roomIdCtrl)),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: isConnected && !inRoom ? _doJoinRoom : null, child: const Text('加入')),
                    const SizedBox(width: 4),
                    OutlinedButton(onPressed: inRoom ? _doLeaveRoom : null, child: const Text('离开')),
                  ]),
                  const SizedBox(height: 12),
                ]),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _buildMessageItem(_messages[i]),
            ),
          ),
          if (inRoom)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                _quickBtn('🎁 礼物', _doSendGift),
                _quickBtn('💬 弹幕', _doSendBarrage),
              ]),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl, enabled: inRoom,
                    decoration: const InputDecoration(hintText: '输入消息...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                    onSubmitted: (_) => _doSendChat(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: inRoom ? _doSendChat : null, child: const Text('发送')),
              ]),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Column(children: [
          AppBar(title: const Text('SDK 日志'), automaticallyImplyLeading: false),
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(8), itemCount: _logs.length, itemBuilder: (ctx, i) => Text(_logs[i], style: const TextStyle(fontSize: 11, fontFamily: 'monospace')))),
        ]),
      ),
    );
  }

  Widget _buildStatusChip() {
    final (color, label) = switch (_connState) {
      IMConnectionState.connected => (Colors.green, '已连接'),
      IMConnectionState.connecting => (Colors.orange, '连接中'),
      IMConnectionState.reconnecting => (Colors.orange, '重连中'),
      IMConnectionState.disconnected => (Colors.red, '未连接'),
    };
    return Chip(avatar: CircleAvatar(backgroundColor: color, radius: 5), label: Text(label, style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact);
  }

  Widget _buildInput(String label, TextEditingController ctrl, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: TextField(controller: ctrl, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true), style: const TextStyle(fontSize: 13)),
  );

  Widget _buildMessageItem(_ChatMessage msg) {
    final (bgColor, textColor) = switch (msg.type) {
      _MsgType.chat => (Colors.grey.shade100, Colors.black87),
      _MsgType.gift => (Colors.pink.shade50, Colors.pink.shade700),
      _MsgType.barrage => (Colors.blue.shade50, Colors.blue.shade700),
      _MsgType.notice => (Colors.amber.shade50, Colors.amber.shade800),
      _MsgType.join => (Colors.green.shade50, Colors.green.shade700),
      _MsgType.leave => (Colors.red.shade50, Colors.red.shade700),
      _MsgType.system => (Colors.orange.shade50, Colors.orange.shade800),
      _MsgType.error => (Colors.red.shade50, Colors.red),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(child: Text(msg.text, style: TextStyle(fontSize: 13, color: textColor))),
        Text('${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6, bottom: 4),
    child: ActionChip(label: Text(label, style: const TextStyle(fontSize: 12)), onPressed: onTap),
  );
}

enum _MsgType { chat, gift, barrage, notice, join, leave, system, error }

class _ChatMessage {
  final String text;
  final _MsgType type;
  final DateTime time;
  _ChatMessage({required this.text, required this.type, required this.time});
}
