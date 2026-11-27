import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../models/question.dart';
import '../providers/app_providers.dart';
import '../widgets/figure_view.dart';
import '../widgets/fraction_view.dart';
import '../widgets/speech_bubble.dart';
import 'practice_screen.dart';

/// Học: thẻ vuốt ngang (PageView), 4–5 thẻ/bài, có thẻ "Lỗi hay gặp".
/// Cuối bài có nút "Luyện ngay".
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    super.key,
    required this.island,
    required this.lesson,
    required this.meta,
  });

  final IslandData island;
  final Lesson lesson;
  final IslandMeta meta;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // Đánh dấu đã xem bài Học (hiện biểu tượng sách ở điểm dừng).
    final db = ref.read(databaseProvider);
    db
        .markLessonViewed(widget.island.islandId, widget.lesson.lessonId)
        .then((_) {
      if (mounted) ref.read(progressRefreshProvider.notifier).state++;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.lesson.cards;
    final color = Color(widget.meta.colorValue);
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.title)),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SpeechBubble(
              mood: MascotMood.neutral,
              mascotSize: 64,
              text: cards.isEmpty
                  ? 'Mình cùng học nhé!'
                  : 'Mình học về: ${cards[_page].heading}',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: cards.isEmpty
                ? const Center(
                    child: Text('Bài này chưa có thẻ bài học.'),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: cards.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final card = cards[i];
                      final isMistakeCard =
                          card.heading.contains('Lỗi hay gặp');
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Card(
                          elevation: 3,
                          color: isMistakeCard
                              ? Colors.orange.shade50
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: color,
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichMathText(
                                          isMistakeCard
                                              ? '🪤 Coi chừng cái bẫy này!'
                                              : card.heading,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  RichMathText(card.body, fontSize: 18),
                                  if (card.figure != null)
                                    FigureView(figure: card.figure!, color: color),
                                  if (card.example != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ví dụ:',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          RichMathText(card.example!, fontSize: 17),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // Tiến độ dạng viên ngọc.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              cards.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: Transform.rotate(
                  angle: 0.7853981633974483, // 45 độ
                  child: Container(
                    width: _page == i ? 13 : 9,
                    height: _page == i ? 13 : 9,
                    decoration: BoxDecoration(
                      color: _page == i ? color : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticeScreen(
                        island: widget.island,
                        lesson: widget.lesson,
                        meta: widget.meta,
                      ),
                    ),
                  );
                },
                child: const Text('Luyện ngay',
                    style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
