import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });

  final String text;
  final bool isUser;
  final String time;
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Halo! Saya asisten AI DriveMate. Ada yang bisa saya bantu seputar perawatan atau kendala kendaraan Anda?',
      isUser: false,
      time: '09:40',
    ),
    ChatMessage(
      text: 'Mobil saya terasa bergetar saat kecepatan tinggi, apa penyebabnya?',
      isUser: true,
      time: '09:41',
    ),
    ChatMessage(
      text: 'Getaran pada kecepatan tinggi biasanya disebabkan oleh beberapa hal:\n\n'
          '1. Ban tidak seimbang (perlu balancing roda).\n'
          '2. Tekanan angin ban tidak merata atau pelek bengkok.\n'
          '3. Komponen kaki-kaki aus (tie rod, bushing, ball joint).\n\n'
          'Saran: Lakukan spooring & balancing di bengkel rekanan terdekat untuk memastikan keselamatan berkendara.',
      isUser: false,
      time: '09:41',
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final query = _inputController.text.trim();
    if (query.isEmpty) return;

    final now = TimeOfDay.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true, time: timeStr));
      _inputController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Respons AI Otomotif Cerdas
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final aiReply = _generateAiResponse(query);
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: aiReply, isUser: false, time: timeStr));
      });
      _scrollToBottom();
    });
  }

  String _generateAiResponse(String query) {
    final q = query.toLowerCase();

    if (q.contains('oli') || q.contains('pelumas')) {
      return 'Penggantian oli mesin mobil umumnya dianjurkan setiap 5.000 - 10.000 km atau maksimal 6 bulan sekali, tergantung jenis oli (Full Synthetic disarankan untuk performa optimal). Jangan lupa ganti filter oli setiap 2 kali ganti oli mesin.';
    } else if (q.contains('rem') || q.contains('bunyi')) {
      return 'Bunyi mendecit pada rem umumnya terjadi karena kampas rem sudah menipis atau kotoran debu pada piringan rotor. Segera periksa ketebalan kampas rem sebelum merusak cakram rem.';
    } else if (q.contains('baterai') || q.contains('aki')) {
      return 'Umur pakai aki kendaraan biasanya berkisar antara 1,5 hingga 2,5 tahun. Tanda-tanda aki melemah: starter mesin terasa lambat, klakson redup, atau indikator baterai di instrumen menyala.';
    } else if (q.contains('pajak') || q.contains('stnk')) {
      return 'Untuk pengingat pajak tahunan, DriveMate telah mencatat jatuh tempo Anda pada 12 Juli 2026. Anda dapat membayar melalui e-Samsat atau Samsat Digital Nasional (SIGNAL).';
    } else if (q.contains('check engine') || q.contains('indikator')) {
      return 'Lampu indikator Check Engine menyala menandakan ada sensor emisi, busi, atau sistem pembakaran yang membaca anomali data. Disarankan menghubungkan OBD-2 scanner di bengkel terdekat.';
    } else {
      return 'Terima kasih atas pertanyaannya. Berdasarkan panduan standar otomotif, pastikan selalu memeriksa oli mesin, tekanan ban, radiator coolant, dan minyak rem secara berkala sebelum melakukan perjalanan jauh. Untuk diagnosa presisi, kunjungi mekanik profesional di bengkel resmi.';
    }
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Avatar Robot AI (Mockup Layar 6)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DriveMate AI Bot',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tanyakan apa saja tentang kendaraan Anda',
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

            // Chat List
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

            // Typing Indicator
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI sedang menganalisis pertanyaan...',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            // Chat Input Bar (Mockup Layar 6)
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
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Tulis pertanyaan...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _sendMessage,
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

  Widget _buildChatBubble(ChatMessage msg) {
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
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
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
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: const Color(0xFFE4EDF7)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.navy.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
          ),
        ),
      );
    }
  }
}
