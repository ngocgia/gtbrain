import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/money_controller.dart';
import '../models/transaction_models.dart';
import '../widgets/category_icon.dart';

/// Thêm / sửa giao dịch thu–chi.
class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const TransactionFormScreen({super.key, this.transactionId});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState
    extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  TxType _type = TxType.expense;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _loadExisting(List<MoneyTransaction> monthTransactions) {
    if (_loaded || widget.transactionId == null) return;
    try {
      final t = monthTransactions.firstWhere((e) => e.id == widget.transactionId);
      _type = t.type;
      _categoryId = t.categoryId;
      _date = t.transactionDate;
      _amountCtrl.text = t.amount == t.amount.roundToDouble()
          ? t.amount.round().toString()
          : t.amount.toStringAsFixed(0);
      _noteCtrl.text = t.note ?? '';
      _loaded = true;
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      await ref.read(moneyControllerProvider.notifier).saveTransaction(
            MoneyTransaction(
              id: widget.transactionId,
              type: _type,
              amount: amount,
              categoryId: _categoryId,
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              transactionDate: _date,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.transactionId == null
                ? 'Đã thêm giao dịch'
                : 'Đã cập nhật giao dịch')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.transactionId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(moneyControllerProvider.notifier)
          .deleteTransaction(widget.transactionId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthTx =
        ref.watch(monthSummaryProvider(MonthKey.of(_date))).value;
    _loadExisting(monthTx?.transactions ?? const []);

    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId == null ? 'Thêm giao dịch' : 'Sửa giao dịch'),
        actions: [
          if (widget.transactionId != null)
            IconButton(
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('💰 Khoản chi')),
                ButtonSegment(value: TxType.income, label: Text('💵 Khoản thu')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null; // đổi loại → chọn lại danh mục
              }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'Số tiền (VND)',
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: '₫',
              ),
              validator: (v) {
                final amount = int.tryParse(v ?? '');
                return amount != null && amount > 0 ? null : 'Nhập số tiền hợp lệ';
              },
            ),
            const SizedBox(height: 20),
            Text('Danh mục',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Lỗi tải danh mục: $e'),
              data: (cats) {
                final filtered =
                    cats.where((c) => c.type == _type).toList();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in filtered)
                      ChoiceChip(
                        selected: _categoryId == cat.id,
                        onSelected: (_) =>
                            setState(() => _categoryId = cat.id),
                        label: Text(cat.name),
                        avatar: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: CategoryIcon.tryParseColor(cat.color)
                                ?.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CategoryIcon.icons[cat.icon] ?? Icons.category,
                            size: 14,
                            color: CategoryIcon.tryParseColor(cat.color),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                'Ngày: ${_date.day}/${_date.month}/${_date.year}',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(widget.transactionId == null ? 'Thêm giao dịch' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
