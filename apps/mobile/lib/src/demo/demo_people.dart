// Sample members for Demo mode. Every person here is invented (first names
// only, like the real app) and every photo is a code-drawn avatar
// (`demo://avatar/<seed>?woman=1`), so nothing needs a network.
import 'package:marriage_connect/src/core/illustrations/sample_avatar_url.dart';

/// One invented member.
class DemoMember {
  const DemoMember({
    required this.id,
    required this.name,
    required this.woman,
    required this.age,
    required this.district,
    required this.intention,
    required this.timeline,
    required this.maritalStatus,
    required this.hasChildren,
    required this.wantsChildren,
    required this.languages,
    required this.occupation,
    required this.education,
    required this.intro,
    required this.why,
    required this.discuss,
    required this.photoSeeds,
    required this.scoreBand,
  });

  final String id;
  final String name;
  final bool woman;
  final int age;
  final String district;
  final String intention;
  final String timeline;
  final String maritalStatus;
  final String hasChildren;
  final String wantsChildren;
  final List<String> languages;
  final String occupation;
  final String education;
  final String intro;
  final List<String> why;
  final List<String> discuss;
  final List<String> photoSeeds;
  final String scoreBand;

  List<String> get photoUrls => [
        for (final s in photoSeeds) sampleAvatarUrl(s, woman: woman),
      ];

  String get maritalLabel => switch (maritalStatus) {
        'divorced' => 'Divorced',
        'widowed' => 'Widowed',
        _ => 'Never married',
      };
}

const _women = <String>[
  'Aisha',
  'Barbra',
  'Brenda',
  'Christine',
  'Doreen',
  'Esther',
  'Faith',
  'Gloria',
  'Harriet',
  'Irene',
  'Joan',
  'Josephine',
  'Lillian',
  'Margaret',
  'Naomi',
  'Olivia',
  'Patience',
  'Prossy',
  'Rebecca',
  'Sarah',
  'Stella',
  'Sharon',
  'Teddy',
  'Winnie',
  'Mercy',
  'Ruth',
  'Diana',
  'Racheal',
  'Annet',
  'Juliet',
];

const _men = <String>[
  'Abdul',
  'Brian',
  'Charles',
  'Daniel',
  'Denis',
  'Emmanuel',
  'Fred',
  'Geoffrey',
  'Henry',
  'Isaac',
  'Jackson',
  'Joseph',
  'Kenneth',
  'Lawrence',
  'Moses',
  'Nelson',
  'Patrick',
  'Peter',
  'Richard',
  'Samuel',
  'Solomon',
  'Timothy',
  'Tonny',
  'Vincent',
  'Wilson',
  'Andrew',
  'David',
  'Ivan',
  'Simon',
  'Ronald',
];

const _districts = <String>[
  'Kampala',
  'Wakiso',
  'Mukono',
  'Jinja',
  'Mbarara',
  'Gulu',
  'Lira',
  'Mbale',
  'Masaka',
  'Kabarole',
  'Arua',
  'Soroti',
  'Kabale',
  'Hoima',
  'Iganga',
  'Tororo',
  'Kasese',
  'Mityana',
  'Luwero',
  'Entebbe',
];

const _jobs = <(String, String)>[
  ('Primary school teacher', 'bachelors'),
  ('Nurse', 'certificate_diploma'),
  ('Accountant', 'bachelors'),
  ('Software developer', 'bachelors'),
  ('Shop owner', 'secondary'),
  ('Civil engineer', 'bachelors'),
  ('Tailor and designer', 'certificate_diploma'),
  ('Agricultural officer', 'bachelors'),
  ('Boda-boda fleet owner', 'secondary'),
  ('Bank teller', 'bachelors'),
  ('Lecturer', 'postgraduate'),
  ('Photographer', 'certificate_diploma'),
  ('Hairdresser and salon owner', 'secondary'),
  ('Pharmacist', 'bachelors'),
  ('Police officer', 'certificate_diploma'),
  ('Coffee farmer', 'secondary'),
  ('Radio presenter', 'bachelors'),
  ('Lawyer', 'postgraduate'),
  ('Caterer', 'certificate_diploma'),
  ('Doctor', 'postgraduate'),
];

const _likes = <String>[
  'singing in my church choir',
  'cooking matooke and groundnut sauce on Sundays',
  'long walks and watching football',
  'gardening and small business ideas',
  'reading and quiet evenings at home',
  'travelling to see new places in Uganda',
  'cheering for the Cranes and the Cranes only',
  'music, dancing and good conversation',
  'volunteering with young people',
  'visiting my parents in the village',
  'learning something new every month',
  'watching Nollywood with a cup of tea',
];

const _hopes = <String>[
  'someone kind, honest and ready to build a home together.',
  'a partner who values family and prays, works and laughs with me.',
  'a calm, respectful person who communicates openly.',
  'a hard-working partner who also knows how to rest.',
  'a loyal friend first, then a husband or wife.',
  'someone serious about marriage and not about games.',
];

const _why = <String>[
  'You both want children',
  'You are both close to your families',
  'You both hope to marry within two years',
  'You would both like to live in town',
  'You solve disagreements the same way: by talking',
  'Your ideal weekends look alike',
  'You are close in age',
  'You both live around Kampala',
  'You share a similar view of who manages money',
  'You both speak Luganda and English',
];

const _discuss = <String>[
  'Different views on where to live',
  'One of you wants more children than the other',
  'You visit family at different rhythms',
  'Different ideas about weekends',
  'You may see household money differently',
];

const _timelines = <String>['within_1y', '1_2y', '2_4y', 'open'];
const _languageSets = <List<String>>[
  ['en', 'lg'],
  ['en', 'lg', 'sw'],
  ['en', 'nyn'],
  ['en', 'ach'],
  ['en', 'teo'],
  ['en', 'lg', 'nyn'],
];

/// The ~60 invented members (30 women, 30 men). Deterministic: the same
/// build always draws the same people.
List<DemoMember> buildDemoMembers() {
  final out = <DemoMember>[];
  for (var i = 0; i < _women.length; i++) {
    out.add(_make(i, woman: true, name: _women[i]));
  }
  for (var i = 0; i < _men.length; i++) {
    out.add(_make(i, woman: false, name: _men[i]));
  }
  return out;
}

DemoMember _make(int i, {required bool woman, required String name}) {
  final k = woman ? i : i + 7; // offsets so the sexes do not mirror
  final job = _jobs[(k * 3 + 1) % _jobs.length];
  final district =
      _districts[(k * 3 + k ~/ 4 + (woman ? 0 : 2)) % _districts.length];
  final age = 24 + (k * 7) % 17; // 24..40
  final divorced = k % 9 == 4;
  final widowed = k % 13 == 6;
  final hasKids = divorced || widowed || k % 7 == 3;
  final like1 = _likes[k % _likes.length];
  final like2 = _likes[(k + 5) % _likes.length];
  final hope = _hopes[(k * 2) % _hopes.length];
  final intro = 'I am $age, living in $district, and I work as a '
      '${job.$1.toLowerCase()}. In my free time I enjoy $like1 and '
      '$like2. I am looking for $hope '
      '${hasKids ? 'I have a child I love dearly and I would like my future family to be a happy one. ' : 'I would love to start a family of my own one day. '}'
      'Let us talk and see where it goes.';
  final id = 'm-${woman ? 'w' : 'm'}${(i + 1).toString().padLeft(2, '0')}';
  final why = [
    _why[k % _why.length],
    _why[(k + 3) % _why.length],
    _why[(k + 6) % _why.length],
  ];
  return DemoMember(
    id: id,
    name: name,
    woman: woman,
    age: age,
    district: district,
    intention: k % 4 == 0 ? 'marriage_open_timeline' : 'marriage_soon',
    timeline: _timelines[k % _timelines.length],
    maritalStatus: divorced
        ? 'divorced'
        : widowed
            ? 'widowed'
            : 'never_married',
    hasChildren: hasKids ? 'yes_living_with_me' : 'no',
    wantsChildren: k % 6 == 5 ? 'unsure' : (k % 11 == 7 ? 'no' : 'yes'),
    languages: _languageSets[k % _languageSets.length],
    occupation: job.$1,
    education: job.$2,
    intro: intro,
    why: why,
    discuss: [_discuss[k % _discuss.length]],
    photoSeeds: ['$id-a', '$id-b', '$id-c'],
    scoreBand: const ['strong', 'good', 'possible'][k % 3],
  );
}
