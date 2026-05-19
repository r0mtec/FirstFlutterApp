import 'package:flutter_test/flutter_test.dart';
import 'package:lab/main.dart';
import 'package:lab/models/cashdesk_models.dart';

void main() {
  testWidgets('shows cashier login screen', (tester) async {
    await tester.pumpWidget(
      const CashDeskApp(
        initialSettings: AppSettings(serverUrl: AppSettings.defaultServerUrl),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вход кассира'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
