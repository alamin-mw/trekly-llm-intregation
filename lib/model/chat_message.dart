class ChatMessage {
  final String text;
  final bool isUser; // true for user messages, false for LLM responses
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
