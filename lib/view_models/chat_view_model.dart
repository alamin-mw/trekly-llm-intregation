import 'package:Trekly/model/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// Define the Riverpod provider for ChatViewModel
final chatViewModelProvider = ChangeNotifierProvider<ChatViewModel>((ref) {
  return ChatViewModel();
});

class ChatViewModel extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  // WebSocketChannel? _channel;
  bool _isConnected = false;

  List<ChatMessage> get messages => _messages;
  bool get isConnected => _isConnected;

  ChatViewModel() {
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    try {
      // Replace with your WebSocket server URL
      // _channel = WebSocketChannel.connect(
      //   Uri.parse('wss://your-llm-server.com/chat'),
      // );

      // Listen for messages from the server
      // _channel?.stream.listen(
      //   (data) {
      //     final response = jsonDecode(data);
      //     _messages.add(
      //       ChatMessage(
      //         text: response['response'] ?? 'No response',
      //         isUser: false,
      //         timestamp: DateTime.now(),
      //       ),
      //     );
      //     _isConnected = true;
      //     notifyListeners();
      //   },
      //   onError: (error) {
      //     debugPrint('WebSocket error: $error');
      //     _isConnected = false;
      //     notifyListeners();
      //   },
      //   onDone: () {
      //     debugPrint('WebSocket connection closed');
      //     _isConnected = false;
      //     notifyListeners();
      //   },
      // );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  void sendMessage(String text) {
    if (_isConnected && text.isNotEmpty) {
      // Add user message to the list
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );

      // Send message to the server
      // _channel?.sink.add(jsonEncode({'message': text}));
      notifyListeners();
    }
  }

  void reconnect() {
    if (!_isConnected) {
      _connectToWebSocket();
    }
  }

  @override
  void dispose() {
    // _channel?.sink.close();
    super.dispose();
  }
}
