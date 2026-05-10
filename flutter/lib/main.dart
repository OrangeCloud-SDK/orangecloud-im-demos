import 'package:flutter/material.dart';
import 'pages/chat_demo_page.dart';

/// OrangeCloud IM SDK - Flutter Demo
///
/// 演示如何使用 orangecloud_im_client 进行：
/// 1. 连接/断开 SignalR Hub
/// 2. 加入/离开房间
/// 3. 发送/接收各类消息（聊天、礼物、弹幕、公告、关播）
/// 4. 在线用户管理
/// 5. 连接状态监控与自动重连
void main() {
  runApp(const OrangeCloudIMDemoApp());
}

class OrangeCloudIMDemoApp extends StatelessWidget {
  const OrangeCloudIMDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrangeCloud IM Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ChatDemoPage(),
    );
  }
}
