import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/member_models.dart';
import 'member_form.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ManagementGate(child: _MembersList());
}

/// Holds one bounded page. Back history retains cursors, never every profile.
class _MembersList extends StatefulWidget {
  const _MembersList();
  @override
  State<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<_MembersList> {
  final search = TextEditingController();
  Timer? debounce;
  int request = 0;
  bool busy = true, archived = false;
  String? error;
  List<MemberProfile> rows = [];
  MemberCursor? after, next;
  final history = <MemberCursor?>[];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool reset = false}) async {
    if (reset) {
      after = null;
      history.clear();
    }
    final version = ++request;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await context.read<AppServices>().members.ownerList(
        query: search.text,
        archived: archived,
        after: after,
      );
      if (mounted && version == request) {
        setState(() {
          rows = page.items;
          next = page.nextCursor;
          busy = false;
        });
      }
    } catch (e) {
      if (!mounted || version != request) return;
      if (e is AppError && e.message == 'm3DraftChanged' && after != null) {
        await load(reset: true);
        return;
      }
      setState(() {
        busy = false;
        error = safeError(e);
      });
    }
  }

  Future<void> edit([MemberProfile? member]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MemberForm(member: member)),
    );
    if (mounted) await load(reset: true);
  }

  Future<void> archive(MemberProfile member) async {
    if (busy) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr(
            context,
            member.archived ? 'm53RestoreMember' : 'm53ArchiveMember',
          ),
        ),
        content: Text(tr(context, 'm53ArchiveMemberHelp')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr(
                context,
                member.archived ? 'm53RestoreMember' : 'm53ArchiveMember',
              ),
            ),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AppServices>().members.archive(
        member.id,
        member.revision,
        !member.archived,
      );
      if (mounted) await load(reset: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = safeError(e);
        });
      }
    }
  }

  @override
  void dispose() {
    request++;
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, 'm53Members')),
      actions: const [LanguageButton()],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: busy ? null : edit,
      tooltip: tr(context, 'm53MemberCreate'),
      child: const Icon(Icons.person_add),
    ),
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ManagedTextField(
                    controller: search,
                    onChanged: (_) {
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 275),
                        () => load(reset: true),
                      );
                    },
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53MemberSearch'),
                      suffixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                CheckboxListTile(
                  value: archived,
                  onChanged: busy
                      ? null
                      : (value) {
                          archived = value!;
                          load(reset: true);
                        },
                  title: Text(tr(context, 'm53ArchivedMembers')),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(tr(context, 'm53MemberVisitHelp')),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null) Text(tr(context, error!)),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: rows.isEmpty ? 1 : rows.length,
            itemBuilder: (context, index) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tr(context, 'm53NoMembers')),
                );
              }
              final member = rows[index];
              return ListTile(
                title: Text(member.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.phone ?? tr(context, 'm3NoPhone')),
                    Text('${tr(context, 'm53MemberVisits')}: ${member.visits}'),
                    if (member.needsReview)
                      Text(tr(context, 'm53MemberRepairRequired')),
                  ],
                ),
                onTap: busy ? null : () => edit(member),
                trailing: IconButton(
                  tooltip: tr(
                    context,
                    member.archived ? 'm53RestoreMember' : 'm53ArchiveMember',
                  ),
                  onPressed: busy ? null : () => archive(member),
                  icon: Icon(
                    member.archived ? Icons.unarchive : Icons.archive_outlined,
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 88),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: tr(context, 'm53SetupBack'),
                    onPressed: busy || history.isEmpty
                        ? null
                        : () {
                            after = history.removeLast();
                            load();
                          },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => load(reset: true),
                    tooltip: tr(context, 'm4ReloadStart'),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: tr(context, 'loadMore'),
                    onPressed: busy || next == null
                        ? null
                        : () {
                            history.add(after);
                            after = next;
                            load();
                          },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
