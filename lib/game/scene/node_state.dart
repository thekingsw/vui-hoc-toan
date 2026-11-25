/// Trạng thái hiển thị của một điểm dừng trong cảnh đảo
/// (SPEC giao diện mục 4).
enum NodeDisplayState {
  /// Đã xong Luyện tập: cắm cờ xanh + dấu tích.
  done,

  /// Đã xem bài Học: biểu tượng cuốn sách.
  viewed,

  /// Bài đầu tiên chưa xong: vòng sáng nhấp nháy + mũi tên nhảy.
  suggested,

  /// Chưa làm: lấp lánh nhẹ.
  todo,
}

/// Chỉ số bài được gợi ý làm tiếp: bài đầu tiên (theo thứ tự) chưa xong
/// Luyện tập. Trả về -1 nếu đã xong hết.
int suggestedLessonIndex(List<String> lessonIds, Set<String> doneIds) {
  for (var i = 0; i < lessonIds.length; i++) {
    if (!doneIds.contains(lessonIds[i])) return i;
  }
  return -1;
}

NodeDisplayState nodeDisplayState({
  required String lessonId,
  required int index,
  required Set<String> doneIds,
  required Set<String> viewedIds,
  required int suggestedIndex,
}) {
  if (doneIds.contains(lessonId)) return NodeDisplayState.done;
  if (index == suggestedIndex) return NodeDisplayState.suggested;
  if (viewedIds.contains(lessonId)) return NodeDisplayState.viewed;
  return NodeDisplayState.todo;
}
