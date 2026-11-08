// Reduced motion for the Living Landscapes interaction transitions.
//
// Hover, press and selection feedback (printed button settle, check-in step
// bar, bottom/top bar indicators, index-row chevron, icon-well ring) keeps its
// final visual state in both modes. With normal motion it animates; with
// reduced motion (MediaQuery.disableAnimations) it reaches that state at once.
// Each test samples a frame part-way through the transition.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/theme/nature_tokens.dart';
import 'package:mindpulse/presentation/nature/nature_home_sections.dart';
import 'package:mindpulse/presentation/nature/nature_navigation.dart';
import 'package:mindpulse/presentation/nature/nature_widgets.dart';

const _mid = Duration(milliseconds: 40); // shorter than press (110) and selection (180)

Widget _host(Widget child, {required bool reduce}) {
  return MaterialApp(
    theme: NatureTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump(); // deliver the hover; the transition starts on this frame
  return mouse;
}

void main() {
  for (final reduce in [false, true]) {
    final mode = reduce ? 'reduced motion' : 'normal motion';

    group(mode, () {
      testWidgets('printed action: hover settle', (tester) async {
        await tester.pumpWidget(_host(
          SizedBox(width: 320, child: NaturePrintedAction(label: 'Begin', onTap: () {})),
          reduce: reduce,
        ));
        final rest = tester.getTopLeft(find.text('Begin'));
        await _hover(tester, find.text('Begin'));
        await tester.pump(_mid);
        final dx = tester.getTopLeft(find.text('Begin')).dx - rest.dx;
        if (reduce) {
          expect(dx, moreOrLessEquals(1.5));
        } else {
          expect(dx, inExclusiveRange(0.0, 1.5));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(find.text('Begin')).dx - rest.dx, moreOrLessEquals(1.5));
        }
      });

      testWidgets('check-in step bar fills', (tester) async {
        Widget header(int step) => _host(SizedBox(width: 360, child: NatureStepHeader(step: step)), reduce: reduce);
        await tester.pumpWidget(header(1));
        await tester.pumpWidget(header(2));
        await tester.pump(_mid);
        final box = tester.renderObject<RenderDecoratedBox>(find.descendant(
            of: find.byType(AnimatedContainer).at(1), matching: find.byType(DecoratedBox)));
        final color = (box.decoration as BoxDecoration).color;
        if (reduce) {
          expect(color, NatureColors.forest);
        } else {
          expect(color, isNot(NatureColors.forest));
          await tester.pumpAndSettle();
          final settled = tester.renderObject<RenderDecoratedBox>(find.descendant(
              of: find.byType(AnimatedContainer).at(1), matching: find.byType(DecoratedBox)));
          expect((settled.decoration as BoxDecoration).color, NatureColors.forest);
        }
        // The step itself is announced in text, not by the bar.
        expect(find.text('Daily check-in · Step 2 of 2'), findsOneWidget);
      });

      testWidgets('bottom bar: active indicator', (tester) async {
        Widget bar(int i) => _host(
              SizedBox(width: 412, child: NatureBottomBar(currentIndex: i, onTap: (_) {}, onCheckIn: () {})),
              reduce: reduce,
            );
        await tester.pumpWidget(bar(0));
        await tester.pumpWidget(bar(1));
        await tester.pump(_mid);
        final w = tester.getSize(find.byType(AnimatedContainer).at(1)).width;
        if (reduce) {
          expect(w, 22);
        } else {
          expect(w, inExclusiveRange(0.0, 22.0));
          await tester.pumpAndSettle();
          expect(tester.getSize(find.byType(AnimatedContainer).at(1)).width, 22);
        }
        expect(tester.getSemantics(find.bySemanticsLabel('Insights tab')),
            matchesSemantics(label: 'Insights tab', isSelected: true, isButton: true, hasTapAction: true,
                isFocusable: true, hasFocusAction: true, hasSelectedState: true, hasEnabledState: true, isEnabled: true));
      });

      testWidgets('top bar: active indicator', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Widget bar(int i) => _host(
              SizedBox(
                width: 1280,
                child: NatureTopBar(overSky: false, currentIndex: i, onTap: (_) {}, onCheckIn: () {}),
              ),
              reduce: reduce,
            );
        await tester.pumpWidget(bar(0));
        await tester.pumpWidget(bar(1));
        await tester.pump(_mid);
        final w = tester.getSize(find.byType(AnimatedContainer).at(1)).width;
        if (reduce) {
          expect(w, 24);
        } else {
          expect(w, inExclusiveRange(0.0, 24.0));
          await tester.pumpAndSettle();
          expect(tester.getSize(find.byType(AnimatedContainer).at(1)).width, 24);
        }
      });

      testWidgets('icon well: ring settles into register', (tester) async {
        Widget well(bool s) =>
            _host(NaturePrintedIconWell(icon: Icons.book_outlined, settled: s), reduce: reduce);
        await tester.pumpWidget(well(false));
        final ring = find.descendant(of: find.byType(AnimatedPositioned), matching: find.byType(Container));
        final origin = tester.getTopLeft(find.byType(NaturePrintedIconWell));
        double left() => tester.getTopLeft(ring).dx - origin.dx;
        expect(left(), 4);
        await tester.pumpWidget(well(true));
        await tester.pump(_mid);
        if (reduce) {
          expect(left(), 2);
        } else {
          expect(left(), inExclusiveRange(2.0, 4.0));
          await tester.pumpAndSettle();
          expect(left(), 2);
        }
      });

      testWidgets('ways to reflect: chevron moves on hover', (tester) async {
        await tester.pumpWidget(_host(
          SizedBox(
            width: 412,
            child: NatureWaysToReflect(
              modalities: [NatureModality(Icons.book_outlined, 'Journal', 'Write a note', () => const SizedBox())],
              open: (_) {},
            ),
          ),
          reduce: reduce,
        ));
        final chevron = find.byIcon(Icons.chevron_right_rounded);
        final rest = tester.getTopLeft(chevron).dx;
        await _hover(tester, find.text('Journal'));
        await tester.pump(_mid);
        final dx = tester.getTopLeft(chevron).dx - rest;
        final full = 0.18 * tester.getSize(chevron).width;
        if (reduce) {
          expect(dx, moreOrLessEquals(full));
        } else {
          expect(dx, inExclusiveRange(0.0, full));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(chevron).dx - rest, moreOrLessEquals(full));
        }
      });
    });
  }
}
