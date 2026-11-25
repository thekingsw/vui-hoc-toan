import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// Bọc quanh màn hình đầu tiên: khi app mở, kiểm tra bản mới trên
/// GitHub Releases; có bản mới thì hiện hộp thoại 1 chạm để tải + cài.
/// Không có mạng hoặc không có bản mới thì im lặng hoàn toàn.
class UpdateChecker extends StatefulWidget {
  const UpdateChecker({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked) return;
    _checked = true;
    final info = await checkForUpdate();
    if (info == null || !mounted) return;
    final context = widget.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final notes = info.notes.length > 300
        ? '${info.notes.substring(0, 300)}…'
        : info.notes;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Có bản mới'),
        content: Text(
          'Phiên bản ${info.version} đã sẵn sàng.'
          '${notes.isEmpty ? '' : '\n\n$notes'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cập nhật ngay'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    await _download(context, info);
  }

  Future<void> _download(BuildContext context, UpdateInfo info) async {
    var progress = 0.0;
    var known = false;
    StateSetter? setDialogState;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          setDialogState = setState;
          return AlertDialog(
            title: const Text('Đang tải bản mới…'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: known ? progress : null),
                const SizedBox(height: 12),
                Text(known
                    ? '${(progress * 100).round()}%'
                    : 'Đang kết nối…'),
              ],
            ),
          );
        },
      ),
    );

    try {
      await downloadAndInstall(info, onProgress: (p) {
        if (p != null) {
          progress = p;
          known = true;
        }
        setDialogState?.call(() {});
      });
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Chưa tải được bản mới. Kiểm tra mạng rồi mở lại app nhé.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
