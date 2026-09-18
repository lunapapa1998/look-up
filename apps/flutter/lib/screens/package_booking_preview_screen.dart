import 'package:flutter/material.dart';

import '../models/stay_package.dart';
import '../theme/layout_tokens.dart';

/// Local-only planning preview. It never sends or stores a reservation.
class PackageBookingPreviewScreen extends StatefulWidget {
  const PackageBookingPreviewScreen({super.key, required this.package});
  final StayPackage package;
  @override
  State<PackageBookingPreviewScreen> createState() =>
      _PackageBookingPreviewScreenState();
}

class _PackageBookingPreviewScreenState
    extends State<PackageBookingPreviewScreen> {
  DateTime? _departure;
  int _people = 1;

  Future<void> _pickDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _departure ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '희망 출발일 선택 · 예약 가능일이 아닙니다',
    );
    if (picked != null && mounted) setState(() => _departure = picked);
  }

  void _showPreview() {
    if (_departure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('희망 출발일을 선택해주세요')));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선택 내용 미리보기'),
        content: SingleChildScrollView(
          child: Text(
            '${widget.package.title}\n\n'
            '${_departure!.year}.${_departure!.month.toString().padLeft(2, '0')}.${_departure!.day.toString().padLeft(2, '0')} 출발 희망 · $_people명\n'
            '예시 총액 ${formatPackagePrice(widget.package.pricePerPerson * _people)}원\n\n'
            '실제 예약이 접수되지 않았습니다. 출발일·가격·잔여 좌석은 운영사 확인 전입니다.',
          ),
        ),
        actions: [
          TextButton(
            key: const Key('package_booking_close'),
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('예약 미리보기')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(widget.package.title, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text(
                '예시 상품입니다. 예약·결제 기능은 준비 중이며, 선택한 내용은 전송하거나 저장하지 않습니다.',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('희망 출발일', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('package_booking_date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _departure == null
                    ? '날짜 선택'
                    : '${_departure!.year}.${_departure!.month}.${_departure!.day}',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              key: const Key('package_booking_people'),
              initialValue: _people,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '여행 인원'),
              items: [
                for (var i = 1; i <= 6; i++)
                  DropdownMenuItem(value: i, child: Text('$i명')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _people = value);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('예시 총액', style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatPackagePrice(widget.package.pricePerPerson * _people)}원',
              key: const Key('package_booking_total'),
              style: text.headlineMedium?.copyWith(color: colors.secondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '실제 판매 가격이 아닙니다. 포함 사항과 가격은 변경될 수 있습니다.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const Key('package_booking_confirm'),
              onPressed: _showPreview,
              child: const Text('선택 내용 미리보기'),
            ),
          ],
        ),
      ),
    );
  }
}
