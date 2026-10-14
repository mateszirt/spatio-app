import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';

final pendingSyncItemsProvider = StreamProvider<List<SyncQueueTableData>>((ref) {
  return ref.watch(syncServiceProvider).watchPendingSyncItems();
});

/// Bottom sheet listing exactly which changes are still waiting for synchronization.
class PendingSyncSheet extends ConsumerStatefulWidget {
  const PendingSyncSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PendingSyncSheet(),
    );
  }

  @override
  ConsumerState<PendingSyncSheet> createState() => _PendingSyncSheetState();
}

class _PendingSyncSheetState extends ConsumerState<PendingSyncSheet> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncServiceProvider).syncAll();
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _label(SyncQueueTableData item) {
    try {
      final map = jsonDecode(item.payload) as Map<String, dynamic>;
      final name = map['name'] ?? map['title'];
      if (name != null) return name.toString();
    } catch (_) {}
    return item.recordId;
  }

  IconData _icon(String table) {
    switch (table) {
      case 'Room':
        return Icons.meeting_room_outlined;
      case 'Furniture_Item':
        return Icons.chair_outlined;
      default:
        return Icons.task_alt_rounded;
    }
  }

  String _opLabel(String op) {
    switch (op) {
      case 'DELETE':
        return 'Delete';
      case 'UPDATE':
        return 'Update';
      default:
        return 'Create';
    }
  }

  String _tableLabel(String table) => table == 'Furniture_Item' ? 'Furniture' : table;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(pendingSyncItemsProvider).value ?? const <SyncQueueTableData>[];
    final errors = ref.read(syncServiceProvider).lastSyncErrors;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.sync_problem, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Waiting to sync (${items.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSyncing ? null : _syncNow,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: const Text('Sync now'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Everything is synchronized ✅'))
                  : ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final error = errors[item.id];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber.shade50,
                            child: Icon(_icon(item.targetTable), color: Colors.amber.shade900, size: 20),
                          ),
                          title: Text(
                            _label(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_opLabel(item.operation)} ${_tableLabel(item.targetTable)} • '
                            '${TimeOfDay.fromDateTime(item.createdAt).format(context)}'
                            '${error != null ? '\nLast attempt failed: $error' : ''}',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: error != null ? Colors.red.shade700 : Colors.grey.shade700,
                            ),
                          ),
                          isThreeLine: error != null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
