import 'package:flutter/services.dart';

/// Uganda is the launch market: the screen shows a fixed +256 prefix and the
/// member types the 9 national digits (772 000 000). The server also accepts
/// a leading 0, so pasted numbers in any common form work.
const ugCallingCode = '+256';
const ugNationalLength = 9;

/// Digits only, without a leading 0 or a pasted 256 country code, at most 9.
String ugNationalDigits(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('256') && d.length > ugNationalLength) {
    d = d.substring(3);
  }
  if (d.startsWith('0')) d = d.substring(1);
  return d.length > ugNationalLength ? d.substring(0, ugNationalLength) : d;
}

/// `772 000 000` grouping for display while typing.
String groupUgNational(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 6) b.write(' ');
    b.write(digits[i]);
  }
  return b.toString();
}

/// `+256772000000` when [raw] is a complete number, else null.
String? ugE164(String raw) {
  final d = ugNationalDigits(raw);
  return d.length == ugNationalLength ? '$ugCallingCode$d' : null;
}

/// `+256 772 000 000` for showing a number back to its owner.
String displayUgPhone(String e164) {
  if (e164.startsWith(ugCallingCode)) {
    return '$ugCallingCode ${groupUgNational(ugNationalDigits(e164))}';
  }
  return e164;
}

/// Keeps the field to digits, strips a leading 0 / pasted +256, groups 3-3-3.
class UgPhoneFormatter extends TextInputFormatter {
  const UgPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = groupUgNational(ugNationalDigits(newValue.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
