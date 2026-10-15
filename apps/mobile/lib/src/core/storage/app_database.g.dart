// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OutboxMessagesTable extends OutboxMessages
    with TableInfo<$OutboxMessagesTable, OutboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientMsgIdMeta =
      const VerificationMeta('clientMsgId');
  @override
  late final GeneratedColumn<String> clientMsgId = GeneratedColumn<String>(
      'client_msg_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchIdMeta =
      const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
      'match_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _failedCodeMeta =
      const VerificationMeta('failedCode');
  @override
  late final GeneratedColumn<String> failedCode = GeneratedColumn<String>(
      'failed_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [clientMsgId, matchId, body, attempts, failedCode, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_messages';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_msg_id')) {
      context.handle(
          _clientMsgIdMeta,
          clientMsgId.isAcceptableOrUnknown(
              data['client_msg_id']!, _clientMsgIdMeta));
    } else if (isInserting) {
      context.missing(_clientMsgIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta,
          matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('failed_code')) {
      context.handle(
          _failedCodeMeta,
          failedCode.isAcceptableOrUnknown(
              data['failed_code']!, _failedCodeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientMsgId};
  @override
  OutboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxMessage(
      clientMsgId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_msg_id'])!,
      matchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_id'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      failedCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}failed_code']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutboxMessagesTable createAlias(String alias) {
    return $OutboxMessagesTable(attachedDatabase, alias);
  }
}

class OutboxMessage extends DataClass implements Insertable<OutboxMessage> {
  final String clientMsgId;
  final String matchId;
  final String body;
  final int attempts;
  final String? failedCode;
  final DateTime createdAt;
  const OutboxMessage(
      {required this.clientMsgId,
      required this.matchId,
      required this.body,
      required this.attempts,
      this.failedCode,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_msg_id'] = Variable<String>(clientMsgId);
    map['match_id'] = Variable<String>(matchId);
    map['body'] = Variable<String>(body);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || failedCode != null) {
      map['failed_code'] = Variable<String>(failedCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return OutboxMessagesCompanion(
      clientMsgId: Value(clientMsgId),
      matchId: Value(matchId),
      body: Value(body),
      attempts: Value(attempts),
      failedCode: failedCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failedCode),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxMessage(
      clientMsgId: serializer.fromJson<String>(json['clientMsgId']),
      matchId: serializer.fromJson<String>(json['matchId']),
      body: serializer.fromJson<String>(json['body']),
      attempts: serializer.fromJson<int>(json['attempts']),
      failedCode: serializer.fromJson<String?>(json['failedCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientMsgId': serializer.toJson<String>(clientMsgId),
      'matchId': serializer.toJson<String>(matchId),
      'body': serializer.toJson<String>(body),
      'attempts': serializer.toJson<int>(attempts),
      'failedCode': serializer.toJson<String?>(failedCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxMessage copyWith(
          {String? clientMsgId,
          String? matchId,
          String? body,
          int? attempts,
          Value<String?> failedCode = const Value.absent(),
          DateTime? createdAt}) =>
      OutboxMessage(
        clientMsgId: clientMsgId ?? this.clientMsgId,
        matchId: matchId ?? this.matchId,
        body: body ?? this.body,
        attempts: attempts ?? this.attempts,
        failedCode: failedCode.present ? failedCode.value : this.failedCode,
        createdAt: createdAt ?? this.createdAt,
      );
  OutboxMessage copyWithCompanion(OutboxMessagesCompanion data) {
    return OutboxMessage(
      clientMsgId:
          data.clientMsgId.present ? data.clientMsgId.value : this.clientMsgId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      body: data.body.present ? data.body.value : this.body,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      failedCode:
          data.failedCode.present ? data.failedCode.value : this.failedCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessage(')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('matchId: $matchId, ')
          ..write('body: $body, ')
          ..write('attempts: $attempts, ')
          ..write('failedCode: $failedCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(clientMsgId, matchId, body, attempts, failedCode, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxMessage &&
          other.clientMsgId == this.clientMsgId &&
          other.matchId == this.matchId &&
          other.body == this.body &&
          other.attempts == this.attempts &&
          other.failedCode == this.failedCode &&
          other.createdAt == this.createdAt);
}

class OutboxMessagesCompanion extends UpdateCompanion<OutboxMessage> {
  final Value<String> clientMsgId;
  final Value<String> matchId;
  final Value<String> body;
  final Value<int> attempts;
  final Value<String?> failedCode;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxMessagesCompanion({
    this.clientMsgId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.body = const Value.absent(),
    this.attempts = const Value.absent(),
    this.failedCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxMessagesCompanion.insert({
    required String clientMsgId,
    required String matchId,
    required String body,
    this.attempts = const Value.absent(),
    this.failedCode = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : clientMsgId = Value(clientMsgId),
        matchId = Value(matchId),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<OutboxMessage> custom({
    Expression<String>? clientMsgId,
    Expression<String>? matchId,
    Expression<String>? body,
    Expression<int>? attempts,
    Expression<String>? failedCode,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientMsgId != null) 'client_msg_id': clientMsgId,
      if (matchId != null) 'match_id': matchId,
      if (body != null) 'body': body,
      if (attempts != null) 'attempts': attempts,
      if (failedCode != null) 'failed_code': failedCode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxMessagesCompanion copyWith(
      {Value<String>? clientMsgId,
      Value<String>? matchId,
      Value<String>? body,
      Value<int>? attempts,
      Value<String?>? failedCode,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return OutboxMessagesCompanion(
      clientMsgId: clientMsgId ?? this.clientMsgId,
      matchId: matchId ?? this.matchId,
      body: body ?? this.body,
      attempts: attempts ?? this.attempts,
      failedCode: failedCode ?? this.failedCode,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientMsgId.present) {
      map['client_msg_id'] = Variable<String>(clientMsgId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (failedCode.present) {
      map['failed_code'] = Variable<String>(failedCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessagesCompanion(')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('matchId: $matchId, ')
          ..write('body: $body, ')
          ..write('attempts: $attempts, ')
          ..write('failedCode: $failedCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMatchesTable extends CachedMatches
    with TableInfo<$CachedMatchesTable, CachedMatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _memberIdMeta =
      const VerificationMeta('memberId');
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
      'member_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
      'age', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _districtMeta =
      const VerificationMeta('district');
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
      'district', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _maritalStatusLabelMeta =
      const VerificationMeta('maritalStatusLabel');
  @override
  late final GeneratedColumn<String> maritalStatusLabel =
      GeneratedColumn<String>('marital_status_label', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _photoVerifiedMeta =
      const VerificationMeta('photoVerified');
  @override
  late final GeneratedColumn<bool> photoVerified = GeneratedColumn<bool>(
      'photo_verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("photo_verified" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _photoUrlMeta =
      const VerificationMeta('photoUrl');
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
      'photo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        memberId,
        displayName,
        age,
        district,
        maritalStatusLabel,
        photoVerified,
        photoUrl,
        createdAt,
        position
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_matches';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMatche> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(_memberIdMeta,
          memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta));
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
          _ageMeta, age.isAcceptableOrUnknown(data['age']!, _ageMeta));
    }
    if (data.containsKey('district')) {
      context.handle(_districtMeta,
          district.isAcceptableOrUnknown(data['district']!, _districtMeta));
    }
    if (data.containsKey('marital_status_label')) {
      context.handle(
          _maritalStatusLabelMeta,
          maritalStatusLabel.isAcceptableOrUnknown(
              data['marital_status_label']!, _maritalStatusLabelMeta));
    }
    if (data.containsKey('photo_verified')) {
      context.handle(
          _photoVerifiedMeta,
          photoVerified.isAcceptableOrUnknown(
              data['photo_verified']!, _photoVerifiedMeta));
    }
    if (data.containsKey('photo_url')) {
      context.handle(_photoUrlMeta,
          photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMatche(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      memberId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}member_id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      age: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}age']),
      district: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}district'])!,
      maritalStatusLabel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}marital_status_label']),
      photoVerified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}photo_verified'])!,
      photoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_url']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $CachedMatchesTable createAlias(String alias) {
    return $CachedMatchesTable(attachedDatabase, alias);
  }
}

class CachedMatche extends DataClass implements Insertable<CachedMatche> {
  final String id;
  final String memberId;
  final String displayName;
  final int? age;
  final String district;
  final String? maritalStatusLabel;
  final bool photoVerified;
  final String? photoUrl;
  final DateTime createdAt;
  final int position;
  const CachedMatche(
      {required this.id,
      required this.memberId,
      required this.displayName,
      this.age,
      required this.district,
      this.maritalStatusLabel,
      required this.photoVerified,
      this.photoUrl,
      required this.createdAt,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['member_id'] = Variable<String>(memberId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || age != null) {
      map['age'] = Variable<int>(age);
    }
    map['district'] = Variable<String>(district);
    if (!nullToAbsent || maritalStatusLabel != null) {
      map['marital_status_label'] = Variable<String>(maritalStatusLabel);
    }
    map['photo_verified'] = Variable<bool>(photoVerified);
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['position'] = Variable<int>(position);
    return map;
  }

  CachedMatchesCompanion toCompanion(bool nullToAbsent) {
    return CachedMatchesCompanion(
      id: Value(id),
      memberId: Value(memberId),
      displayName: Value(displayName),
      age: age == null && nullToAbsent ? const Value.absent() : Value(age),
      district: Value(district),
      maritalStatusLabel: maritalStatusLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(maritalStatusLabel),
      photoVerified: Value(photoVerified),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      createdAt: Value(createdAt),
      position: Value(position),
    );
  }

  factory CachedMatche.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMatche(
      id: serializer.fromJson<String>(json['id']),
      memberId: serializer.fromJson<String>(json['memberId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      age: serializer.fromJson<int?>(json['age']),
      district: serializer.fromJson<String>(json['district']),
      maritalStatusLabel:
          serializer.fromJson<String?>(json['maritalStatusLabel']),
      photoVerified: serializer.fromJson<bool>(json['photoVerified']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memberId': serializer.toJson<String>(memberId),
      'displayName': serializer.toJson<String>(displayName),
      'age': serializer.toJson<int?>(age),
      'district': serializer.toJson<String>(district),
      'maritalStatusLabel': serializer.toJson<String?>(maritalStatusLabel),
      'photoVerified': serializer.toJson<bool>(photoVerified),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'position': serializer.toJson<int>(position),
    };
  }

  CachedMatche copyWith(
          {String? id,
          String? memberId,
          String? displayName,
          Value<int?> age = const Value.absent(),
          String? district,
          Value<String?> maritalStatusLabel = const Value.absent(),
          bool? photoVerified,
          Value<String?> photoUrl = const Value.absent(),
          DateTime? createdAt,
          int? position}) =>
      CachedMatche(
        id: id ?? this.id,
        memberId: memberId ?? this.memberId,
        displayName: displayName ?? this.displayName,
        age: age.present ? age.value : this.age,
        district: district ?? this.district,
        maritalStatusLabel: maritalStatusLabel.present
            ? maritalStatusLabel.value
            : this.maritalStatusLabel,
        photoVerified: photoVerified ?? this.photoVerified,
        photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
        createdAt: createdAt ?? this.createdAt,
        position: position ?? this.position,
      );
  CachedMatche copyWithCompanion(CachedMatchesCompanion data) {
    return CachedMatche(
      id: data.id.present ? data.id.value : this.id,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      age: data.age.present ? data.age.value : this.age,
      district: data.district.present ? data.district.value : this.district,
      maritalStatusLabel: data.maritalStatusLabel.present
          ? data.maritalStatusLabel.value
          : this.maritalStatusLabel,
      photoVerified: data.photoVerified.present
          ? data.photoVerified.value
          : this.photoVerified,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMatche(')
          ..write('id: $id, ')
          ..write('memberId: $memberId, ')
          ..write('displayName: $displayName, ')
          ..write('age: $age, ')
          ..write('district: $district, ')
          ..write('maritalStatusLabel: $maritalStatusLabel, ')
          ..write('photoVerified: $photoVerified, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, memberId, displayName, age, district,
      maritalStatusLabel, photoVerified, photoUrl, createdAt, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMatche &&
          other.id == this.id &&
          other.memberId == this.memberId &&
          other.displayName == this.displayName &&
          other.age == this.age &&
          other.district == this.district &&
          other.maritalStatusLabel == this.maritalStatusLabel &&
          other.photoVerified == this.photoVerified &&
          other.photoUrl == this.photoUrl &&
          other.createdAt == this.createdAt &&
          other.position == this.position);
}

class CachedMatchesCompanion extends UpdateCompanion<CachedMatche> {
  final Value<String> id;
  final Value<String> memberId;
  final Value<String> displayName;
  final Value<int?> age;
  final Value<String> district;
  final Value<String?> maritalStatusLabel;
  final Value<bool> photoVerified;
  final Value<String?> photoUrl;
  final Value<DateTime> createdAt;
  final Value<int> position;
  final Value<int> rowid;
  const CachedMatchesCompanion({
    this.id = const Value.absent(),
    this.memberId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.age = const Value.absent(),
    this.district = const Value.absent(),
    this.maritalStatusLabel = const Value.absent(),
    this.photoVerified = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMatchesCompanion.insert({
    required String id,
    required String memberId,
    required String displayName,
    this.age = const Value.absent(),
    this.district = const Value.absent(),
    this.maritalStatusLabel = const Value.absent(),
    this.photoVerified = const Value.absent(),
    this.photoUrl = const Value.absent(),
    required DateTime createdAt,
    required int position,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        memberId = Value(memberId),
        displayName = Value(displayName),
        createdAt = Value(createdAt),
        position = Value(position);
  static Insertable<CachedMatche> custom({
    Expression<String>? id,
    Expression<String>? memberId,
    Expression<String>? displayName,
    Expression<int>? age,
    Expression<String>? district,
    Expression<String>? maritalStatusLabel,
    Expression<bool>? photoVerified,
    Expression<String>? photoUrl,
    Expression<DateTime>? createdAt,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memberId != null) 'member_id': memberId,
      if (displayName != null) 'display_name': displayName,
      if (age != null) 'age': age,
      if (district != null) 'district': district,
      if (maritalStatusLabel != null)
        'marital_status_label': maritalStatusLabel,
      if (photoVerified != null) 'photo_verified': photoVerified,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMatchesCompanion copyWith(
      {Value<String>? id,
      Value<String>? memberId,
      Value<String>? displayName,
      Value<int?>? age,
      Value<String>? district,
      Value<String?>? maritalStatusLabel,
      Value<bool>? photoVerified,
      Value<String?>? photoUrl,
      Value<DateTime>? createdAt,
      Value<int>? position,
      Value<int>? rowid}) {
    return CachedMatchesCompanion(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      district: district ?? this.district,
      maritalStatusLabel: maritalStatusLabel ?? this.maritalStatusLabel,
      photoVerified: photoVerified ?? this.photoVerified,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (maritalStatusLabel.present) {
      map['marital_status_label'] = Variable<String>(maritalStatusLabel.value);
    }
    if (photoVerified.present) {
      map['photo_verified'] = Variable<bool>(photoVerified.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMatchesCompanion(')
          ..write('id: $id, ')
          ..write('memberId: $memberId, ')
          ..write('displayName: $displayName, ')
          ..write('age: $age, ')
          ..write('district: $district, ')
          ..write('maritalStatusLabel: $maritalStatusLabel, ')
          ..write('photoVerified: $photoVerified, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMessagesTable extends CachedMessages
    with TableInfo<$CachedMessagesTable, CachedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchIdMeta =
      const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
      'match_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientMsgIdMeta =
      const VerificationMeta('clientMsgId');
  @override
  late final GeneratedColumn<String> clientMsgId = GeneratedColumn<String>(
      'client_msg_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
      'sender', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaJsonMeta =
      const VerificationMeta('mediaJson');
  @override
  late final GeneratedColumn<String> mediaJson = GeneratedColumn<String>(
      'media_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deliveredAtMeta =
      const VerificationMeta('deliveredAt');
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
      'delivered_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
      'read_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _safetyTipMeta =
      const VerificationMeta('safetyTip');
  @override
  late final GeneratedColumn<bool> safetyTip = GeneratedColumn<bool>(
      'safety_tip', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("safety_tip" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        matchId,
        clientMsgId,
        sender,
        kind,
        body,
        mediaJson,
        createdAt,
        deliveredAt,
        readAt,
        safetyTip,
        deleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_messages';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta,
          matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('client_msg_id')) {
      context.handle(
          _clientMsgIdMeta,
          clientMsgId.isAcceptableOrUnknown(
              data['client_msg_id']!, _clientMsgIdMeta));
    }
    if (data.containsKey('sender')) {
      context.handle(_senderMeta,
          sender.isAcceptableOrUnknown(data['sender']!, _senderMeta));
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('media_json')) {
      context.handle(_mediaJsonMeta,
          mediaJson.isAcceptableOrUnknown(data['media_json']!, _mediaJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
          _deliveredAtMeta,
          deliveredAt.isAcceptableOrUnknown(
              data['delivered_at']!, _deliveredAtMeta));
    }
    if (data.containsKey('read_at')) {
      context.handle(_readAtMeta,
          readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta));
    }
    if (data.containsKey('safety_tip')) {
      context.handle(_safetyTipMeta,
          safetyTip.isAcceptableOrUnknown(data['safety_tip']!, _safetyTipMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      matchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_id'])!,
      clientMsgId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_msg_id']),
      sender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body']),
      mediaJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      deliveredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}delivered_at']),
      readAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}read_at']),
      safetyTip: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}safety_tip'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
    );
  }

  @override
  $CachedMessagesTable createAlias(String alias) {
    return $CachedMessagesTable(attachedDatabase, alias);
  }
}

class CachedMessage extends DataClass implements Insertable<CachedMessage> {
  final String id;
  final String matchId;
  final String? clientMsgId;
  final String sender;
  final String kind;
  final String? body;
  final String? mediaJson;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool safetyTip;
  final bool deleted;
  const CachedMessage(
      {required this.id,
      required this.matchId,
      this.clientMsgId,
      required this.sender,
      required this.kind,
      this.body,
      this.mediaJson,
      required this.createdAt,
      this.deliveredAt,
      this.readAt,
      required this.safetyTip,
      required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    if (!nullToAbsent || clientMsgId != null) {
      map['client_msg_id'] = Variable<String>(clientMsgId);
    }
    map['sender'] = Variable<String>(sender);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || mediaJson != null) {
      map['media_json'] = Variable<String>(mediaJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    map['safety_tip'] = Variable<bool>(safetyTip);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  CachedMessagesCompanion toCompanion(bool nullToAbsent) {
    return CachedMessagesCompanion(
      id: Value(id),
      matchId: Value(matchId),
      clientMsgId: clientMsgId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientMsgId),
      sender: Value(sender),
      kind: Value(kind),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      mediaJson: mediaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaJson),
      createdAt: Value(createdAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      readAt:
          readAt == null && nullToAbsent ? const Value.absent() : Value(readAt),
      safetyTip: Value(safetyTip),
      deleted: Value(deleted),
    );
  }

  factory CachedMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMessage(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      clientMsgId: serializer.fromJson<String?>(json['clientMsgId']),
      sender: serializer.fromJson<String>(json['sender']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String?>(json['body']),
      mediaJson: serializer.fromJson<String?>(json['mediaJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      safetyTip: serializer.fromJson<bool>(json['safetyTip']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'clientMsgId': serializer.toJson<String?>(clientMsgId),
      'sender': serializer.toJson<String>(sender),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String?>(body),
      'mediaJson': serializer.toJson<String?>(mediaJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'safetyTip': serializer.toJson<bool>(safetyTip),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  CachedMessage copyWith(
          {String? id,
          String? matchId,
          Value<String?> clientMsgId = const Value.absent(),
          String? sender,
          String? kind,
          Value<String?> body = const Value.absent(),
          Value<String?> mediaJson = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> deliveredAt = const Value.absent(),
          Value<DateTime?> readAt = const Value.absent(),
          bool? safetyTip,
          bool? deleted}) =>
      CachedMessage(
        id: id ?? this.id,
        matchId: matchId ?? this.matchId,
        clientMsgId: clientMsgId.present ? clientMsgId.value : this.clientMsgId,
        sender: sender ?? this.sender,
        kind: kind ?? this.kind,
        body: body.present ? body.value : this.body,
        mediaJson: mediaJson.present ? mediaJson.value : this.mediaJson,
        createdAt: createdAt ?? this.createdAt,
        deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
        readAt: readAt.present ? readAt.value : this.readAt,
        safetyTip: safetyTip ?? this.safetyTip,
        deleted: deleted ?? this.deleted,
      );
  CachedMessage copyWithCompanion(CachedMessagesCompanion data) {
    return CachedMessage(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      clientMsgId:
          data.clientMsgId.present ? data.clientMsgId.value : this.clientMsgId,
      sender: data.sender.present ? data.sender.value : this.sender,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      mediaJson: data.mediaJson.present ? data.mediaJson.value : this.mediaJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deliveredAt:
          data.deliveredAt.present ? data.deliveredAt.value : this.deliveredAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      safetyTip: data.safetyTip.present ? data.safetyTip.value : this.safetyTip,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessage(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('sender: $sender, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('safetyTip: $safetyTip, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matchId, clientMsgId, sender, kind, body,
      mediaJson, createdAt, deliveredAt, readAt, safetyTip, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMessage &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.clientMsgId == this.clientMsgId &&
          other.sender == this.sender &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.mediaJson == this.mediaJson &&
          other.createdAt == this.createdAt &&
          other.deliveredAt == this.deliveredAt &&
          other.readAt == this.readAt &&
          other.safetyTip == this.safetyTip &&
          other.deleted == this.deleted);
}

class CachedMessagesCompanion extends UpdateCompanion<CachedMessage> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String?> clientMsgId;
  final Value<String> sender;
  final Value<String> kind;
  final Value<String?> body;
  final Value<String?> mediaJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deliveredAt;
  final Value<DateTime?> readAt;
  final Value<bool> safetyTip;
  final Value<bool> deleted;
  final Value<int> rowid;
  const CachedMessagesCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.clientMsgId = const Value.absent(),
    this.sender = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.safetyTip = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMessagesCompanion.insert({
    required String id,
    required String matchId,
    this.clientMsgId = const Value.absent(),
    required String sender,
    required String kind,
    this.body = const Value.absent(),
    this.mediaJson = const Value.absent(),
    required DateTime createdAt,
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.safetyTip = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        matchId = Value(matchId),
        sender = Value(sender),
        kind = Value(kind),
        createdAt = Value(createdAt);
  static Insertable<CachedMessage> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? clientMsgId,
    Expression<String>? sender,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<String>? mediaJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deliveredAt,
    Expression<DateTime>? readAt,
    Expression<bool>? safetyTip,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (clientMsgId != null) 'client_msg_id': clientMsgId,
      if (sender != null) 'sender': sender,
      if (kind != null) 'kind': kind,
      if (body != null) 'body': body,
      if (mediaJson != null) 'media_json': mediaJson,
      if (createdAt != null) 'created_at': createdAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (readAt != null) 'read_at': readAt,
      if (safetyTip != null) 'safety_tip': safetyTip,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? matchId,
      Value<String?>? clientMsgId,
      Value<String>? sender,
      Value<String>? kind,
      Value<String?>? body,
      Value<String?>? mediaJson,
      Value<DateTime>? createdAt,
      Value<DateTime?>? deliveredAt,
      Value<DateTime?>? readAt,
      Value<bool>? safetyTip,
      Value<bool>? deleted,
      Value<int>? rowid}) {
    return CachedMessagesCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      sender: sender ?? this.sender,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      mediaJson: mediaJson ?? this.mediaJson,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      safetyTip: safetyTip ?? this.safetyTip,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (clientMsgId.present) {
      map['client_msg_id'] = Variable<String>(clientMsgId.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (mediaJson.present) {
      map['media_json'] = Variable<String>(mediaJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (safetyTip.present) {
      map['safety_tip'] = Variable<bool>(safetyTip.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('sender: $sender, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('safetyTip: $safetyTip, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OutboxMessagesTable outboxMessages = $OutboxMessagesTable(this);
  late final $CachedMatchesTable cachedMatches = $CachedMatchesTable(this);
  late final $CachedMessagesTable cachedMessages = $CachedMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [outboxMessages, cachedMatches, cachedMessages];
}

typedef $$OutboxMessagesTableCreateCompanionBuilder = OutboxMessagesCompanion
    Function({
  required String clientMsgId,
  required String matchId,
  required String body,
  Value<int> attempts,
  Value<String?> failedCode,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$OutboxMessagesTableUpdateCompanionBuilder = OutboxMessagesCompanion
    Function({
  Value<String> clientMsgId,
  Value<String> matchId,
  Value<String> body,
  Value<int> attempts,
  Value<String?> failedCode,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$OutboxMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get failedCode => $composableBuilder(
      column: $table.failedCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get failedCode => $composableBuilder(
      column: $table.failedCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get failedCode => $composableBuilder(
      column: $table.failedCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxMessagesTable,
    OutboxMessage,
    $$OutboxMessagesTableFilterComposer,
    $$OutboxMessagesTableOrderingComposer,
    $$OutboxMessagesTableAnnotationComposer,
    $$OutboxMessagesTableCreateCompanionBuilder,
    $$OutboxMessagesTableUpdateCompanionBuilder,
    (
      OutboxMessage,
      BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>
    ),
    OutboxMessage,
    PrefetchHooks Function()> {
  $$OutboxMessagesTableTableManager(
      _$AppDatabase db, $OutboxMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientMsgId = const Value.absent(),
            Value<String> matchId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> failedCode = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxMessagesCompanion(
            clientMsgId: clientMsgId,
            matchId: matchId,
            body: body,
            attempts: attempts,
            failedCode: failedCode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientMsgId,
            required String matchId,
            required String body,
            Value<int> attempts = const Value.absent(),
            Value<String?> failedCode = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxMessagesCompanion.insert(
            clientMsgId: clientMsgId,
            matchId: matchId,
            body: body,
            attempts: attempts,
            failedCode: failedCode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxMessagesTable, OutboxMessage>(table),
                    BaseReferences<_$AppDatabase, $OutboxMessagesTable,
                        OutboxMessage>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxMessagesTable,
    OutboxMessage,
    $$OutboxMessagesTableFilterComposer,
    $$OutboxMessagesTableOrderingComposer,
    $$OutboxMessagesTableAnnotationComposer,
    $$OutboxMessagesTableCreateCompanionBuilder,
    $$OutboxMessagesTableUpdateCompanionBuilder,
    (
      OutboxMessage,
      BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>
    ),
    OutboxMessage,
    PrefetchHooks Function()>;
typedef $$CachedMatchesTableCreateCompanionBuilder = CachedMatchesCompanion
    Function({
  required String id,
  required String memberId,
  required String displayName,
  Value<int?> age,
  Value<String> district,
  Value<String?> maritalStatusLabel,
  Value<bool> photoVerified,
  Value<String?> photoUrl,
  required DateTime createdAt,
  required int position,
  Value<int> rowid,
});
typedef $$CachedMatchesTableUpdateCompanionBuilder = CachedMatchesCompanion
    Function({
  Value<String> id,
  Value<String> memberId,
  Value<String> displayName,
  Value<int?> age,
  Value<String> district,
  Value<String?> maritalStatusLabel,
  Value<bool> photoVerified,
  Value<String?> photoUrl,
  Value<DateTime> createdAt,
  Value<int> position,
  Value<int> rowid,
});

class $$CachedMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMatchesTable> {
  $$CachedMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memberId => $composableBuilder(
      column: $table.memberId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get age => $composableBuilder(
      column: $table.age, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get district => $composableBuilder(
      column: $table.district, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get maritalStatusLabel => $composableBuilder(
      column: $table.maritalStatusLabel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get photoVerified => $composableBuilder(
      column: $table.photoVerified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));
}

class $$CachedMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMatchesTable> {
  $$CachedMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memberId => $composableBuilder(
      column: $table.memberId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get age => $composableBuilder(
      column: $table.age, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get district => $composableBuilder(
      column: $table.district, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get maritalStatusLabel => $composableBuilder(
      column: $table.maritalStatusLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get photoVerified => $composableBuilder(
      column: $table.photoVerified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));
}

class $$CachedMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMatchesTable> {
  $$CachedMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<String> get maritalStatusLabel => $composableBuilder(
      column: $table.maritalStatusLabel, builder: (column) => column);

  GeneratedColumn<bool> get photoVerified => $composableBuilder(
      column: $table.photoVerified, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$CachedMatchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedMatchesTable,
    CachedMatche,
    $$CachedMatchesTableFilterComposer,
    $$CachedMatchesTableOrderingComposer,
    $$CachedMatchesTableAnnotationComposer,
    $$CachedMatchesTableCreateCompanionBuilder,
    $$CachedMatchesTableUpdateCompanionBuilder,
    (
      CachedMatche,
      BaseReferences<_$AppDatabase, $CachedMatchesTable, CachedMatche>
    ),
    CachedMatche,
    PrefetchHooks Function()> {
  $$CachedMatchesTableTableManager(_$AppDatabase db, $CachedMatchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> memberId = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<int?> age = const Value.absent(),
            Value<String> district = const Value.absent(),
            Value<String?> maritalStatusLabel = const Value.absent(),
            Value<bool> photoVerified = const Value.absent(),
            Value<String?> photoUrl = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMatchesCompanion(
            id: id,
            memberId: memberId,
            displayName: displayName,
            age: age,
            district: district,
            maritalStatusLabel: maritalStatusLabel,
            photoVerified: photoVerified,
            photoUrl: photoUrl,
            createdAt: createdAt,
            position: position,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String memberId,
            required String displayName,
            Value<int?> age = const Value.absent(),
            Value<String> district = const Value.absent(),
            Value<String?> maritalStatusLabel = const Value.absent(),
            Value<bool> photoVerified = const Value.absent(),
            Value<String?> photoUrl = const Value.absent(),
            required DateTime createdAt,
            required int position,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMatchesCompanion.insert(
            id: id,
            memberId: memberId,
            displayName: displayName,
            age: age,
            district: district,
            maritalStatusLabel: maritalStatusLabel,
            photoVerified: photoVerified,
            photoUrl: photoUrl,
            createdAt: createdAt,
            position: position,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedMatchesTable, CachedMatche>(table),
                    BaseReferences<_$AppDatabase, $CachedMatchesTable,
                        CachedMatche>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedMatchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedMatchesTable,
    CachedMatche,
    $$CachedMatchesTableFilterComposer,
    $$CachedMatchesTableOrderingComposer,
    $$CachedMatchesTableAnnotationComposer,
    $$CachedMatchesTableCreateCompanionBuilder,
    $$CachedMatchesTableUpdateCompanionBuilder,
    (
      CachedMatche,
      BaseReferences<_$AppDatabase, $CachedMatchesTable, CachedMatche>
    ),
    CachedMatche,
    PrefetchHooks Function()>;
typedef $$CachedMessagesTableCreateCompanionBuilder = CachedMessagesCompanion
    Function({
  required String id,
  required String matchId,
  Value<String?> clientMsgId,
  required String sender,
  required String kind,
  Value<String?> body,
  Value<String?> mediaJson,
  required DateTime createdAt,
  Value<DateTime?> deliveredAt,
  Value<DateTime?> readAt,
  Value<bool> safetyTip,
  Value<bool> deleted,
  Value<int> rowid,
});
typedef $$CachedMessagesTableUpdateCompanionBuilder = CachedMessagesCompanion
    Function({
  Value<String> id,
  Value<String> matchId,
  Value<String?> clientMsgId,
  Value<String> sender,
  Value<String> kind,
  Value<String?> body,
  Value<String?> mediaJson,
  Value<DateTime> createdAt,
  Value<DateTime?> deliveredAt,
  Value<DateTime?> readAt,
  Value<bool> safetyTip,
  Value<bool> deleted,
  Value<int> rowid,
});

class $$CachedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sender => $composableBuilder(
      column: $table.sender, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaJson => $composableBuilder(
      column: $table.mediaJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get safetyTip => $composableBuilder(
      column: $table.safetyTip, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));
}

class $$CachedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sender => $composableBuilder(
      column: $table.sender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaJson => $composableBuilder(
      column: $table.mediaJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get safetyTip => $composableBuilder(
      column: $table.safetyTip, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));
}

class $$CachedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get clientMsgId => $composableBuilder(
      column: $table.clientMsgId, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get mediaJson =>
      $composableBuilder(column: $table.mediaJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<bool> get safetyTip =>
      $composableBuilder(column: $table.safetyTip, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$CachedMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedMessagesTable,
    CachedMessage,
    $$CachedMessagesTableFilterComposer,
    $$CachedMessagesTableOrderingComposer,
    $$CachedMessagesTableAnnotationComposer,
    $$CachedMessagesTableCreateCompanionBuilder,
    $$CachedMessagesTableUpdateCompanionBuilder,
    (
      CachedMessage,
      BaseReferences<_$AppDatabase, $CachedMessagesTable, CachedMessage>
    ),
    CachedMessage,
    PrefetchHooks Function()> {
  $$CachedMessagesTableTableManager(
      _$AppDatabase db, $CachedMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> matchId = const Value.absent(),
            Value<String?> clientMsgId = const Value.absent(),
            Value<String> sender = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> body = const Value.absent(),
            Value<String?> mediaJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<DateTime?> readAt = const Value.absent(),
            Value<bool> safetyTip = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion(
            id: id,
            matchId: matchId,
            clientMsgId: clientMsgId,
            sender: sender,
            kind: kind,
            body: body,
            mediaJson: mediaJson,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
            readAt: readAt,
            safetyTip: safetyTip,
            deleted: deleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String matchId,
            Value<String?> clientMsgId = const Value.absent(),
            required String sender,
            required String kind,
            Value<String?> body = const Value.absent(),
            Value<String?> mediaJson = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<DateTime?> readAt = const Value.absent(),
            Value<bool> safetyTip = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion.insert(
            id: id,
            matchId: matchId,
            clientMsgId: clientMsgId,
            sender: sender,
            kind: kind,
            body: body,
            mediaJson: mediaJson,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
            readAt: readAt,
            safetyTip: safetyTip,
            deleted: deleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedMessagesTable, CachedMessage>(table),
                    BaseReferences<_$AppDatabase, $CachedMessagesTable,
                        CachedMessage>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedMessagesTable,
    CachedMessage,
    $$CachedMessagesTableFilterComposer,
    $$CachedMessagesTableOrderingComposer,
    $$CachedMessagesTableAnnotationComposer,
    $$CachedMessagesTableCreateCompanionBuilder,
    $$CachedMessagesTableUpdateCompanionBuilder,
    (
      CachedMessage,
      BaseReferences<_$AppDatabase, $CachedMessagesTable, CachedMessage>
    ),
    CachedMessage,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OutboxMessagesTableTableManager get outboxMessages =>
      $$OutboxMessagesTableTableManager(_db, _db.outboxMessages);
  $$CachedMatchesTableTableManager get cachedMatches =>
      $$CachedMatchesTableTableManager(_db, _db.cachedMatches);
  $$CachedMessagesTableTableManager get cachedMessages =>
      $$CachedMessagesTableTableManager(_db, _db.cachedMessages);
}
