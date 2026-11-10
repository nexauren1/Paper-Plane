import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paper_plane/screens/support_screen.dart';
import 'package:paper_plane/widgets/report_dialog.dart';

void main() {
  testWidgets('support screen exposes problem categories and ticket history', (tester) async {
    await tester.pumpWidget(const MaterialApp(locale: Locale('pt'), supportedLocales: [Locale('pt')], home: SupportScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ajuda e suporte'), findsOneWidget);
    expect(find.text('Novo pedido'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Os teus pedidos'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Os teus pedidos'), findsOneWidget);
    expect(find.text('Enviar pedido'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Segurança'), findsOneWidget);
    expect(find.text('Envio e entrega de aviões'), findsOneWidget);
  });

  testWidgets('airplane report dialog presents distinct safety categories', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pt'),
      supportedLocales: const [Locale('pt')],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showReportDialog(context, 'test-plane-id'),
              child: const Text('Report'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(find.text('Denunciar avião'), findsOneWidget);
    expect(find.text('Assédio ou perseguição'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('Falsificação de identidade'), findsOneWidget);
  });
}
