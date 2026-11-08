import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_pers/core/demo_store.dart';
import 'package:vibe_pers/core/demo_emergency.dart';
import 'package:vibe_pers/core/community_geometry.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibe_pers/core/models.dart';
import 'package:vibe_pers/main.dart';
import 'package:vibe_pers/screens/emergency_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el visto bueno ficticio persiste tras recargar', () async {
    final store = await DemoStore.load();
    const c = Community(
      id: 'junta-demo-voto',
      name: 'Junta prueba',
      area: 'Zona',
      lat: -11.98,
      lng: -76.77,
    );
    const border = [
      LatLng(-11.99, -76.78),
      LatLng(-11.99, -76.76),
      LatLng(-11.97, -76.76),
      LatLng(-11.97, -76.78),
    ];
    store.bindProfile('usuario-voto', 'Yo', c, border);
    final service = store.localListings.firstWhere(
          (l) => l.id == 'demo-reparacion',
    );
    expect(await store.toggleVoteFor(service), isTrue);
    final reloaded = await DemoStore.load();
    expect(reloaded.restoreCachedProfile('usuario-voto'), isTrue);
    expect(
      reloaded.localListings
          .firstWhere((l) => l.id == 'demo-reparacion')
          .voters
          .contains('usuario-voto'),
      isTrue,
    );
  });

  test('el filtro espacial excluye negocios fuera de la junta', () {
    const boundary = [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)];
    expect(pointInBoundary(boundary, 0.5, 0.5), isTrue);
    expect(pointInBoundary(boundary, 0.5, 1.5), isFalse);
  });

  test('la comunidad guardada prevalece al reconectar', () async {
    final store = await DemoStore.load();
    const c = Community(
      id: 'junta-real',
      name: 'Mi junta',
      area: 'Mi zona',
      lat: -11.98,
      lng: -76.77,
    );
    store.bindProfile('usuario-prueba', 'Yo', c, const [
      LatLng(-11.99, -76.78),
      LatLng(-11.99, -76.76),
      LatLng(-11.97, -76.76),
      LatLng(-11.97, -76.78),
    ]);
    final reloaded = await DemoStore.load();
    expect(reloaded.restoreCachedProfile('usuario-prueba'), isTrue);
    expect(reloaded.community.id, 'junta-real');
    expect(reloaded.currentUser.isLeader, isTrue);
    expect(reloaded.localListings.length, greaterThanOrEqualTo(2));
  });

  test('el PDF del distrito elegido aparece primero', () {
    final chosica = demoAreas.firstWhere(
          (area) => area.name == 'Lurigancho-Chosica',
    );
    expect(orderedDemoAreas(chosica).first.name, 'Lurigancho-Chosica');
    expect(
      orderedDemoAreas(chosica).map((area) => area.pdfAsset).toSet().length,
      3,
    );
  });

  test('la información de Chaclacayo se elige cerca de Chaclacayo', () {
    expect(closestDemoArea(const LatLng(-11.978, -76.767)).name, 'Chaclacayo');
  });

  test(
    'un vecino no puede votar dos veces ni recomendarse a sí mismo',
        () async {
      final store = await DemoStore.load();
      final service = store.listings.firstWhere((l) => l.id == 's1');
      final initial = service.voters.length;
      store.switchUser('pedro');
      expect(store.toggleVote(service), isTrue);
      expect(service.voters.length, initial + 1);
      expect(store.toggleVote(service), isTrue);
      expect(service.voters.length, initial);
      store.switchUser('luis');
      expect(store.toggleVote(service), isFalse);
      expect(service.voters.length, initial);
    },
  );

  test('solo el autor acepta una respuesta solidaria', () async {
    final store = await DemoStore.load();
    final post = store.helpPosts.firstWhere((p) => p.id == 'h1');
    store.switchUser('maria');
    expect(store.respond(post, 'Puedo prestar una silla de ruedas.'), isTrue);
    final response = post.responses.single;
    expect(store.accept(post, response.id), isFalse);
    store.switchUser('ana');
    expect(store.accept(post, response.id), isTrue);
    expect(post.status, 'EN_COORDINACION');
    expect(store.closeHelp(post, 'RESUELTA'), isTrue);
  });

  test('la publicación local persiste y se filtra por comunidad', () async {
    final store = await DemoStore.load();
    store.addHelp(
      HelpPost(
        id: 'nuevo',
        authorId: 'ana',
        communityId: 'palmeras',
        direction: 'Necesito',
        mode: 'Préstamo',
        title: 'Herramienta',
        description: 'Necesito una herramienta prestada.',
        createdAt: DateTime.now(),
      ),
    );
    final reloaded = await DemoStore.load();
    expect(reloaded.localHelp.any((p) => p.id == 'nuevo'), isTrue);
    reloaded.switchUser('carmen');
    expect(reloaded.localHelp.any((p) => p.id == 'nuevo'), isFalse);
  });

  testWidgets('tutorial abre las cuatro secciones', (tester) async {
    final store = await DemoStore.load();
    await tester.pumpWidget(VibePersApp(store: store));
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();

    // Al cerrar la intro, saltará el nuevo diálogo del tutorial de la comunidad. Lo omitimos también.
    if (find.text('Omitir').evaluate().isNotEmpty) {
      await tester.tap(find.text('Omitir').last);
      await tester.pumpAndSettle();
    }

    expect(find.text('Mi comunidad'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.storefront_outlined).last);
    await tester.pumpAndSettle();

    // Al entrar a Mercado saltará su respectivo tutorial. Lo omitimos.
    if (find.text('Omitir').evaluate().isNotEmpty) {
      await tester.tap(find.text('Omitir').last);
      await tester.pumpAndSettle();
    }

    expect(find.text('Mercado y solidaridad'), findsOneWidget);
  });

  testWidgets('SOS necesita dos dedos durante dos segundos', (tester) async {
    final store = await DemoStore.load();
    await tester.pumpWidget(
      MaterialApp(
        // SOLUCIÓN: Agregamos isActive: true para que el constructor coincida
        home: Scaffold(body: EmergencyScreen(store: store, isActive: true)),
      ),
    );

    // Omitimos el cuadro de diálogo del tutorial que aparece al cargar la pantalla
    await tester.pumpAndSettle();
    if (find.text('Omitir').evaluate().isNotEmpty) {
      await tester.tap(find.text('Omitir').last);
      await tester.pumpAndSettle();
    }

    await Scrollable.ensureVisible(
      tester.element(find.byIcon(Icons.sos)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byIcon(Icons.sos));
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center + const Offset(-12, 0));
    await tester.pump();
    await second.down(center + const Offset(12, 0));
    await tester.pump();
    expect(find.text('Mantén 2 segundos'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('SIMULACIÓN SOS ACTIVA'), findsNothing);
    await first.up();
    await second.up();
    await tester.pump();
    final third = await tester.createGesture(pointer: 3);
    final fourth = await tester.createGesture(pointer: 4);
    await third.down(center + const Offset(-12, 0));
    await tester.pump();
    await fourth.down(center + const Offset(12, 0));
    await tester.pump();
    expect(find.text('Mantén 2 segundos'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SIMULACIÓN SOS ACTIVA'), findsOneWidget);
    await third.up();
    await fourth.up();
  });
}