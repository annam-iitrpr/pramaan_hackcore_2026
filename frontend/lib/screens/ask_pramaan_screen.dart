import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/chat_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/localization/app_translations.dart';

class AskPramaanScreen extends StatefulWidget {
  const AskPramaanScreen({super.key});

  @override
  State<AskPramaanScreen> createState() => _AskPramaanScreenState();
}

class _AskPramaanScreenState extends State<AskPramaanScreen> {
  static const MethodChannel _speechChannel = MethodChannel(
    "com.pramaan.app/speech",
  );
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isListening = false;

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final farmProv = Provider.of<FarmProvider>(context, listen: false);
    final crop = farmProv.selectedFarm?.activeCrop ?? "Cotton";

    Provider.of<ChatProvider>(
      context,
      listen: false,
    ).sendMessage(text.trim(), crop: crop);
    _textController.clear();
    _scrollToBottom();
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      try {
        await _speechChannel.invokeMethod("stopListening");
      } catch (_) {}
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    try {
      final String? spokenText = await _speechChannel.invokeMethod<String>(
        "startListening",
        {"language": "en-IN"},
      );
      if (spokenText != null && spokenText.trim().isNotEmpty) {
        _textController.text = spokenText;
        _send(spokenText);
      }
    } catch (e) {
      debugPrint("Headless Speech Recognition: $e");
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryDark,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentGold,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppTranslations.tr(lang, "ask_pramaan_title", "Ask Pramaan AI"),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chat.messages.length,
              itemBuilder: (context, index) {
                final msg = chat.messages[index];
                final isUser = msg.sender == 'user';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primarySurface,
                          child: Icon(
                            Icons.psychology_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomLeft: isUser
                                  ? const Radius.circular(16)
                                  : const Radius.circular(2),
                              bottomRight: isUser
                                  ? const Radius.circular(2)
                                  : const Radius.circular(16),
                            ),
                            border: isUser
                                ? null
                                : Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isUser
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg.timestamp,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isUser
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppColors.textMuted,
                                ),
                              ),
                              if (msg.actionChips.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: msg.actionChips.map((chip) {
                                    return ActionChip(
                                      label: Text(
                                        chip,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      backgroundColor: AppColors.primarySurface,
                                      side: const BorderSide(
                                        color: AppColors.primaryAccent,
                                      ),
                                      onPressed: () => _send(chip),
                                    );
                                  }).toList(),
                                ),
                              ],
                              if (msg.citations.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  "Sources: ${msg.citations.join(', ')}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // In-App Seamless Listening Bar (No black Google modal!)
          if (_isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryDark,
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppTranslations.tr(lang, "listening_in_app", "🎙️ Listening... Speak your farming question naturally"),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleMic,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppTranslations.tr(lang, "stop_btn", "Stop"),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (chat.isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.tr(lang, "analyzing_gemini", "Gemini AI is analyzing agronomic protocols..."),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? AppTranslations.tr(lang, "listening_hint", "Listening to your voice...")
                            : AppTranslations.tr(lang, "ask_ai_input_hint", "Type or speak your farming question..."),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: _isListening
                          ? AppColors.flaggedRed
                          : AppColors.surfaceVariant,
                      foregroundColor: _isListening
                          ? Colors.white
                          : AppColors.primaryDark,
                    ),
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    ),
                    tooltip: _isListening
                        ? AppTranslations.tr(lang, "stop_listening_tooltip", "Stop Listening")
                        : AppTranslations.tr(lang, "speak_in_app_tooltip", "Speak In-App"),
                    onPressed: _toggleMic,
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () => _send(_textController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
