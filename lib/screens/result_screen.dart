import 'package:flutter/material.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../widgets/mascot.dart';
import '../widgets/star_row.dart';

/// Màn kết quả: sao (Quiz) hoặc điểm (Luyện tập), danh sách câu sai.
/// MVP chưa có xu.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.title,
    required this.correct,
    required this.total,
    required this.wrongQuestions,
    this.stars,
    this.subtitle,
    this.elapsedText,
  });

  final String title;
  final int correct;
  final int total;
  final List<Question> wrongQuestions;

  /// null = lượt Luyện tập (không chấm sao).
  final int? stars;
  final String? subtitle;
  final String? elapsedText;

  @override
  Widget build(BuildContext context) {
    final isQuiz = stars != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: MascotWidget(
              mood: correct >= total * 0.6
                  ? MascotMood.excited
                  : MascotMood.neutral,
              size: 110,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (isQuiz) Center(child: StarRow(stars: stars!, size: 44)),
          if (isQuiz) const SizedBox(height: 8),
          Text(
            'Đúng $correct/$total câu',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (elapsedText != null)
            Text(
              'Thời gian: $elapsedText',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
          ],
          const SizedBox(height: 20),
          if (wrongQuestions.isNotEmpty) ...[
            const Text(
              'Câu cần xem lại:',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...wrongQuestions.map((q) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.prompt,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          'Đáp án: ${q.answerText ?? ''}${q.unit != null ? ' ${q.unit}' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (q.explanation != null)
                          Text('Lời giải: ${q.explanation}',
                              style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                )),
          ] else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tuyệt vời, không sai câu nào! 🌟',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Về bản đồ đảo',
                  style: TextStyle(fontSize: 19)),
            ),
          ),
        ],
      ),
    );
  }
}
