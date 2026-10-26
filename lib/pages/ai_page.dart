import 'package:flutter/material.dart';
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

  final List<AiChatMessage> _messages = [
    AiChatMessage(
      text: 'Halo! Saya asisten pintar otomotif DriveMate. Ada yang bisa saya bantu terkait kondisi kendaraan, jadwal servis, atau tips perawatan mobil & motor Anda?',
      isUser: false,
      time: '09:40',
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
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
            text: 'Gagal memproses respon AI: $e',
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
    setState(() {
      _messages
        ..clear()
        ..add(
          AiChatMessage(
            text: 'Percakapan telah direset. Silakan tanyakan hal baru seputar kendaraan Anda.',
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'AI Vehicle Assistant',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Reset Percakapan',
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DriveMate AI Assistant',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Menganalisis perawatan, gejala kerusakan, & rute',
                          style: TextStyle(
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
                      'AI sedang memproses jawaban...',
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
                        decoration: const InputDecoration(
                          hintText: 'Tanyakan kendala atau perawatan kendaraan...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                msg.time,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9),
              ),
            ],
          ),
        ),
      );
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, right: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: msg.isError ? const Color(0xFFFFF0F0) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(
              color: msg.isError ? AppTheme.danger.withValues(alpha: 0.3) : const Color(0xFFE4EDF7),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  color: msg.isError ? AppTheme.danger : AppTheme.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                msg.time,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }
  }
}
