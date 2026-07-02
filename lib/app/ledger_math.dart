import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';

double signedAmount(LedgerEntry entry) {
  switch (entry.type) {
    case EntryType.expense:
      return -entry.amount;
    case EntryType.income:
      return entry.amount;
    case EntryType.transfer:
      return 0;
  }
}

Color colorForType(EntryType type) {
  switch (type) {
    case EntryType.expense:
      return const Color(0xFFE84D6A);
    case EntryType.income:
      return veriMint;
    case EntryType.transfer:
      return veriBlue;
  }
}

double sumByType(Iterable<LedgerEntry> entries, EntryType type) {
  return entries
      .where((entry) => entry.type == type)
      .fold<double>(0, (sum, entry) => sum + entry.amount);
}

List<double> dailyExpenseValues(Iterable<LedgerEntry> entries, DateTime now) {
  final days = DateUtils.getDaysInMonth(now.year, now.month);
  final values = List<double>.filled(days, 0);
  for (final entry in entries) {
    if (entry.type == EntryType.expense &&
        entry.occurredAt.year == now.year &&
        entry.occurredAt.month == now.month) {
      values[entry.occurredAt.day - 1] += entry.amount;
    }
  }
  return values;
}

List<double> monthlyExpenseValues(Iterable<LedgerEntry> entries) {
  final now = DateTime.now();
  final values = List<double>.filled(12, 0);
  for (final entry in entries) {
    if (entry.type == EntryType.expense && entry.occurredAt.year == now.year) {
      values[entry.occurredAt.month - 1] += entry.amount;
    }
  }
  return values;
}

String formatAmount(num value) {
  final text = value.toStringAsFixed(2);
  return text.endsWith('.00')
      ? text.substring(0, text.length - 3)
      : text.replaceFirst(RegExp(r'0$'), '');
}

String formatSignedAmount(double value) {
  if (value == 0) {
    return '0';
  }
  return value > 0
      ? '+${formatAmount(value)}'
      : '-${formatAmount(value.abs())}';
}

String formatDate(DateTime date) {
  return '${date.month}月${date.day}日';
}

String formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
