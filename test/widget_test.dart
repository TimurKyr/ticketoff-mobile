import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketoff_mobile/app.dart';
import 'package:ticketoff_mobile/core/api/auth_service.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/features/attendees/attendee.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class _FakeScanRepository implements ScanRepository {
  @override
  Future<CheckinCount> fetchCount(String eventId) async =>
      const CheckinCount(2, 5);

  @override
  Future<ScanResult> scan(String eventId, String token) =>
      throw UnimplementedError();
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.authenticated = false});

  bool authenticated;

  @override
  Future<bool> hasSession() async => authenticated;

  @override
  Future<void> login(String email, String password) async {
    if (email != 'controller@example.com' || password != 'password123') {
      throw const AuthFailure('Неверный email или пароль');
    }
    authenticated = true;
  }

  @override
  Future<void> logout() async {
    authenticated = false;
  }
}

class _FakeEventsRepository implements AssignedEventsRepository {
  _FakeEventsRepository(this.events);

  final List<AssignedEvent> events;

  @override
  Future<List<AssignedEvent>> fetchMyEvents() async => events;
}

class _FakeAttendeesRepository implements AttendeesRepository {
  var status = TicketStatus.checkedIn;
  var statsRequests = 0;
  var undoRequests = 0;
  var checkInRequests = 0;
  var checkInOutcome = ScanOutcome.checkedIn;
  final queries = <String>[];
  final offsets = <int>[];
  var failFirstPage = false;

  @override
  Future<AttendeePage> fetchAttendees(
    String eventId, {
    required String query,
    required int offset,
  }) async {
    expect(eventId, 'event-1');
    queries.add(query);
    offsets.add(offset);
    if (failFirstPage) {
      failFirstPage = false;
      throw const AttendeesFailure('Не удалось связаться с сервером');
    }
    return AttendeePage(
      items: [
        Attendee(
          ticketId: 'ticket-$offset',
          name: offset == 0 ? 'Dana' : 'Erlan',
          email: offset == 0 ? 'dana@example.com' : null,
          ticketType: 'VIP',
          status: offset == 0 ? status : TicketStatus.valid,
        ),
      ],
      nextOffset: offset == 0 && query.isEmpty ? 1 : null,
    );
  }

  @override
  Future<EventStats> fetchStats(String eventId) async {
    expect(eventId, 'event-1');
    statsRequests++;
    return EventStats(
      registered: 4,
      checkedIn: status == TicketStatus.checkedIn ? 1 : 0,
      percent: status == TicketStatus.checkedIn ? 25 : 0,
    );
  }

  @override
  Future<TicketStatus> undoCheckIn(String ticketId) async {
    expect(ticketId, 'ticket-0');
    undoRequests++;
    return status = TicketStatus.valid;
  }

  @override
  Future<ScanResult> checkInTicket(String ticketId) async {
    expect(ticketId, 'ticket-0');
    checkInRequests++;
    if (checkInOutcome == ScanOutcome.checkedIn) {
      status = TicketStatus.checkedIn;
    }
    return ScanResult(
      outcome: checkInOutcome,
      count: CheckinCount(status == TicketStatus.checkedIn ? 1 : 0, 4),
    );
  }
}

AssignedEvent _event({
  String id = 'event-1',
  String title = 'Концерт',
  String? venueName = 'Зал А',
}) {
  return AssignedEvent(
    id: id,
    title: title,
    status: 'published',
    startAt: DateTime.utc(2026, 11, 9, 14),
    venueName: venueName,
  );
}

void main() {
  testWidgets('language follows the controller and survives an app restart', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    final auth = _FakeAuthGateway();
    Widget buildApp() => TicketoffApp(
      authGateway: auth,
      eventsRepository: _FakeEventsRepository([_event()]),
      attendeesRepository: _FakeAttendeesRepository(),
    );

    Future<void> selectLanguage(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('language-selector')),
          matching: find.widgetWithText(TextButton, label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Рус'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Қаз'), findsOneWidget);
    await selectLanguage('Қаз');
    expect(find.text('Қош келдіңіз!'), findsOneWidget);
    expect(find.text('Қонақ'), findsOneWidget);
    await tester.tap(find.text('Әкімші'));
    await tester.pumpAndSettle();
    expect(find.text('Бақылаушының кіруі'), findsOneWidget);
    final submit = find.byKey(const Key('login-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Құпиясөзді енгізіңіз'), findsOneWidget);
    await selectLanguage('Рус');
    expect(find.text('Введите пароль'), findsOneWidget);
    await selectLanguage('Қаз');

    await tester.enterText(
      find.byKey(const Key('controller-email')),
      'controller@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('controller-password')),
      'password123',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Іс-шаралар'), findsWidgets);
    expect(find.text('Іс-шара қонақтары'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-guests-event-1')));
    await tester.pumpAndSettle();
    expect(find.text('VIP · Белгіленген'), findsOneWidget);

    await selectLanguage('Рус');
    expect(find.text('Имя или email'), findsOneWidget);
    expect(find.text('VIP · Отмечен'), findsOneWidget);
    await selectLanguage('Қаз');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Соңғы іс-шара'), findsOneWidget);
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('Қош келдіңіз!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('Қош келдіңіз!'), findsOneWidget);
  });

  testWidgets('guests retry, search, undo, check in and refresh on return', (
    tester,
  ) async {
    final repository = _FakeAttendeesRepository()..failFirstPage = true;
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: _FakeAuthGateway(authenticated: true),
        eventsRepository: _FakeEventsRepository([_event()]),
        attendeesRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-guests-event-1')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось связаться с сервером'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(repository.offsets, [0, 0, 1]);
    expect(find.text('Erlan'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('attendees-search')),
      'dana@example.com',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.queries.last, 'dana@example.com');
    expect(find.text('Erlan'), findsNothing);
    expect(find.text('Dana'), findsOneWidget);
    await tester.tap(find.text('Отменить отметку'));
    await tester.pumpAndSettle();
    expect(repository.undoRequests, 0);
    expect(find.text('Отменить отметку?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Отменить отметку'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.undoRequests, 1);
    expect(find.text('VIP · Действителен'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    await tester.tap(find.text('Отметить вход'));
    await tester.pumpAndSettle();
    expect(repository.checkInRequests, 0);
    expect(find.text('Отметить вход?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Отметить вход'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.checkInRequests, 1);
    expect(find.text('Вход разрешён'), findsOneWidget);
    expect(find.text('VIP · Отмечен'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    final statsRequests = repository.statsRequests;
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Гости последнего мероприятия'));
    await tester.pumpAndSettle();
    expect(repository.statsRequests, statsRequests + 1);
    expect(repository.queries.last, isEmpty);
  });

  testWidgets('manual check-in displays a rejection from the server', (
    tester,
  ) async {
    final repository = _FakeAttendeesRepository()
      ..status = TicketStatus.valid
      ..checkInOutcome = ScanOutcome.eventCancelled;
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: _FakeAuthGateway(authenticated: true),
        eventsRepository: _FakeEventsRepository([_event()]),
        attendeesRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-guests-event-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отметить вход').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Отметить вход'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.checkInRequests, 1);
    expect(find.text('Событие отменено'), findsOneWidget);
    expect(find.text('VIP · Отмечен'), findsNothing);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets(
    'returning from scanner or guests pins the last event above the list',
    (tester) async {
      final auth = _FakeAuthGateway();
      await tester.pumpWidget(
        TicketoffApp(
          authGateway: auth,
          eventsRepository: _FakeEventsRepository([
            _event(),
            _event(id: 'event-2', title: 'Выставка'),
            for (var i = 3; i <= 10; i++)
              _event(id: 'event-$i', title: 'Событие $i'),
          ]),
          scanRepository: _FakeScanRepository(),
          attendeesRepository: _FakeAttendeesRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Добро пожаловать!'), findsOneWidget);
      await tester.tap(find.text('Администратор'));
      await tester.pumpAndSettle();

      expect(find.text('Вход контролёра'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('controller-email')),
        'controller@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('controller-password')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Мероприятия'), findsOneWidget);
      expect(find.text('Концерт'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final pinned = find.byKey(const Key('pinned-event'));
      expect(pinned, findsNothing);

      await tester.tap(find.byKey(const Key('assigned-event-event-2')));
      await tester.pumpAndSettle();
      expect(find.text('Сканирование билетов'), findsOneWidget);
      expect(find.text('Отмечено 2 из 5'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Мероприятия'), findsOneWidget);
      Finder pinnedTitle(String title) =>
          find.descendant(of: pinned, matching: find.text(title));
      expect(pinnedTitle('Выставка'), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-guests-event-1')));
      await tester.pumpAndSettle();
      expect(find.text('Dana'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Мероприятия'), findsOneWidget);
      expect(pinnedTitle('Концерт'), findsOneWidget);
      expect(pinnedTitle('Выставка'), findsNothing);
      expect(find.byKey(const Key('assigned-event-event-1')), findsOneWidget);

      final list = find.byKey(const Key('assigned-events-list'));
      final pinnedPosition = tester.getTopLeft(pinned);
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );
      expect(tester.getTopLeft(pinned), pinnedPosition);

      await tester.tap(find.byTooltip('Сканер последнего мероприятия'));
      await tester.pumpAndSettle();
      expect(find.text('Сканирование билетов'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(pinnedTitle('Концерт'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('restores saved controller session on startup', (tester) async {
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: _FakeAuthGateway(authenticated: true),
        eventsRepository: _FakeEventsRepository([_event()]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Концерт'), findsOneWidget);
    expect(find.text('Добро пожаловать!'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows an empty state when controller has no assigned events', (
    tester,
  ) async {
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: _FakeAuthGateway(authenticated: true),
        eventsRepository: _FakeEventsRepository(const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Вас пока не назначили ни на одно событие'),
      findsOneWidget,
    );
  });

  testWidgets('invalid password shows a clear error', (tester) async {
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: _FakeAuthGateway(),
        eventsRepository: _FakeEventsRepository(const []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('controller-email')),
      'controller@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('controller-password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Неверный email или пароль'), findsOneWidget);
    expect(find.text('Вход контролёра'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('logout clears the session and returns to role selection', (
    tester,
  ) async {
    final auth = _FakeAuthGateway(authenticated: true);
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: auth,
        eventsRepository: _FakeEventsRepository([_event()]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();

    expect(auth.authenticated, isFalse);
    expect(find.text('Добро пожаловать!'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets(
    'guest selection opens Ticketoff and can return to role selection',
    (tester) async {
      await tester.pumpWidget(
        TicketoffApp(
          authGateway: _FakeAuthGateway(),
          eventsRepository: _FakeEventsRepository(const []),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Гость'));
      await tester.pumpAndSettle();

      expect(find.text('Открыть Ticketoff в браузере'), findsOneWidget);
      expect(find.text('Вход контролёра'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Добро пожаловать!'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
}
