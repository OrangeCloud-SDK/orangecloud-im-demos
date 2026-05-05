import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:orangecloud_im_client/orangecloud_im_client.dart';

/// 聊天室 Demo 页面
///
/// 完整演示 OrangeCloudIMClient 的所有功能：
/// - login / logout（连接管理）
/// - joinGroup / quitGroup（房间操作）
/// - sendGroupMsg（消息发送）
/// - Stream 事件监听（消息接收、用户进出、在线人数、禁言等）
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
  ConnectionState _connState = ConnectionState.disconnected;
  int _onlineCount = 0;
  String? _currentRoomId;
  String _userId = '';
  String _nickName = '';

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _userId = 'user_${Random().nextInt(9999).toString().padLeft(4, '0')}';
    _nickName = '用户$_userId';
    _userIdCtrl.text = _userId;
    _setupListeners();
  }

  void _setupListeners() {
    _subs.add(_client.onConnectionStateChanged.listen((state) {
      setState(() => _connState = state);
      _addLog('连接状态: ${state.name}');
    }));

    _subs.add(_client.onMessageReceived.listen((json) {
      _addLog('收到消息: ${json.length > 80 ? '${json.substring(0, 80)}...' : json}');
      _handleMessage(json);
    }));

    _subs.add(_client.onUserJoined.listen((json) {
      _addLog('用户加入: $json');
      try {
        final user = jsonDecode(json);
        final nick = user['NickName'] ?? user['UserKey'] ?? '匿名';
        _addMsg('$nick 进入了房间 👋', _MsgType.join);
      } catch (_) {
        _addMsg('用户加入: $json', _MsgType.join);
      }
    }));

    _subs.add(_client.onUserLeft.listen((userKey) {
      _addLog('用户离开: $userKey');
      _addMsg('$userKey 离开了房间', _MsgType.leave);
    }));

    _subs.add(_client.onOnlineCountChanged.listen((count) {
      setState(() => _onlineCount = count);
      _addLog('在线人数: $count');
    }));

    _subs.add(_client.onMuted.listen((json) {
      _addLog('被禁言: $json');
      _addMsg('⚠️ 你已被禁言', _MsgType.system);
    }));

    _subs.add(_client.onUnmuted.listen((userKey) {
      _addLog('被解禁: $userKey');
      _addMsg('✅ 你已被解除禁言', _MsgType.system);
    }));

    _subs.add(_client.onRoomClosed.listen((_) {
      _addLog('房间已关闭');
      _addMsg('🔴 房间已关闭', _MsgType.system);
      setState(() => _currentRoomId = null);
    }));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _client.dispose();
    _hubUrlCtrl.dispose();
    _appIdCtrl.dispose();
    _userIdCtrl.dispose();
    _userSigCtrl.dispose();
    _roomIdCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addMsg(String text, _MsgType type) {
    setState(() {
      _messages.add(_ChatMessage(text: text, type: type, time: DateTime.now()));
    });
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
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================
  // 核心操作
  // ============================================================

  Future<void> _doLogin() async {
    _userId = _userIdCtrl.text.trim().isEmpty
        ? 'user_${Random().nextInt(9999).toString().padLeft(4, '0')}'
        : _userIdCtrl.text.trim();
    _nickName = '用户${_userId.substring(_userId.length - 4)}';
    _userIdCtrl.text = _userId;

    _addLog('正在连接...');
    try {
      await _client.login(
        _hubUrlCtrl.text.trim(),
        _appIdCtrl.text.trim(),
        _userId,
        _userSigCtrl.text.trim(),
      );
      _addMsg('已连接到 SignalR Hub', _MsgType.system);
    } catch (e) {
      _addMsg('连接失败: $e', _MsgType.error);
    }
  }

  Future<void> _doLogout() async {
    _addLog('正在断开...');
    await _client.logout();
    setState(() {
      _currentRoomId = null;
      _onlineCount = 0;
    });
    _addMsg('已断开连接', _MsgType.system);
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
    try {
      await _client.quitGroup(_currentRoomId!);
      _addMsg('已离开房间 $_currentRoomId', _MsgType.leave);
      setState(() {
        _currentRoomId = null;
        _onlineCount = 0;
      });
    } catch (e) {
      _addMsg('离开失败: $e', _MsgType.error);
    }
  }

  Future<void> _doSendChat() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _currentRoomId == null) return;

    final msgData = {
      'Type': IMMessageType.publicMsg,
      'data': {
        'content': {'word': text},
        'user_info': {
          'uid': _userId,
          'nick': _nickName,
          'avatar': '',
          'level': '1',
          'isAdmin': '0',
          'isAnchor': '0',
        },
      },
    };

    try {
      await _client.sendGroupMsg(_currentRoomId!, jsonEncode(msgData));
      _msgCtrl.clear();
    } catch (e) {
      _addMsg('发送失败: $e', _MsgType.error);
    }
  }

  Future<void> _doSendGift() async {
    if (_currentRoomId == null) return;
    final giftMsg = {
      'MsgId': DateTime.now().millisecondsSinceEpoch.toString(),
      'Type': IMMessageType.sendGift,
      'GiftInfo': {'Id': 1, 'Name': '小星星', 'CNName': '小星星', 'Profit': 10, 'Price': 20, 'Count': 1},
      'UserInfo': {'UserId': 1, 'IMUserId': _userId, 'NickName': _nickName},
      'AnchorInfo': {'UserId': 100, 'IMUserId': 'anchor_001', 'NickName': '主播'},
    };
    try {
      await _client.sendGroupMsg(_currentRoomId!, jsonEncode(giftMsg));
    } catch (e) {
      _addMsg('送礼失败: $e', _MsgType.error);
    }
  }

  Future<void> _doSendBarrage() async {
    if (_currentRoomId == null) return;
    final msg = {
      'MsgId': DateTime.now().millisecondsSinceEpoch.toString(),
      'Type': IMMessageType.sendBarrage,
      'GiftInfo': {'Id': 0, 'Name': '弹幕', 'Message': '这是一条弹幕 🎉', 'Profit': 1, 'Price': 2, 'Count': 1},
      'UserInfo': {'UserId': 1, 'IMUserId': _userId, 'NickName': _nickName},
      'AnchorInfo': {'UserId': 100, 'IMUserId': 'anchor_001', 'NickName': '主播'},
    };
    try {
      await _client.sendGroupMsg(_currentRoomId!, jsonEncode(msg));
    } catch (e) {
      _addMsg('弹幕失败: $e', _MsgType.error);
    }
  }

  Future<void> _doSendNotice() async {
    if (_currentRoomId == null) return;
    final msg = {
      'Type': IMMessageType.aNotice,
      'data': {'IsShow': true, 'Notice': '这是一条系统公告测试'},
    };
    try {
      await _client.sendGroupMsg(_currentRoomId!, jsonEncode(msg));
    } catch (e) {
      _addMsg('公告失败: $e', _MsgType.error);
    }
  }

  // ============================================================
  // 消息解析
  // ============================================================

  void _handleMessage(String json) {
    try {
      final msg = jsonDecode(json);
      final type = msg['Type'] ?? msg['type'] ?? '';

      switch (type) {
        case 'public_msg':
          final nick = msg['data']?['user_info']?['nick'] ?? '匿名';
          final word = msg['data']?['content']?['word'] ?? '';
          _addMsg('$nick: $word', _MsgType.chat);
        case 'SEND_GIFT':
          final sender = msg['UserInfo']?['NickName'] ?? '匿名';
          final gift = msg['GiftInfo']?['CNName'] ?? '礼物';
          final count = msg['GiftInfo']?['Count'] ?? 1;
          _addMsg('🎁 $sender 送出 $gift x$count', _MsgType.gift);
        case 'SEND_BIG_GIFT':
          final sender = msg['UserInfo']?['NickName'] ?? '匿名';
          final gift = msg['GiftInfo']?['CNName'] ?? '大礼物';
          _addMsg('🎆 $sender 送出 $gift 🚀', _MsgType.gift);
        case 'SEND_BARRAGE':
          final sender = msg['UserInfo']?['NickName'] ?? '匿名';
          final text = msg['GiftInfo']?['Message'] ?? '弹幕';
          _addMsg('💬 $sender: $text', _MsgType.barrage);
        case 'ANotice':
          final notice = msg['data']?['Notice'] ?? '系统公告';
          _addMsg('📢 $notice', _MsgType.notice);
        case 'stop_live':
          _addMsg('🔴 直播已结束', _MsgType.system);
        default:
          _addMsg('未知消息: $type', _MsgType.system);
      }
    } catch (_) {
      _addMsg('消息解析失败', _MsgType.error);
    }
  }

  // ============================================================
  // UI 构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isConnected = _connState == ConnectionState.connected;
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
          // 连接配置（可折叠）
          ExpansionTile(
            title: const Text('🔌 连接配置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _buildInput('Hub URL', _hubUrlCtrl),
                    _buildInput('App ID', _appIdCtrl),
                    _buildInput('User ID', _userIdCtrl, hint: '留空自动生成'),
                    _buildInput('User Sig', _userSigCtrl),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: FilledButton(onPressed: isConnected ? null : _doLogin, child: const Text('登录连接'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.tonal(onPressed: isConnected ? _doLogout : null, child: const Text('断开连接'))),
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
                  ],
                ),
              ),
            ],
          ),

          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _buildMessageItem(_messages[i]),
            ),
          ),

          // 快捷操作
          if (inRoom)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                _quickBtn('🎁 礼物', _doSendGift),
                _quickBtn('💬 弹幕', _doSendBarrage),
                _quickBtn('📢 公告', _doSendNotice),
              ]),
            ),

          // 输入框
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    enabled: inRoom,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
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

      // 日志抽屉
      endDrawer: Drawer(
        child: Column(
          children: [
            AppBar(title: const Text('SDK 日志'), automaticallyImplyLeading: false),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (ctx, i) => Text(_logs[i], style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;
    switch (_connState) {
      case ConnectionState.connected:
        color = Colors.green;
        label = '已连接';
      case ConnectionState.connecting:
        color = Colors.orange;
        label = '连接中';
      case ConnectionState.reconnecting:
        color = Colors.orange;
        label = '重连中';
      case ConnectionState.disconnected:
        color = Colors.red;
        label = '未连接';
    }
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 5),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage msg) {
    Color bgColor;
    Color textColor = Colors.black87;
    switch (msg.type) {
      case _MsgType.chat:
        bgColor = Colors.grey.shade100;
      case _MsgType.gift:
        bgColor = Colors.pink.shade50;
        textColor = Colors.pink.shade700;
      case _MsgType.barrage:
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
      case _MsgType.notice:
        bgColor = Colors.amber.shade50;
        textColor = Colors.amber.shade800;
      case _MsgType.join:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
      case _MsgType.leave:
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
      case _MsgType.system:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
      case _MsgType.error:
        bgColor = Colors.red.shade50;
        textColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: Text(msg.text, style: TextStyle(fontSize: 13, color: textColor))),
          Text(
            '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 4),
      child: ActionChip(label: Text(label, style: const TextStyle(fontSize: 12)), onPressed: onTap),
    );
  }
}

// ============================================================
// 消息模型
// ============================================================

enum _MsgType { chat, gift, barrage, notice, join, leave, system, error }

class _ChatMessage {
  final String text;
  final _MsgType type;
  final DateTime time;
  _ChatMessage({required this.text, required this.type, required this.time});
}
