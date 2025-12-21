import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'rag_service.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  // 文字輸入
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // 顯示
  String _answer = '';
  String? _error;
  bool _asking = false;

  Future<void> _askAi(String prompt) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      _asking = true;
      _error = null;
      _answer = '思考中…';
    });

    final apiKey = const String.fromEnvironment('OPENAI_API_KEY');
    if (apiKey.isEmpty) {
      setState(() {
        _asking = false;
        _error = '缺少 OPENAI_API_KEY，請用 --dart-define 傳入';
      });
      return;
    }

    try {
      // ① 先用 RAG 取出前 3 段最相關內容
      final context = await RagStore.instance.buildContext(prompt, k: 5);

      // ② 再呼叫 Chat Completions，請模型「只根據上下文回答」
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'model': 'gpt-5-nano',
        'messages': [
          {
            'role': 'system',
            'content':
                '你是中文導覽助理。以下是檢索到的知識片段（可能不完整）：\n$context\n\n請優先根據片段內容作答；若片段沒有答案，請說「我在已知資料裡找不到確切答案」。'
          },
          {'role': 'user', 'content': prompt},
        ],
        // 'temperature': 0.3,
      });

      final resp = await http.post(uri, headers: headers, body: body);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        final choices = data['choices'];
        final content = (choices is List && choices.isNotEmpty)
            ? (choices[0]['message']?['content'] ?? '')
            : '';
        final text = content.toString().trim();
        setState(() => _answer = text.isEmpty ? '（模型回應為空）' : text);
      } else {
        String message = 'HTTP ${resp.statusCode}';
        try {
          final e = jsonDecode(resp.body);
          if (e is Map && e['error'] != null) {
            final err = e['error'];
            final msg = (err['message'] ?? err['type'] ?? err).toString();
            message += '：$msg';
          } else {
            message += '：${resp.body}';
          }
        } catch (_) {
          message += '：${resp.body}';
        }
        setState(() => _error = 'API 錯誤：$message');
      }
    } catch (e) {
      setState(() => _error = 'RAG/連線失敗：$e');
    } finally {
      setState(() => _asking = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit = !_asking && _textCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 問答')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 文字輸入 + 送出
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (canSubmit) _askAi(_textCtrl.text);
                    },
                    decoration: const InputDecoration(
                      hintText: '請輸入你的問題…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: canSubmit ? () => _askAi(_textCtrl.text) : null,
                  icon: const Icon(Icons.send),
                  label: const Text('送出'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 回答 / 錯誤
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _error != null
                    ? Text(_error!, style: TextStyle(color: theme.colorScheme.error))
                    : _asking
                        ? const Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Text(
                              _answer.isEmpty ? '（等待問題或回答）' : _answer,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
              ),
            ),

            // 操作列（清空）
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _answer = '';
                      _error = null;
                    });
                    _focusNode.requestFocus();
                  },
                  child: const Text('清空回答'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}