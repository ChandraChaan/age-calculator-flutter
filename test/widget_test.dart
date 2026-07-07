import 'package:agecalculator/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows home screen with title and subtitle', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AgeCalculatorApp());
    await tester.pumpAndSettle();

    expect(find.text('Age Calculator'), findsOneWidget);
    expect(find.text('Calculate your exact age instantly.'), findsOneWidget);
    expect(find.text('Date of Birth'), findsOneWidget);
    expect(find.text('Calculate Age As Of'), findsOneWidget);
  });
}
