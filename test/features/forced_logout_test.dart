import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/feed/presentation/seen_posts_provider.dart';
import 'package:gramx/features/search/data/recent_searches.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

import '../support/td_fixtures.dart';

class _RecordingExecutor extends QueryExecutor implements TransactionExecutor {
  final List<String> deletedStatements = [];

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<void> close() async {}

  @override
  TransactionExecutor beginTransaction() => this;

  @override
  TransactionExecutor beginExclusive() => this;

  @override
  Future<void> send() async {}

  @override
  Future<void> rollback() async {}

  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    deletedStatements.add(statement);
    return 1;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 1;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async => const [];

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 1;
}

class _FakeTdlib implements TdlibService {
  final _auth = StreamController<td.AuthorizationState>.broadcast();
  final _status = StreamController<String>.broadcast();
  final _updates = StreamController<td.TdObject>.broadcast();

  int restartCalls = 0;
  int logOutRequests = 0;

  @override
  Stream<td.AuthorizationState> get authStateStream => _auth.stream;

  @override
  Stream<String> get statusMessageStream => _status.stream;

  @override
  Stream<td.TdObject> get updatesStream => _updates.stream;

  @override
  td.AuthorizationState? get currentAuthState => null;

  @override
  String get lastStatusMessage => 'Connecting to Telegram...';

  void emitAuth(td.AuthorizationState state) => _auth.add(state);

  @override
  Future<void> restartClient() async {
    restartCalls++;
  }

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (function is td.GetMe) {
      return TdFixtures.user(id: 42, firstName: 'Mubarek');
    }
    if (function is td.LogOut) {
      logOutRequests++;
      return const td.Ok();
    }
    if (function is td.LoadChats) {
      throw const TdlibRequestException(404, 'Not Found');
    }
    return const td.Ok();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _FakeSync implements SyncService {
  bool authReadyMarked = false;
  bool listening = false;
  int stopListeningCalls = 0;

  @override
  void markAuthReady() {
    authReadyMarked = true;
  }

  @override
  void startListening() {
    listening = true;
  }

  @override
  void stopListening() {
    listening = false;
    stopListeningCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _FakeSeenPostsNotifier extends SeenPostsNotifier {
  int clearCalls = 0;

  @override
  void build() {}

  @override
  Future<void> clear() async {
    clearCalls++;
  }
}

class _FakeRecentQueryStore implements RecentQueryStore {
  int saveEmptyCalls = 0;

  @override
  Future<List<String>> load() async => const ['gramflow'];

  @override
  Future<void> save(List<String> queries) async {
    if (queries.isEmpty) saveEmptyCalls++;
  }
}

void main() {
  late _RecordingExecutor executor;
  late AppDatabase db;
  late _FakeTdlib tdlib;
  late _FakeSync sync;
  late _FakeSeenPostsNotifier seenPosts;
  late _FakeRecentQueryStore queryStore;
  late ChatCache chatCache;
  late ProviderContainer container;

  setUp(() {
    executor = _RecordingExecutor();
    db = AppDatabase(executor);
    tdlib = _FakeTdlib();
    sync = _FakeSync();
    seenPosts = _FakeSeenPostsNotifier();
    queryStore = _FakeRecentQueryStore();
    chatCache = ChatCache(tdlib);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tdlibServiceProvider.overrideWithValue(tdlib),
        syncServiceProvider.overrideWithValue(sync),
        chatCacheProvider.overrideWithValue(chatCache),
        seenPostsProvider.overrideWith(() => seenPosts),
        recentQueryStoreProvider.overrideWithValue(queryStore),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  Future<void> signIn() async {
    container.read(authControllerProvider);
    tdlib.emitAuth(const td.AuthorizationStateReady());
    await pumpEventQueue();
    expect(container.read(authControllerProvider).step, AuthStep.authenticated);
    expect(sync.listening, isTrue);
  }

  group('Forced logout from Telegram', () {
    test(
      'LoggingOut followed by Closed cleans up local state, restarts client, and shows session-ended notice',
      () async {
        await signIn();

        // Telegram revokes the session remotely: LoggingOut -> Closed.
        tdlib.emitAuth(const td.AuthorizationStateLoggingOut());
        await pumpEventQueue();

        tdlib.emitAuth(const td.AuthorizationStateClosed());
        await pumpEventQueue();

        final authState = container.read(authControllerProvider);
        expect(authState.step, AuthStep.loginMethodSelection);
        expect(authState.errorMessage, AppStrings.authSessionEnded);
        expect(tdlib.restartCalls, 1);
        expect(sync.listening, isFalse);
        expect(sync.stopListeningCalls, greaterThanOrEqualTo(1));
        expect(seenPosts.clearCalls, 1);
        expect(queryStore.saveEmptyCalls, 1);
        expect(
          executor.deletedStatements.any((s) => s.contains('bookmark_entries')),
          isTrue,
        );
        expect(
          executor.deletedStatements.any((s) => s.contains('accounts')),
          isTrue,
        );

        // When TDLib finishes restarting and announces WaitPhoneNumber, the
        // session-ended message remains visible on the sign-in screen.
        tdlib.emitAuth(const td.AuthorizationStateWaitPhoneNumber());
        await pumpEventQueue();

        final afterReconnect = container.read(authControllerProvider);
        expect(afterReconnect.step, AuthStep.loginMethodSelection);
        expect(afterReconnect.errorMessage, AppStrings.authSessionEnded);
      },
    );

    test(
      'Closed arriving directly while authenticated also cleans up and shows session-ended notice',
      () async {
        await signIn();

        tdlib.emitAuth(const td.AuthorizationStateClosed());
        await pumpEventQueue();

        final authState = container.read(authControllerProvider);
        expect(authState.step, AuthStep.loginMethodSelection);
        expect(authState.errorMessage, AppStrings.authSessionEnded);
        expect(tdlib.restartCalls, 1);
        expect(sync.listening, isFalse);
        expect(seenPosts.clearCalls, 1);
      },
    );

    test(
      'normal user-initiated logout cleans up, restarts client, and shows no forced-logout warning',
      () async {
        await signIn();

        await container.read(authControllerProvider.notifier).logout();
        expect(tdlib.logOutRequests, 1);

        tdlib.emitAuth(const td.AuthorizationStateLoggingOut());
        tdlib.emitAuth(const td.AuthorizationStateClosed());
        await pumpEventQueue();

        final authState = container.read(authControllerProvider);
        expect(authState.step, AuthStep.loginMethodSelection);
        expect(authState.errorMessage, isNull);
        expect(tdlib.restartCalls, 1);
        expect(sync.listening, isFalse);
        expect(seenPosts.clearCalls, 1);
      },
    );
  });
}
