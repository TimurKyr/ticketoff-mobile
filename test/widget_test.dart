import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketoff_mobile/app.dart';
import 'package:ticketoff_mobile/core/api/auth_service.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';

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
  testWidgets('controller logs in and sees assigned events', (tester) async {
    final auth = _FakeAuthGateway();
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: auth,
        eventsRepository: _FakeEventsRepository([_event()]),
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

    expect(find.text('Мероприятия'), findsWidgets);
    expect(find.text('Концерт'), findsOneWidget);
    expect(find.text('Зал А'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Сканер'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Выберите назначенное событие, чтобы начать сканирование'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Мероприятия'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assigned-event-event-1')));
    await tester.pumpAndSettle();
    expect(find.text('Сканирование билетов'), findsOneWidget);
    expect(find.text('Мероприятие: event-1'), findsOneWidget);
  });

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
    expect(find.byType(NavigationBar), findsOneWidget);
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

  testWidgets('guest selection does not navigate away', (tester) async {
    await tester.pumpWidget(
      TicketoffApp(
        authGateway: _FakeAuthGateway(),
        eventsRepository: _FakeEventsRepository(const []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Гость'));
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать!'), findsOneWidget);
    expect(find.text('Вход контролёра'), findsNothing);
  });
}
