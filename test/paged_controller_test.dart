import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/pagination/page.dart';
import 'package:kasir_app/core/pagination/paged_controller.dart';

void main() {
  test(
    'reset ignores obsolete responses and blocks concurrent load-more',
    () async {
      final old = Completer<Page<String, int>>();
      final fresh = Completer<Page<String, int>>();
      final calls = <String>[];
      final state = PagedController<String, int, String>(
        filter: 'old',
        load: (filter, after) {
          calls.add(filter);
          return filter == 'old' ? old.future : fresh.future;
        },
      );
      final first = state.loadMore();
      await state.loadMore();
      expect(calls, ['old']);
      final reset = state.reset('new');
      old.complete(Page(items: ['obsolete'], nextCursor: 1));
      await first;
      expect(state.items, isEmpty);
      expect(state.isLoading, true);
      fresh.complete(Page(items: ['current'], nextCursor: null));
      await reset;
      expect(state.items, ['current']);
      expect(state.hasMore, false);
      await state.loadMore();
      expect(calls, ['old', 'new']);
      state.dispose();
    },
  );
  test(
    'obsolete failure cannot change current state; current error can retry',
    () async {
      final old = Completer<Page<int, int>>();
      var fail = true;
      final state = PagedController<int, int, String>(
        filter: 'old',
        load: (filter, after) async {
          if (filter == 'old') return old.future;
          if (fail) throw StateError('test private message');
          return Page(items: [1], nextCursor: null);
        },
      );
      final pending = state.loadMore();
      await state.reset('new');
      expect(state.error, 'listLoadFailed');
      fail = false;
      await state.loadMore();
      old.completeError(StateError('obsolete failure'));
      await pending;
      expect(state.items, [1]);
      expect(state.error, isNull);
      state.dispose();
    },
  );
  test(
    'cache bounded, cursor continues after eviction; local mutation uses reset',
    () async {
      final cursors = <int?>[];
      final state = PagedController<int, int, String>(
        filter: 'a',
        maxCachedPages: 2,
        load: (_, after) async {
          cursors.add(after);
          final next = (after ?? 0) + 1;
          return Page(items: [next], nextCursor: next);
        },
      );
      for (var i = 0; i < 5; i++) {
        await state.loadMore();
      }
      expect(state.items, [4, 5]);
      expect(cursors, [null, 1, 2, 3, 4]);
      expect(() => state.items.add(7), throwsUnsupportedError);
      await state.reset('a');
      expect(state.items, [1]);
      expect(cursors.last, isNull);
      state.dispose();
    },
  );
  test(
    'dispose during in-flight page does not notify or retain results',
    () async {
      final pending = Completer<Page<int, int>>();
      final state = PagedController<int, int, String>(
        filter: '',
        load: (_, _) => pending.future,
      );
      var notifications = 0;
      state.addListener(() => notifications++);
      final request = state.loadMore();
      state.dispose();
      pending.complete(Page(items: [1], nextCursor: null));
      await request;
      expect(notifications, 1);
      expect(state.items, isEmpty);
    },
  );
}
