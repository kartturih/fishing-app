import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/ranked_largest_catch_row.dart';

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late CatchPhotoRepository catchPhotoRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('ranked_largest_catch_row');
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => tempDir),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Catch buildCatch() {
    return Catch(
      id: 'catch-1',
      fishingSpotId: 'spot-1',
      species: FishSpecies.pike,
      caughtAt: DateTime.utc(2026, 7, 17),
      weightGrams: 2500,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
  }

  testWidgets('renders the given rank alongside the wrapped CatchListItem', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RankedLargestCatchRow(
            rank: 1,
            catchModel: buildCatch(),
            catchPhotoRepository: catchPhotoRepository,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Hauki'), findsOneWidget);
  });

  testWidgets('exposes a rank semantic label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RankedLargestCatchRow(
            rank: 2,
            catchModel: buildCatch(),
            catchPhotoRepository: catchPhotoRepository,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('2. sija'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping the row invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RankedLargestCatchRow(
            rank: 3,
            catchModel: buildCatch(),
            catchPhotoRepository: catchPhotoRepository,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hauki'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets(
    'rank 1, 2, and 3 each render with distinct medal colors, and rank 1 '
    "'s badge is visually more prominent",
    (tester) async {
      Container badgeContainer() {
        final matches = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(RankedLargestCatchRow),
                matching: find.byType(Container),
              ),
            )
            .where((container) {
              final decoration = container.decoration;
              return decoration is BoxDecoration &&
                  decoration.shape == BoxShape.circle;
            })
            .toList();
        expect(matches, hasLength(1));
        return matches.single;
      }

      Future<Container> pumpRank(int rank) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RankedLargestCatchRow(
                rank: rank,
                catchModel: buildCatch(),
                catchPhotoRepository: catchPhotoRepository,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return badgeContainer();
      }

      Color colorOf(Container container) =>
          (container.decoration! as BoxDecoration).color!;

      final firstPlace = await pumpRank(1);
      final secondPlace = await pumpRank(2);
      final thirdPlace = await pumpRank(3);

      final backgroundColors = {
        colorOf(firstPlace),
        colorOf(secondPlace),
        colorOf(thirdPlace),
      };
      expect(backgroundColors, hasLength(3));

      expect(
        firstPlace.constraints!.maxWidth,
        greaterThan(secondPlace.constraints!.maxWidth),
      );
      expect(
        secondPlace.constraints!.maxWidth,
        thirdPlace.constraints!.maxWidth,
      );
    },
  );

  testWidgets(
    'rank 1, 2, and 3 each render with distinct card border colors, and '
    "rank 1's card has a thicker border and higher elevation",
    (tester) async {
      Future<Card> pumpRank(int rank) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RankedLargestCatchRow(
                rank: rank,
                catchModel: buildCatch(),
                catchPhotoRepository: catchPhotoRepository,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.widget<Card>(find.byType(Card));
      }

      BorderSide borderOf(Card card) =>
          (card.shape! as RoundedRectangleBorder).side;

      final firstPlace = await pumpRank(1);
      final secondPlace = await pumpRank(2);
      final thirdPlace = await pumpRank(3);

      final borderColors = {
        borderOf(firstPlace).color,
        borderOf(secondPlace).color,
        borderOf(thirdPlace).color,
      };
      expect(borderColors, hasLength(3));

      expect(
        borderOf(firstPlace).width,
        greaterThan(borderOf(secondPlace).width),
      );
      expect(borderOf(secondPlace).width, borderOf(thirdPlace).width);
      expect(firstPlace.elevation, greaterThan(secondPlace.elevation!));
      expect(secondPlace.elevation, thirdPlace.elevation);
    },
  );

  test('rejects a rank outside 1..3', () {
    expect(
      () => RankedLargestCatchRow(
        rank: 4,
        catchModel: buildCatch(),
        catchPhotoRepository: catchPhotoRepository,
        onTap: () {},
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => RankedLargestCatchRow(
        rank: 0,
        catchModel: buildCatch(),
        catchPhotoRepository: catchPhotoRepository,
        onTap: () {},
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
