import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pokemon/main.dart';

void main() {
  testWidgets('Pokémon Tap smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PokemonTapApp());

    // 验证初始界面中有“Choose Your Starter”标题
    expect(find.text('Choose Your Starter'), findsOneWidget);

    // 你可以继续添加更多 widget 测试，比如点击某个精灵后是否能进入游戏界面：
    // await tester.tap(find.text('Bulbasaur'));
    // await tester.pumpAndSettle();
    // expect(find.text('Score: 0'), findsOneWidget);
  });
}
