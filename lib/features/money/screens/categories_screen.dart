import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/money_controller.dart';
import '../models/transaction_models.dart';
import '../widgets/category_icon.dart';

/// Quản lý danh mục thu/chi: thêm, sửa, xóa (danh mục tùy chỉnh).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final controller = ref.read(moneyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (cats) {
          final income = cats.where((c) => c.type == TxType.income).toList();
          final expense = cats.where((c) => c.type == TxType.expense).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _Section(
                title: 'Khoản chi',
                cats: expense,
                onEdit: (c) => _showEditor(context, ref, existing: c),
                onDelete: (c) async {
                  final ok = await _confirmDelete(context, c);
                  if (ok) {
                    await controller.deleteCategory(c.id!);
                  }
                },
              ),
              _Section(
                title: 'Khoản thu',
                cats: income,
                onEdit: (c) => _showEditor(context, ref, existing: c),
                onDelete: (c) async {
                  final ok = await _confirmDelete(context, c);
                  if (ok) {
                    await controller.deleteCategory(c.id!);
                  }
                },
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'ℹ️ Xóa danh mục sẽ KHÔNG xóa các giao dịch đã ghi — '
                    'chúng chuyển sang "không phân loại".',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, TransactionCategory c) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa "${c.name}"?'),
        content: const Text(
            'Các giao dịch của danh mục này sẽ không còn được phân loại.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    TransactionCategory? existing,
  }) async {
    final controller = ref.read(moneyControllerProvider.notifier);
    final theme = Theme.of(context);

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var icon = existing?.icon ?? 'category';
    var color = existing?.color ?? '#4CAF50';
    var type = existing?.type ?? TxType.expense;
    final errorText = ValueNotifier<String?>(null);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'Thêm danh mục' : 'Sửa danh mục',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (existing == null)
                SegmentedButton<TxType>(
                  segments: const [
                    ButtonSegment(value: TxType.expense, label: Text('Khoản chi')),
                    ButtonSegment(value: TxType.income, label: Text('Khoản thu')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setSheetState(() => type = s.first),
                ),
              if (existing == null) const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: existing == null,
                decoration: InputDecoration(
                  labelText: 'Tên danh mục',
                  errorText: errorText.value,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Màu sắc'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final c in const [
                    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
                    '#3F51B5', '#2196F3', '#00BCD4', '#009688',
                    '#4CAF50', '#8BC34A', '#FF9800', '#795548',
                  ])
                    GestureDetector(
                      onTap: () => setSheetState(() => color = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: CategoryIcon.tryParseColor(c),
                          shape: BoxShape.circle,
                          border: color == c
                              ? Border.all(
                                  color: theme.colorScheme.onSurface, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Icon'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in CategoryIcon.icons.entries)
                    ChoiceChip(
                      selected: icon == entry.key,
                      onSelected: (_) =>
                          setSheetState(() => icon = entry.key),
                      label: Icon(entry.value, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    errorText.value = 'Nhập tên danh mục';
                    setSheetState(() {});
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      if (existing == null) {
        await controller.addCategory(TransactionCategory(
          name: nameCtrl.text.trim(),
          icon: icon,
          color: color,
          type: type,
        ));
      } else {
        await controller.updateCategory(
            existing.copyWith(name: nameCtrl.text.trim(), icon: icon, color: color));
      }
    }
    nameCtrl.dispose();
    errorText.dispose();
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<TransactionCategory> cats;
  final void Function(TransactionCategory) onEdit;
  final void Function(TransactionCategory) onDelete;

  const _Section({
    required this.title,
    required this.cats,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Card(
          child: Column(
            children: [
              for (final (i, cat) in cats.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                ListTile(
                  leading: CategoryIcon(icon: cat.icon, color: cat.color),
                  title: Text(cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Sửa',
                        onPressed: () => onEdit(cat),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: theme.colorScheme.error),
                        tooltip: 'Xóa',
                        onPressed: () => onDelete(cat),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
