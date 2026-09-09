import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_model.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final List<ChatMessageModel> _messages = [];
  bool _isTyping = false;

  List<ChatMessageModel> get messages => _messages;
  bool get isTyping => _isTyping;

  ChatProvider() {
    _initDefaultMessage();
  }

  void _initDefaultMessage() {
    _messages.add(ChatMessageModel(
      id: 'msg-01',
      sender: 'pramaan_ai',
      text: 'Sat Sri Akal / Namaste! I am **Ask Pramaan**, your AI Agronomy & Real-Time Weather Assistant (PAU Ludhiana Standards). How can I assist with your Punjab crop spray windows, wheat yellow rust, or cotton pest management today?',
      timestamp: DateFormat('hh:mm a').format(DateTime.now()),
      actionChips: ['Check Punjab Spray Window', 'Ludhiana Weather', 'Wheat Yellow Rust Guide', 'Malwa Whitefly Window'],
      citations: ['PAU Ludhiana Protocols', 'Pramaan Verified Live Weather'],
    ));
  }


  Future<void> sendMessage(String text, {String crop = 'Cotton', String lang = 'en'}) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessageModel(
      id: 'msg-user-${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: text,
      timestamp: DateFormat('hh:mm a').format(DateTime.now()),
    );
    _messages.add(userMsg);
    _isTyping = true;
    notifyListeners();

    final result = await _api.chatWithAssistant(text, crop, lang);

    final aiMsg = ChatMessageModel(
      id: 'msg-ai-${DateTime.now().millisecondsSinceEpoch}',
      sender: 'pramaan_ai',
      text: result['reply'] ?? 'Here are the recommended agronomic practices for your query.',
      timestamp: DateFormat('hh:mm a').format(DateTime.now()),
      actionChips: result['action_chips'] != null ? List<String>.from(result['action_chips']) : [],
      citations: result['citations'] != null ? List<String>.from(result['citations']) : [],
    );

    _messages.add(aiMsg);
    _isTyping = false;
    notifyListeners();
  }
}
