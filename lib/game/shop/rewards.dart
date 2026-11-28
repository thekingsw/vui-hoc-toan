// Luật nhận xu (SPEC giao diện mục 8) — cố định, không ngẫu nhiên.
// Mọi khoản đều nhận qua reward_log theo khóa để chống nhận lặp.

/// Trả lời đúng một câu lần đầu tiên (mỗi câu chỉ nhận một lần).
const int coinFirstCorrect = 3;

/// Xong một lượt Luyện tập.
const int coinPracticeDone = 10;

/// Tổng xu tích lũy theo mức sao Thử thách: 1 sao = 30, 2 sao = 60,
/// 3 sao = 100. Đạt mức mới chỉ trả phần chênh.
int cumulativeStarCoins(int stars) => switch (stars) {
      >= 3 => 100,
      2 => 60,
      1 => 30,
      _ => 0,
    };

/// Xu nhận thêm khi đi từ [prevBest] lên [newStars] sao.
int starCoinReward(int newStars, int prevBest) {
  final diff = cumulativeStarCoins(newStars) - cumulativeStarCoins(prevBest);
  return diff < 0 ? 0 : diff;
}

String questionRewardKey(String questionId) => 'q:$questionId';

String practiceRewardKey(String lessonId, int runIndex) =>
    'practice:$lessonId:$runIndex';

/// Số lượt Luyện tập tối đa có xu mỗi ngày cho mỗi bài (chống farm xu).
const int maxPracticeCoinsPerDay = 3;

/// Khóa xu Luyện tập theo ngày: `practice:<bài>:<yyyy-MM-dd>:<n>`.
String practiceRewardKeyForDay(String lessonId, String date, int n) =>
    'practice:$lessonId:$date:$n';

/// Tiền tố đếm số lần đã nhận xu Luyện tập của [lessonId] trong [date].
String practiceDayPrefix(String lessonId, String date) =>
    'practice:$lessonId:$date:';

/// Được nhận xu xong lượt Luyện tập khi đúng ≥ 6/10 câu và chưa quá
/// [maxPracticeCoinsPerDay] lượt có xu trong ngày cho bài này.
bool canClaimPracticeCoin({
  required int correct,
  required int total,
  required int claimedToday,
}) {
  if (total <= 0) return false;
  if (claimedToday >= maxPracticeCoinsPerDay) return false;
  return correct * 10 >= total * 6;
}

String bossStarRewardKey(String islandId, int starLevel) =>
    'boss:$islandId:star$starLevel';

/// Các khoản (khóa, xu) cần nhận khi Thử thách đạt [newStars] sao:
/// mỗi mức sao là một khóa riêng, xu của mức đó = phần chênh tích lũy
/// (star1: 30, star2: 30, star3: 40). Nhận qua reward_log nên mức đã
/// nhận rồi sẽ tự bỏ qua — tổng nhận đúng bằng phần chênh.
List<(String, int)> bossStarClaims(String islandId, int newStars) {
  final claims = <(String, int)>[];
  for (var level = 1; level <= newStars && level <= 3; level++) {
    final amount =
        cumulativeStarCoins(level) - cumulativeStarCoins(level - 1);
    claims.add((bossStarRewardKey(islandId, level), amount));
  }
  return claims;
}
