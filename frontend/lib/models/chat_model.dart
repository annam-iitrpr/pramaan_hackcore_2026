class ChatMessageModel {
  final String id;
  final String sender; // "user" or "pramaan_ai"
  final String text;
  final String timestamp;
  final List<String> actionChips;
  final List<String> citations;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actionChips = const [],
    this.citations = const [],
  });
}
