/// Trạng thái hiển thị của một đảo trên bản đồ biển (SPEC giao diện mục 3).
enum IslandDisplayState {
  /// Đảo đang chơi: đã mở, chưa đạt sao.
  current,

  /// Đã hoàn thành: đạt ≥ 1 sao (cắm cờ, hiện sao).
  completed,

  /// Đã có dữ liệu nhưng chưa mở: phủ sương mù + ổ khóa.
  locked,

  /// Chưa có dữ liệu: bóng đảo bí ẩn "Sắp có".
  mystery,
}

IslandDisplayState islandDisplayState({
  required bool hasData,
  required bool unlocked,
  required int bestStars,
}) {
  if (!hasData) return IslandDisplayState.mystery;
  if (!unlocked) return IslandDisplayState.locked;
  return bestStars >= 1
      ? IslandDisplayState.completed
      : IslandDisplayState.current;
}

/// Đảo hiện tại của bé (nơi thuyền đậu): đảo đầu tiên theo thứ tự đang ở
/// trạng thái "current"; nếu không có (đã xong hết các đảo có dữ liệu)
/// thì đảo "completed" cuối cùng; không có nữa thì đảo đầu tiên.
String currentIslandId(
  List<String> islandOrder,
  Map<String, IslandDisplayState> states,
) {
  for (final id in islandOrder) {
    if (states[id] == IslandDisplayState.current) return id;
  }
  String? lastCompleted;
  for (final id in islandOrder) {
    if (states[id] == IslandDisplayState.completed) lastCompleted = id;
  }
  return lastCompleted ?? islandOrder.first;
}
