import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_connect/src/core/illustrations/illustrations.dart';

import 'shot.dart';

Widget _sheet() => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(),
            const SizedBox(height: 12),
            const HeroIllustration(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ['grace', 'moses', 'aisha', 'brian', 'sarah', 'peter', 'ruth', 'david'])
                  SampleAvatar(seed: s, size: 72, circle: true),
                const VerifiedBadgeArt(size: 40),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in EmptyKind.values) EmptyIllustration(kind: k, size: 110),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  for (final s in ['grace', 'moses', 'aisha'])
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SampleAvatar(seed: s),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  setUpAll(loadRealFonts);
  for (final b in Brightness.values) {
    testWidgets('illustrations ${b.name}', (t) async {
      phoneSurface(t, logical: const Size(390, 1500));
      await t.pumpWidget(shotHost(_sheet(), brightness: b));
      await t.pumpAndSettle();
      await snap(t, 'illustrations_${b.name}');
    });
  }
}
