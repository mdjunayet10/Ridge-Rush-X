import 'package:flutter_test/flutter_test.dart';
import 'package:hill_rider/main.dart';
import 'package:hill_rider/services/save_service.dart';
import 'package:hill_rider/services/sfx_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the Hill Rider main menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final saveService = SaveService();
    await saveService.init();
    final sfxService = SfxService(saveService: saveService);

    await tester.pumpWidget(
      HillRiderApp(saveService: saveService, sfxService: sfxService),
    );

    expect(find.text('Hill Rider'), findsWidgets);
    expect(find.text('Start Rolling Canyon'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
