import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class RagChunk {
  final String id;
  final String text;
  List<double>? embedding; // 可緩存於記憶體

  RagChunk({required this.id, required this.text, this.embedding});
}

class RagStore {
  RagStore._();
  static final RagStore instance = RagStore._();

  final List<RagChunk> _chunks = [];
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    // 路徑維持你原本寫的 assets/data/knowledge.json
    final raw = await rootBundle.loadString('assets/knowledge.json');
    final list = jsonDecode(raw) as List;
    _chunks.clear();
    for (final m in list) {
      final id = (m is Map && m['id'] != null) ? m['id'].toString() : '';
      final text = (m is Map && m['text'] != null) ? m['text'].toString() : '';
      if (text.trim().isEmpty) continue;

      // 可在這裡做「切塊」
      if (text.length > 1000) {
        const step = 700;
        for (int i = 0; i < text.length; i += step) {
          final end = (i + step).clamp(0, text.length);
          final sub = text.substring(i, end);
          _chunks.add(RagChunk(id: '${id}_$i', text: sub));
        }
      } else {
        _chunks.add(RagChunk(id: id.isEmpty ? 'auto_${_chunks.length}' : id, text: text));
      }
    }
    _loaded = true;
  }

  Future<List<double>> _embed(String text) async {
    final apiKey = const String.fromEnvironment('OPENAI_API_KEY');
    if (apiKey.isEmpty) {
      throw Exception('缺少 OPENAI_API_KEY，請用 --dart-define 傳入');
    }
    final uri = Uri.parse('https://api.openai.com/v1/embeddings');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'model': 'text-embedding-3-small',
      'input': text,
    });
    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Embeddings 失敗：${resp.statusCode} ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    final vec = (data['data'][0]['embedding'] as List)
        .cast<num>()
        .map((e) => e.toDouble())
        .toList();
    return vec;
  }

  double _cosSim(List<double> a, List<double> b) {
    double dot = 0, na = 0, nb = 0;
    final n = (a.length < b.length) ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  /// 取得與 query 最相關的前 k 段。會動態對尚未嵌入的段落做嵌入。
  Future<List<RagChunk>> retrieve(String query, {int k = 3}) async {
    await ensureLoaded();

    // 先取得 query 的向量
    final qVec = await _embed(query);

    // 確保每個 chunk 都有 embedding
    for (final c in _chunks) {
      if (c.embedding == null) {
        c.embedding = await _embed(c.text);
      }
    }

    // 計分
    final scored = _chunks
        .map((c) => MapEntry(c, _cosSim(qVec, c.embedding ?? const [])))
        .toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(k).map((e) => e.key).toList();
  }

  /// 將檢索結果組成提示上下文
  Future<String> buildContext(String query, {int k = 3}) async {
    final top = await retrieve(query, k: k);
    final buf = StringBuffer();
    for (int i = 0; i < top.length; i++) {
      buf.writeln('【片段 ${i + 1}】');
      buf.writeln(top[i].text.trim());
      buf.writeln();
    }
    return buf.toString().trim();
  }
}