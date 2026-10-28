import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../l10n/localization.dart';
import '../../inventory/application/inventory_service.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/supplier_return.dart';
import 'supplier_return_screen.dart';

/// Drafts, posted returns and eligible source receipts have independent bounded
/// cursors. Selecting a receipt only creates a draft, never a stock movement.
class SupplierReturnsScreen extends StatefulWidget {
  const SupplierReturnsScreen({super.key, required this.supplier});
  final EntityId supplier;
  @override
  State<SupplierReturnsScreen> createState() => _SupplierReturnsScreenState();
}

class _SupplierReturnsScreenState extends State<SupplierReturnsScreen> {
  List<Map<String, Object?>> rows = [];
  SupplierReturnCursor? next;
  SupplierReturnReceiptCursor? receiptNext;
  String mode = 'drafts', name = '', error = '';
  bool busy = false, started = false;
  int generation = 0;
  bool get hasMore => mode == 'receipts' ? receiptNext != null : next != null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final app = context.read<AppServices>();
      if (app.database.generation != generation) {
        throw const AppError('m3DraftChanged');
      }
      final supplier = await app.suppliers.terms(widget.supplier);
      if (mode == 'receipts') {
        final page = await app.inventory.supplierReturnReceipts(
          widget.supplier,
          after: more ? receiptNext : null,
        );
        if (mounted) {
          setState(() {
            rows = page.items;
            receiptNext = page.nextCursor;
            name = supplier.name;
          });
        }
      } else {
        final page = await app.inventory.supplierReturns(
          widget.supplier,
          drafts: mode == 'drafts',
          after: more ? next : null,
        );
        if (mounted) {
          setState(() {
            rows = page.items;
            next = page.nextCursor;
            name = supplier.name;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, Object?> row) async {
    if (busy) return;
    EntityId id = EntityId(row['id'] as String);
    if (mode == 'receipts') {
      setState(() => busy = true);
      try {
        final draft = await context
            .read<AppServices>()
            .inventory
            .createSupplierReturnDraft(id);
        id = draft.id;
      } catch (e) {
        if (mounted) setState(() => error = safeError(e));
        return;
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SupplierReturnScreen(id: id)),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53SupplierReturns')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 4,
              child: busy ? const LinearProgressIndicator() : null,
            ),
            SizedBox(
              key: ValueKey(
                busy ? 'supplier-returns-loading' : 'supplier-returns-ready',
              ),
              height: 0,
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('supplier-returns-list'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(name),
                  if (error.isNotEmpty) Text(tr(context, error)),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    isExpanded: true,
                    items: [
                      for (final value in ['drafts', 'posted', 'receipts'])
                        DropdownMenuItem(
                          value: value,
                          child: Text(tr(context, 'm53ReturnList$value')),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            setState(() => mode = value!);
                            load();
                          },
                  ),
                  if (!busy && rows.isEmpty)
                    Text(tr(context, 'm53SupplierEmpty')),
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        key: ValueKey('supplier-return-row-${row['id']}'),
                        title: Text(
                          tr(
                            context,
                            mode == 'receipts'
                                ? 'm53ReturnChooseReceipt'
                                : mode == 'drafts'
                                ? 'm53ReturnStatusdraft'
                                : row['reversed'] == 1
                                ? 'm53ReturnReversed'
                                : 'm53ReturnStatusposted',
                          ),
                        ),
                        subtitle: Text(
                          '${DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int).toLocal()}${mode == 'receipts' ? '' : '\n${row['reason']}'}',
                        ),
                        onTap: busy ? null : () => open(row),
                      ),
                    ),
                  if (hasMore)
                    TextButton(
                      onPressed: busy ? null : () => load(more: true),
                      child: Text(tr(context, 'm53SupplierNext')),
                    ),
                  TextButton(
                    onPressed: busy ? null : load,
                    child: Text(tr(context, 'm53SupplierFirst')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
