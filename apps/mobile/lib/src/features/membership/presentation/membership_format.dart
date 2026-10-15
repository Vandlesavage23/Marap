import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/membership/application/membership_providers.dart';
import 'package:marriage_connect/src/features/membership/domain/entitlements.dart';

String formatWhen(BuildContext context, DateTime when) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).add_jm().format(when.toLocal());
}

String formatDate(BuildContext context, DateTime when) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(when.toLocal());
}

String periodLabel(AppLocalizations l, StoreProduct p) {
  final m = p.months;
  return m != null
      ? l.paywallPeriodMonths(m)
      : l.paywallPeriodDays(p.durationDays);
}

/// The store's own localised price when it gave one, else the server's
/// display price. UGX has no minor unit.
String priceLabel(BuildContext context, PricedProduct p) {
  if (p.storePrice != null && p.storePrice!.isNotEmpty) return p.storePrice!;
  final locale = Localizations.localeOf(context).toString();
  final product = p.product;
  final digits = product.currency == 'UGX' ? 0 : 2;
  final value = digits == 0 ? product.priceMinor : product.priceMinor / 100;
  return NumberFormat.currency(
    locale: locale,
    name: product.currency,
    decimalDigits: digits,
  ).format(value);
}
