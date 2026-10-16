import 'package:flutter/material.dart';
import 'package:marriage_connect/src/core/widgets/widgets.dart';

/// Every kit component / state widget in its meaningful variants. The golden
/// and overflow tests iterate this map so a new component cannot be added
/// without being covered (see kit_coverage test).
final Map<String, Widget Function()> kitCases = {
  'button_primary': () => McButton(label: 'Continue', onPressed: () {}),
  'button_secondary': () => McButton(
        label: 'Choose another photo',
        onPressed: () {},
        kind: McButtonKind.secondary,
        icon: Icons.photo_outlined,
      ),
  'button_text': () => McButton(
        label: 'Skip for now',
        onPressed: () {},
        kind: McButtonKind.text,
      ),
  'button_destructive': () => McButton(
        label: 'Delete my account',
        onPressed: () {},
        kind: McButtonKind.destructive,
      ),
  'button_loading': () =>
      McButton(label: 'Sending interest', onPressed: () {}, loading: true),
  'button_disabled': () => const McButton(label: 'Continue', onPressed: null),
  'text_field': () => const McTextField(
        label: 'Display name',
        helper: 'Shown on your profile. Not your legal name.',
        hint: 'e.g. Sarah',
      ),
  'text_field_error': () => const McTextField(
        label: 'Phone number',
        error: "That number doesn't look right. Check it and try again.",
      ),
  'text_field_optional': () => const McTextField(
        label: 'Church or mosque',
        optional: true,
      ),
  'card': () => const McCard(
        child: Text('Plain content inside a card that may wrap onto lines.'),
      ),
  'card_tappable': () => McCard(
        onTap: () {},
        child: const Text('Tap the whole card'),
      ),
  'profile_card': () => ProfileCard(
        displayName: 'Grace',
        age: 29,
        place: 'Kampala',
        summary: 'Teacher who loves long walks, cooking and Sunday lunches '
            'with family.',
        verified: true,
        onTap: () {},
      ),
  'profile_card_minimal': () => const ProfileCard(displayName: 'Daniel'),
  'verification_badge': () => const VerificationBadge(),
  'verification_badge_compact': () => const VerificationBadge(compact: true),
  'status_chip_neutral': () => const StatusChip(label: 'Draft'),
  'status_chip_info': () =>
      const StatusChip(label: 'Waiting for reply', tone: StatusTone.info),
  'status_chip_success': () => const StatusChip(
        label: 'Matched',
        tone: StatusTone.success,
        icon: Icons.favorite,
      ),
  'status_chip_warning': () =>
      const StatusChip(label: 'Needs review', tone: StatusTone.warning),
  'status_chip_error': () =>
      const StatusChip(label: 'Declined', tone: StatusTone.error),
  'bottom_sheet': () => BottomSheetScaffold(
        title: 'Send an interest',
        actions: [
          McButton(label: 'Send interest', onPressed: () {}),
          McButton(
            label: 'Cancel',
            onPressed: () {},
            kind: McButtonKind.text,
          ),
        ],
        child: const Text(
          'Your description goes to them straight away. You can write a '
          'short note too.',
        ),
      ),
  'consent_unchecked': () => ConsentTile(
        title: 'I agree to the Terms of Service',
        description: 'You can read them first. You can withdraw later.',
        onChanged: (_) {},
      ),
  'consent_checked': () => ConsentTile(
        title: 'Use my answers to find compatible people',
        value: true,
        onChanged: (_) {},
      ),
  'consent_error': () => ConsentTile(
        title: 'I confirm I am 18 or older',
        error: 'Please confirm to continue.',
        onChanged: (_) {},
      ),
  'membership_trial': () => const MembershipBanner(
        kind: MembershipBannerKind.trial,
        date: '17 Oct, 14:00',
      ),
  'membership_active': () => MembershipBanner(
        kind: MembershipBannerKind.active,
        date: '16 Nov 2026',
        actionLabel: 'Manage',
        onAction: () {},
      ),
  'membership_ended': () => MembershipBanner(
        kind: MembershipBannerKind.ended,
        actionLabel: 'See membership',
        onAction: () {},
      ),
  'safety_tip': () => const SafetyTip(
        message: 'Meet in a public place and tell someone you trust where '
            "you're going.",
      ),
  'safety_tip_action': () => SafetyTip(
        title: 'Before you meet',
        message: 'Keep conversations in the app until you feel comfortable.',
        actionLabel: 'Learn more',
        onAction: () {},
      ),
  'state_empty': EmptyState.new,
  'state_error': () => ErrorState(onRetry: () {}),
  'state_offline': () => OfflineState(onRetry: () {}),
  'state_restricted': () =>
      const RestrictedState(reason: 'Your membership has ended.'),
  'offline_banner': () => const OfflineBanner(),
};

/// Cases that fill the screen (own scroll/centre) and so are hosted without
/// the padded top-aligned wrapper.
const fullScreenCases = {
  'state_empty',
  'state_error',
  'state_offline',
  'state_restricted',
  'bottom_sheet',
};
