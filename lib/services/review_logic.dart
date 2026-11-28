/// Logic thuần cho Hộp ôn lại (Đợt A — Học thông minh).
///
/// Hộp Leitner 5 mức: sai → về hộp 1; đúng trong lượt ôn → lên 1 hộp;
/// đúng ở hộp 5 → tốt nghiệp (ra khỏi hộp). Lịch ôn theo hộp:
/// hộp 1 → 1 ngày, 2 → 3 ngày, 3 → 7 ngày, 4 → 14 ngày, 5 → 30 ngày.
library;

const int kMaxBox = 5;
const List<int> kBoxIntervalDays = [1, 3, 7, 14, 30];

/// Hộp kế tiếp sau một lần trả lời trong lượt ôn.
/// Trả về 0 nghĩa là tốt nghiệp (xóa khỏi hộp).
int nextBox(int currentBox, bool correct) {
  if (!correct) return 1;
  if (currentBox >= kMaxBox) return 0;
  return currentBox + 1;
}

/// Số ngày chờ tới lượt ôn kế tiếp cho một hộp (1–5).
int intervalDaysForBox(int box) {
  final i = box.clamp(1, kMaxBox) - 1;
  return kBoxIntervalDays[i];
}

/// Thời điểm ôn kế tiếp (ms) tính từ [nowMs] cho [box].
/// Đến hạn vào đầu ngày (00:00 giờ địa phương) sau [intervalDaysForBox]
/// ngày — sai hôm nay thì sáng mai đã ôn được, không phải chờ đủ 24 giờ.
int nextReviewAt(int box, int nowMs) {
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
  final startOfToday = DateTime(now.year, now.month, now.day);
  return startOfToday
      .add(Duration(days: intervalDaysForBox(box)))
      .millisecondsSinceEpoch;
}

/// Một mục trong hộp ôn (dạng thuần, không phụ thuộc DB).
class ReviewEntry {
  const ReviewEntry({
    required this.questionId,
    required this.box,
    required this.nextReviewAtMs,
    required this.wrongCount,
  });

  final String questionId;
  final int box;
  final int? nextReviewAtMs;
  final int wrongCount;
}

/// Chọn các câu đến hạn ôn: quá hạn trước, hộp thấp trước, sai nhiều trước.
/// Tối đa [limit] câu một lượt.
List<ReviewEntry> pickDueReview(List<ReviewEntry> entries, int nowMs,
    {int limit = 10}) {
  final due = entries
      .where((e) => e.nextReviewAtMs == null || e.nextReviewAtMs! <= nowMs)
      .toList();
  due.sort((a, b) {
    final byBox = a.box.compareTo(b.box);
    if (byBox != 0) return byBox;
    final byWrong = b.wrongCount.compareTo(a.wrongCount);
    if (byWrong != 0) return byWrong;
    return (a.nextReviewAtMs ?? 0).compareTo(b.nextReviewAtMs ?? 0);
  });
  return due.take(limit).toList();
}

/// Thống kê một kỹ năng (tag chính của câu hỏi).
class SkillStat {
  const SkillStat({
    required this.skill,
    required this.correct,
    required this.wrong,
  });

  final String skill;
  final int correct;
  final int wrong;

  int get total => correct + wrong;
  double get accuracy => total == 0 ? 1 : correct / total;
}

/// Kỹ năng yếu nhất: tỉ lệ đúng thấp nhất trong số kỹ năng đã làm
/// ít nhất [minAttempts] câu. null nếu chưa đủ dữ liệu.
SkillStat? weakestSkill(List<SkillStat> stats, {int minAttempts = 3}) {
  final eligible = stats.where((s) => s.total >= minAttempts).toList();
  if (eligible.isEmpty) return null;
  eligible.sort((a, b) {
    final byAcc = a.accuracy.compareTo(b.accuracy);
    if (byAcc != 0) return byAcc;
    return b.total.compareTo(a.total);
  });
  return eligible.first;
}
