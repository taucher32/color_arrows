import 'package:color_arrows/services/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts at level 1 and only moves forward', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.load();
    expect(store.currentLevel, 1);
    await store.unlock(3);
    await store.unlock(2);
    expect(store.currentLevel, 3);
    expect((await ProgressStore.load()).currentLevel, 3);
  });
}
