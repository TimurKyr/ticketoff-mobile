import 'package:flutter_test/flutter_test.dart';
import 'package:ticketoff_mobile/app.dart';
import 'package:ticketoff_mobile/core/api/health_service.dart';

class _AvailableHealthStatus implements HealthStatusSource {
  const _AvailableHealthStatus();

  @override
  Future<bool> check() async => true;
}

void main() {
  testWidgets('events screen displays backend health status', (tester) async {
    await tester.pumpWidget(
      const TicketoffApp(healthStatusSource: _AvailableHealthStatus()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
  });
}
