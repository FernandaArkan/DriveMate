import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isProcessing = false;
  int _activeRequestId = 0;
  bool _initializedGreeting = false;

  final List<AiChatMessage> _messages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedGreeting) {
      final l10n = AppLocalizations.of(context);
      _messages.add(
        AiChatMessage(
          text: l10n.aiGreeting,
          isUser: false,
          time: '09:40',
        ),
      );
      _initializedGreeting = true;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final l10n = AppLocalizations.of(context);
    // Kunci eksekusi agar 1 pesan hanya menjalankan 1 request aktif dan tidak terjadi panggilan ganda
    if (_isProcessing || _isTyping) return;

    final query = _inputController.text.trim();
    if (query.isEmpty) return;

    _isProcessing = true;
    final currentRequestId = ++_activeRequestId;

    final now = TimeOfDay.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(AiChatMessage(text: query, isUser: true, time: timeStr));
      _inputController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final reply = await AiService.instance.askAi(query, history: _messages);

      // Pastikan widget masih aktif dan hanya memproses respon dari request terkini
      if (!mounted || currentRequestId != _activeRequestId) return;

      setState(() {
        _isTyping = false;
        _isProcessing = false;
        _messages.add(AiChatMessage(text: reply, isUser: false, time: timeStr));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted || currentRequestId != _activeRequestId) return;

      setState(() {
        _isTyping = false;
        _isProcessing = false;
        _messages.add(
          AiChatMessage(
            text: '${l10n.aiErrorPrefix}: $e',
            isUser: false,
            time: timeStr,
            isError: true,
          ),
        );
      });
      _scrollToBottom();
    } finally {
      if (currentRequestId == _activeRequestId) {
        _isProcessing = false;
        if (mounted && _isTyping) {
          setState(() => _isTyping = false);
        }
      }
    }
  }

  void _clearChat() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _messages
        ..clear()
        ..add(
          AiChatMessage(
            text: l10n.aiResetNotice,
            isUser: false,
            time: '${TimeOfDay.now().hour.toString().padLeft(2, "0")}:${TimeOfDay.now().minute.toString().padLeft(2, "0")}',
          ),
        );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.aiTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: l10n.aiResetTooltip,
            onPressed: _clearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Info Robot AI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aiTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.aiSubtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE6EEF8)),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildChatBubble(msg);
                },
              ),
            ),

            // Typing Indicator saat memproses
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.aiThinking,
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            // Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E9F3)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _inputController,
                        onSubmitted: (_) {
                          if (!_isProcessing && !_isTyping) {
                            _sendMessage();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: l10n.aiInputHint,
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: (_isProcessing || _isTyping) ? null : _sendMessage,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
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

  Widget _buildChatBubble(AiChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: msg.isError ? AppTheme.danger.withValues(alpha: 0.12) : AppTheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                msg.isError ? Icons.error_outline_rounded : Icons.smart_toy_rounded,
                color: msg.isError ? AppTheme.danger : AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? AppTheme.primary
                    : msg.isError
                        ? const Color(0xFFFFEBEE)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                border: msg.isUser
                    ? null
                    : Border.all(
                        color: msg.isError ? const Color(0xFFFFCDD2) : const Color(0xFFE4ECF6),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navy.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser
                          ? Colors.white
                          : msg.isError
                              ? const Color(0xFFC62828)
                              : AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.time,
                    style: TextStyle(
                      color: msg.isUser ? Colors.white70 : AppTheme.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
