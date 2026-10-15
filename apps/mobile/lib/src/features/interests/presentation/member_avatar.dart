import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/l10n/gen/app_localizations.dart';
import 'package:marriage_connect/src/features/discovery/presentation/progressive_image.dart';
import 'package:marriage_connect/src/features/interests/domain/member_summary.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.member, this.size = 48, super.key});
  final MemberSummary member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = member.photoUrl;
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: url == null
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person_outline),
              )
            : ProgressiveImage(
                url: url,
                decodeWidth: (size * 2).round(),
                thumbWidth: (size * 2).round(),
              ),
      ),
    );
  }
}

/// "Name, 29", or just the name when the age is unknown.
String memberTitle(AppLocalizations l, MemberSummary m) =>
    m.age == null ? m.displayName : l.discNameAge(m.displayName, m.age!);
