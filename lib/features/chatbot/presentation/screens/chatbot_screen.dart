import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../services/chatbot_service.dart';
import '../widgets/chat_message_bubble.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const List<String> _quickPrompts = [
    'Necesito ayuda urgente',
    'Quiero apoyo emocional',
    'Como hago una denuncia',
    'Busco un centro de apoyo',
  ];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatbotService _chatbotService = ChatbotService();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Hola, soy tu chatbot de apoyo. Puedo ayudarte con orientacion inicial sobre seguridad, apoyo emocional y rutas de ayuda.',
      isUser: false,
    ),
  ];

  bool _isBotTyping = false;

  Future<void> _sendMessage([String? presetMessage]) async {
    final rawMessage = presetMessage ?? _messageController.text;
    final message = rawMessage.trim();
    if (message.isEmpty || _isBotTyping) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_ChatMessage(text: message, isUser: true));
      _messageController.clear();
      _isBotTyping = true;
    });

    _scrollToBottom();

    try {
      final reply = await _chatbotService.generateReply(
        _buildConversationTurns(),
      );
      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
        _isBotTyping = false;
      });
    } on ChatbotException catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(text: error.message, isUser: false));
        _isBotTyping = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Ocurrio un error inesperado al consultar el chatbot.',
            isUser: false,
          ),
        );
        _isBotTyping = false;
      });
    }

    _scrollToBottom();
  }

  List<ChatbotTurn> _buildConversationTurns() {
    final relevantMessages = _messages.skip(1).toList();
    if (relevantMessages.length > 10) {
      return relevantMessages
          .sublist(relevantMessages.length - 10)
          .map(
            (message) => ChatbotTurn(
              role: message.isUser ? 'user' : 'assistant',
              content: message.text,
            ),
          )
          .toList();
    }

    return relevantMessages
        .map(
          (message) => ChatbotTurn(
            role: message.isUser ? 'user' : 'assistant',
            content: message.text,
          ),
        )
        .toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = _chatbotService.isConfigured;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Chatbot de apoyo')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: CustomCard(
                borderRadius: 20,
                hasShadow: true,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isConfigured
                                ? 'Chat conectado a Groq (${AppConstants.groqChatModel}).'
                                : 'El chat necesita una clave de Groq para responder.',
                            style: AppTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isConfigured
                          ? 'Responde en tiempo real con IA y conserva el contexto reciente de la conversación.'
                          : 'Arranca la app con flutter_groq.cmd run o configura GROQ_API_KEY como dart-define.',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return ActionChip(
                    onPressed: () => _sendMessage(prompt),
                    backgroundColor: AppTheme.cardBg,
                    side: const BorderSide(color: AppTheme.divider),
                    label: Text(
                      prompt,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const ChatMessageBubble(
                      text: '',
                      isUser: false,
                      isTyping: true,
                    );
                  }

                  final message = _messages[index];
                  return ChatMessageBubble(
                    text: message.text,
                    isUser: message.isUser,
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu mensaje...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isBotTyping ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.send_rounded, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
