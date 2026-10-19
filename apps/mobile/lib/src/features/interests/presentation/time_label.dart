import 'package:intl/intl.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';

/// Short, human time for list rows: "14:05" today, "Yesterday", else "12 Oct".
String shortTimeLabel(AppLocalizations l, DateTime when, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final w = when.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(w.year, w.month, w.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat.Hm(l.localeName).format(w);
  if (diff == 1) return l.v2aYesterday;
  return DateFormat.MMMd(l.localeName).format(w);
}
