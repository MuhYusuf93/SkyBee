import '../../../core/domain/value_types.dart';

/// Input owns no identity: an edit always supplies a separate stable member ID.
final class MemberInput {
  const MemberInput({
    required this.name,
    required this.phone,
    this.address = '',
  });
  final String name, phone, address;
}

final class MemberProfile {
  const MemberProfile(
    this.id,
    this.name,
    this.phone,
    this.address,
    this.revision,
    this.archived,
    this.needsReview,
    this.visits,
  );
  final EntityId id;
  final String name;
  final String? phone;
  final String address;
  final int revision, visits;
  final bool archived, needsReview;
}

/// Cursor binds the aggregate ordering and invalidates after a local mutation.
final class MemberCursor {
  const MemberCursor(
    this.visits,
    this.name,
    this.id,
    this.query,
    this.archived,
    this.generation,
    this.databaseRevision,
  );
  final int visits, generation, databaseRevision;
  final String name, query;
  final EntityId id;
  final bool archived;
}

final class ResolvedMember {
  const ResolvedMember(this.id, this.name, this.phone);
  final EntityId id;
  final String name;
  final String? phone;
}
