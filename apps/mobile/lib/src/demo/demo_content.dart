// Static sample content for Demo mode: the question set, membership
// products, and short chat scripts. All invented; prices are placeholders
// (the same planning assumptions the backend seeds: UGX 20,000 / 50,000).

typedef Json = Map<String, Object?>;

Json _q(
  String key,
  String dimension,
  String prompt,
  List<String> options, {
  bool core = true,
  bool dealbreaker = false,
  String type = 'single',
  String? consent,
}) =>
    {
      'key': key,
      'dimension': dimension,
      'type': type,
      'prompt': prompt,
      'is_core': core,
      'is_special': consent != null,
      'allow_dealbreaker': dealbreaker,
      if (consent != null) 'consent_required': consent,
      'options': [
        for (final o in options)
          {'value': o.toLowerCase().replaceAll(' ', '_'), 'label': o},
      ],
    };

/// The full question set: ten core questions (eight are enough to go live),
/// optional ones, a scale, a multi-choice and two consent-gated special ones.
List<Json> demoQuestions() => [
      _q(
        'q1',
        'intent',
        'When would you like to marry?',
        ['Within a year', 'In 1 to 2 years', 'No fixed time'],
      ),
      _q(
        'q2',
        'children',
        'Do you want children?',
        ['Yes', 'No', 'Not sure'],
        dealbreaker: true,
      ),
      _q(
        'q3',
        'children',
        'How many children would you like?',
        ['1 to 2', '3 to 4', 'More than 4'],
      ),
      _q(
        'q4',
        'location',
        'Where would you like to live after marriage?',
        ['In town', 'In the village', 'Anywhere'],
      ),
      _q(
        'q5',
        'family',
        'How close are you to your family?',
        ['Very close', 'Close', 'Independent'],
      ),
      _q(
        'q6',
        'roles',
        'Who should manage the household money?',
        ['Both of us', 'Husband', 'Wife'],
      ),
      _q(
        'q7',
        'communication',
        'After a disagreement you usually...',
        ['Talk it out at once', 'Take time first', 'Ask family to help'],
      ),
      _q(
        'q8',
        'lifestyle',
        'Your ideal weekend is...',
        ['At home', 'With family', 'Out and about'],
      ),
      _q(
        'q9',
        'location',
        'Would you move town for your partner?',
        ['Yes', 'Maybe', 'No'],
      ),
      _q(
        'q10',
        'family',
        'How often do you want to visit family?',
        ['Weekly', 'Monthly', 'Rarely'],
      ),
      {
        'key': 'q11',
        'dimension': 'lifestyle',
        'type': 'scale',
        'prompt': 'How tidy do you like your home?',
        'is_core': false,
        'is_special': false,
        'allow_dealbreaker': false,
        'options': {
          'min': 1,
          'max': 5,
          'min_label': 'Relaxed',
          'max_label': 'Very tidy',
        },
      },
      _q(
        'q12',
        'communication',
        'Which languages would you like spoken at home?',
        ['English', 'Luganda', 'Runyankole', 'Luo', 'Swahili'],
        core: false,
        type: 'multi',
      ),
      _q(
        'q13',
        'lifestyle',
        'Do you drink alcohol?',
        ['Never', 'Sometimes', 'Often'],
        core: false,
        dealbreaker: true,
      ),
      _q(
        'q14',
        'roles',
        'Should both of you work after marriage?',
        ['Yes, both', 'One of us', 'Open to either'],
        core: false,
      ),
      _q(
        'q15',
        'faith',
        'How important is faith in your daily life?',
        ['Very important', 'Somewhat', 'Not very'],
        core: false,
        consent: 'special_religion',
      ),
      _q(
        'q16',
        'money',
        'How do you feel about supporting relatives financially?',
        ['Gladly, within limits', 'Only in emergencies', 'I prefer not to'],
        core: false,
        consent: 'special_finance',
      ),
    ];

/// Membership products (placeholder prices, UGX has no minor unit).
List<Json> demoProducts() => [
      {
        'code': 'membership_1m',
        'duration_days': 30,
        'price_minor': 20000,
        'currency': 'UGX',
        'store_product_id': 'membership_1m',
      },
      {
        'code': 'membership_3m',
        'duration_days': 90,
        'price_minor': 50000,
        'currency': 'UGX',
        'store_product_id': 'membership_3m',
      },
    ];

/// Replies a match sends after you write, in order (then it cycles).
const demoReplies = <String>[
  'Hello! So nice to hear from you 😊',
  'I am doing well, thank you. How was your day?',
  'That sounds lovely. Tell me more about your family.',
  'Ha ha, I like that. What do you enjoy doing on weekends?',
  'I would love to talk more. Are you free this evening?',
  'Thank you for being so open with me. I appreciate it.',
];

/// A short, warm opening chat per seeded match: (fromMe, text, minutes ago).
/// The newest entries are the ones the other person wrote last, so a match
/// can open with unread messages.
const demoChatScripts = <List<(bool, String, int)>>[
  [
    (false, 'Hello! Thank you for accepting my interest.', 1500),
    (true, 'Hello, nice to meet you. I liked your introduction.', 1490),
    (false, 'Thank you! What do you do for work?', 1480),
    (true, 'I am a nurse at Mulago. And you?', 1470),
    (false, 'Ah, a nurse, that is a noble job. I teach primary school.', 1440),
    (true, 'I think we will have a lot to talk about 😊', 1430),
    (false, 'Are you free to chat on Saturday afternoon?', 95),
    (false, 'I can tell you about my family and my plans.', 94),
  ],
  [
    (true, 'Good evening, thank you for your interest.', 4300),
    (false, 'Good evening! I hope your week went well.', 4290),
    (true, 'It did, thank you. How is Jinja?', 4285),
    (
      false,
      'Peaceful as always. Come and see the source of the Nile one day.',
      4280
    ),
    (true, 'I would like that very much.', 4270),
  ],
  [
    (false, 'Hi, I am glad we matched.', 600),
    (
      false,
      'Please send me some airtime so we can talk, I am out of data.',
      590
    ),
  ],
];

/// Which seeded messages carry the scam-style safety tip (chat script index,
/// message index): a money request, so the Safety tip shows up.
const demoSafetyTipAt = <(int, int)>{(2, 1)};
