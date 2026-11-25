import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../models/question.dart';
import '../widgets/mascot.dart';
import '../providers/app_providers.dart';
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
          const MascotWidget(mood: MascotMood.neutral, size: 72),
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
                                        child: Text(
                                          card.heading,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    card.body,
                                    style: const TextStyle(fontSize: 18),
                                  ),
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
                                          Text(
                                            card.example!,
                                            style:
                                                const TextStyle(fontSize: 17),
                                          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              cards.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _page == i ? color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
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
