// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clipboard_utils.dart';

void main() {
  late int tapCount;
  late int singleTapUpCount;
  late int singleTapCancelCount;
  late int singleLongTapStartCount;
  late int doubleTapDownCount;
  late int forcePressStartCount;
  late int forcePressEndCount;
  late int dragStartCount;
  late int dragUpdateCount;
  late int dragEndCount;
  const Offset forcePressOffset = Offset(400.0, 50.0);

  void _handleTapDown(TapDownDetails details) { tapCount++; }
  void _handleSingleTapUp(TapUpDetails details) { singleTapUpCount++; }
  void _handleSingleTapCancel() { singleTapCancelCount++; }
  void _handleSingleLongTapStart(LongPressStartDetails details) { singleLongTapStartCount++; }
  void _handleDoubleTapDown(TapDownDetails details) { doubleTapDownCount++; }
  void _handleForcePressStart(ForcePressDetails details) { forcePressStartCount++; }
  void _handleForcePressEnd(ForcePressDetails details) { forcePressEndCount++; }
  void _handleDragSelectionStart(DragStartDetails details) { dragStartCount++; }
  void _handleDragSelectionUpdate(DragStartDetails _, DragUpdateDetails details) { dragUpdateCount++; }
  void _handleDragSelectionEnd(DragEndDetails details) { dragEndCount++; }

  setUp(() {
    tapCount = 0;
    singleTapUpCount = 0;
    singleTapCancelCount = 0;
    singleLongTapStartCount = 0;
    doubleTapDownCount = 0;
    forcePressStartCount = 0;
    forcePressEndCount = 0;
    dragStartCount = 0;
    dragUpdateCount = 0;
    dragEndCount = 0;
  });

  Future<void> pumpGestureDetector(WidgetTester tester) async {
    await tester.pumpWidget(
      TextSelectionGestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onSingleTapUp: _handleSingleTapUp,
        onSingleTapCancel: _handleSingleTapCancel,
        onSingleLongTapStart: _handleSingleLongTapStart,
        onDoubleTapDown: _handleDoubleTapDown,
        onForcePressStart: _handleForcePressStart,
        onForcePressEnd: _handleForcePressEnd,
        onDragSelectionStart: _handleDragSelectionStart,
        onDragSelectionUpdate: _handleDragSelectionUpdate,
        onDragSelectionEnd: _handleDragSelectionEnd,
        child: Container(),
      ),
    );
  }

  Future<void> pumpTextSelectionGestureDetectorBuilder(
    WidgetTester tester, {
    bool forcePressEnabled = true,
    bool selectionEnabled = true,
  }) async {
    final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();
    final FakeTextSelectionGestureDetectorBuilderDelegate delegate = FakeTextSelectionGestureDetectorBuilderDelegate(
      editableTextKey: editableTextKey,
      forcePressEnabled: forcePressEnabled,
      selectionEnabled: selectionEnabled,
    );
    final TextSelectionGestureDetectorBuilder provider =
    TextSelectionGestureDetectorBuilder(delegate: delegate);

    await tester.pumpWidget(
      MaterialApp(
        home: provider.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: FakeEditableText(key: editableTextKey),
        ),
      ),
    );
  }

  test('TextSelectionOverlay.fadeDuration exist', () async {
    expect(TextSelectionOverlay.fadeDuration, SelectionOverlay.fadeDuration);
  });

  testWidgets('a series of taps all call onTaps', (WidgetTester tester) async {
    await pumpGestureDetector(tester);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tapAt(const Offset(200, 200));
    expect(tapCount, 6);
  });

  testWidgets('in a series of rapid taps, onTapDown and onDoubleTapDown alternate', (WidgetTester tester) async {
    await pumpGestureDetector(tester);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(singleTapUpCount, 1);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(singleTapUpCount, 1);
    expect(doubleTapDownCount, 1);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(singleTapUpCount, 2);
    expect(doubleTapDownCount, 1);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(singleTapUpCount, 2);
    expect(doubleTapDownCount, 2);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(singleTapUpCount, 3);
    expect(doubleTapDownCount, 2);
    await tester.tapAt(const Offset(200, 200));
    expect(singleTapUpCount, 3);
    expect(doubleTapDownCount, 3);
    expect(tapCount, 6);
  });

  testWidgets('quick tap-tap-hold is a double tap down', (WidgetTester tester) async {
    await pumpGestureDetector(tester);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    expect(singleTapUpCount, 1);
    final TestGesture gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(singleTapUpCount, 1);
    // Every down is counted.
    expect(tapCount, 2);
    // No cancels because the second tap of the double tap is a second successful
    // single tap behind the scene.
    expect(singleTapCancelCount, 0);
    expect(doubleTapDownCount, 1);
    // The double tap down hold supersedes the single tap down.
    expect(singleLongTapStartCount, 0);

    await gesture.up();
    // Nothing else happens on up.
    expect(singleTapUpCount, 1);
    expect(tapCount, 2);
    expect(singleTapCancelCount, 0);
    expect(doubleTapDownCount, 1);
    expect(singleLongTapStartCount, 0);
  });

  testWidgets('a very quick swipe is ignored', (WidgetTester tester) async {
    await pumpGestureDetector(tester);
    final TestGesture gesture = await tester.startGesture(const Offset(200, 200));
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(100, 100));
    await tester.pump();
    expect(singleTapUpCount, 0);
    expect(tapCount, 0);
    expect(singleTapCancelCount, 0);
    expect(doubleTapDownCount, 0);
    expect(singleLongTapStartCount, 0);

    await gesture.up();
    // Nothing else happens on up.
    expect(singleTapUpCount, 0);
    expect(tapCount, 0);
    expect(singleTapCancelCount, 0);
    expect(doubleTapDownCount, 0);
    expect(singleLongTapStartCount, 0);
  });

  testWidgets('a slower swipe has a tap down and a canceled tap', (WidgetTester tester) async {
    await pumpGestureDetector(tester);
    final TestGesture gesture = await tester.startGesture(const Offset(200, 200));
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(100, 100));
    await tester.pump();
    expect(singleTapUpCount, 0);
    expect(tapCount, 1);
    expect(singleTapCancelCount, 1);
    expect(doubleTapDownCount, 0);
    expect(singleLongTapStartCount, 0);
  });

  testWidgets('a force press initiates a force press', (WidgetTester tester) async {
    await pumpGestureDetector(tester);

    final int pointerValue = tester.nextPointer;

    final TestGesture gesture = await tester.createGesture();

    await gesture.downWithCustomEvent(
      forcePressOffset,
      PointerDownEvent(
        pointer: pointerValue,
        position: forcePressOffset,
        pressure: 0.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );

    await gesture.updateWithCustomEvent(PointerMoveEvent(
      pointer: pointerValue,
      pressure: 0.5,
      pressureMin: 0,
    ));
    await gesture.up();
    await tester.pumpAndSettle();

    await gesture.downWithCustomEvent(
      forcePressOffset,
      PointerDownEvent(
        pointer: pointerValue,
        position: forcePressOffset,
        pressure: 0.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    await gesture.updateWithCustomEvent(PointerMoveEvent(
      pointer: pointerValue,
      pressure: 0.5,
      pressureMin: 0,
    ));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));

    await gesture.downWithCustomEvent(
      forcePressOffset,
      PointerDownEvent(
        pointer: pointerValue,
        position: forcePressOffset,
        pressure: 0.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    await gesture.updateWithCustomEvent(PointerMoveEvent(
      pointer: pointerValue,
      pressure: 0.5,
      pressureMin: 0,
    ));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));

    await gesture.downWithCustomEvent(
      forcePressOffset,
      PointerDownEvent(
        pointer: pointerValue,
        position: forcePressOffset,
        pressure: 0.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    await gesture.updateWithCustomEvent(PointerMoveEvent(
      pointer: pointerValue,
      pressure: 0.5,
      pressureMin: 0,
    ));
    await gesture.up();

    expect(forcePressStartCount, 4);
  });

  testWidgets('a tap and then force press initiates a force press and not a double tap', (WidgetTester tester) async {
    await pumpGestureDetector(tester);

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.createGesture();
    await gesture.downWithCustomEvent(
      forcePressOffset,
      PointerDownEvent(
          pointer: pointerValue,
          position: forcePressOffset,
          pressure: 0.0,
          pressureMax: 6.0,
          pressureMin: 0.0,
      ),

    );
    // Initiate a quick tap.
    await gesture.updateWithCustomEvent(
      PointerMoveEvent(
        pointer: pointerValue,
        pressure: 0.0,
        pressureMin: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();

    // Initiate a force tap.
    await gesture.downWithCustomEvent(
      forcePressOffset,
      PointerDownEvent(
        pointer: pointerValue,
        position: forcePressOffset,
        pressure: 0.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    await gesture.updateWithCustomEvent(PointerMoveEvent(
      pointer: pointerValue,
      pressure: 0.5,
      pressureMin: 0,
    ));
    expect(forcePressStartCount, 1);

    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(forcePressEndCount, 1);
    expect(doubleTapDownCount, 0);
  });

  testWidgets('a long press from a touch device is recognized as a long single tap', (WidgetTester tester) async {
    await pumpGestureDetector(tester);

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: pointerValue,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapCount, 1);
    expect(singleTapUpCount, 0);
    expect(singleLongTapStartCount, 1);
  });

  testWidgets('a long press from a mouse is just a tap', (WidgetTester tester) async {
    await pumpGestureDetector(tester);

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: pointerValue,
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapCount, 1);
    expect(singleTapUpCount, 1);
    expect(singleLongTapStartCount, 0);
  });

  testWidgets('a touch drag is not recognized for text selection', (WidgetTester tester) async {
    await pumpGestureDetector(tester);

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: pointerValue,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveBy(const Offset(210.0, 200.0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapCount, 0);
    expect(singleTapUpCount, 0);
    expect(dragStartCount, 0);
    expect(dragUpdateCount, 0);
    expect(dragEndCount, 0);
  });

  testWidgets('a mouse drag is recognized for text selection', (WidgetTester tester) async {
    await pumpGestureDetector(tester);

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: pointerValue,
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveBy(const Offset(210.0, 200.0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapCount, 0);
    expect(singleTapUpCount, 0);
    expect(dragStartCount, 1);
    expect(dragUpdateCount, 1);
    expect(dragEndCount, 1);
  });

  testWidgets('a slow mouse drag is still recognized for text selection', (WidgetTester tester) async {
    await pumpGestureDetector(tester);

    final int pointerValue = tester.nextPointer;
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: pointerValue,
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(seconds: 2));
    await gesture.moveBy(const Offset(210.0, 200.0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dragStartCount, 1);
    expect(dragUpdateCount, 1);
    expect(dragEndCount, 1);
  });

  testWidgets('test TextSelectionGestureDetectorBuilder long press', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester);
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: 0,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.pumpAndSettle();

    final FakeEditableTextState state = tester.state(find.byType(FakeEditableText));
    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    expect(state.showToolbarCalled, isTrue);
    expect(renderEditable.selectPositionAtCalled, isTrue);
  });

  testWidgets('TextSelectionGestureDetectorBuilder right click Apple platforms', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/80119
    await pumpTextSelectionGestureDetectorBuilder(tester);

    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    renderEditable.text = const TextSpan(text: 'one two three four five six seven');
    await tester.pump();

    final TestGesture gesture = await tester.createGesture(
      pointer: 0,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(gesture.removePointer);

    // Get the location of the 10th character
    final Offset charLocation = renderEditable
        .getLocalRectForCaret(const TextPosition(offset: 10)).center;
    final Offset globalCharLocation = charLocation + tester.getTopLeft(find.byType(FakeEditable));

    // Right clicking on a word should select it
    await gesture.down(globalCharLocation);
    await gesture.up();
    await tester.pump();
    expect(renderEditable.selectWordCalled, isTrue);

    // Right clicking on a word within a selection shouldn't change the selection
    renderEditable.selectWordCalled = false;
    renderEditable.selection = const TextSelection(baseOffset: 3, extentOffset: 20);
    await gesture.down(globalCharLocation);
    await gesture.up();
    await tester.pump();
    expect(renderEditable.selectWordCalled, isFalse);

    // Right clicking on a word within a reverse (right-to-left) selection shouldn't change the selection
    renderEditable.selectWordCalled = false;
    renderEditable.selection = const TextSelection(baseOffset: 20, extentOffset: 3);
    await gesture.down(globalCharLocation);
    await gesture.up();
    await tester.pump();
    expect(renderEditable.selectWordCalled, isFalse);
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS, TargetPlatform.macOS }),
  );

  testWidgets('TextSelectionGestureDetectorBuilder right click non-Apple platforms', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/80119
    await pumpTextSelectionGestureDetectorBuilder(tester);

    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    renderEditable.text = const TextSpan(text: 'one two three four five six seven');
    await tester.pump();

    final TestGesture gesture = await tester.createGesture(
      pointer: 0,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(gesture.removePointer);

    // Get the location of the 10th character
    final Offset charLocation = renderEditable
        .getLocalRectForCaret(const TextPosition(offset: 10)).center;
    final Offset globalCharLocation = charLocation + tester.getTopLeft(find.byType(FakeEditable));

    // Right clicking on an unfocused field should place the cursor, not select
    // the word.
    await gesture.down(globalCharLocation);
    await gesture.up();
    await tester.pump();
    expect(renderEditable.selectWordCalled, isFalse);
    expect(renderEditable.selectPositionCalled, isTrue);

    // Right clicking on a focused field with selection shouldn't change the
    // selection.
    renderEditable.selectPositionCalled = false;
    renderEditable.selection = const TextSelection(baseOffset: 3, extentOffset: 20);
    renderEditable.hasFocus = true;
    await gesture.down(globalCharLocation);
    await gesture.up();
    await tester.pump();
    expect(renderEditable.selectWordCalled, isFalse);
    expect(renderEditable.selectPositionCalled, isFalse);

    // Right clicking on a focused field with a reverse (right to left)
    // selection shouldn't change the selection.
    renderEditable.selection = const TextSelection(baseOffset: 20, extentOffset: 3);
    await gesture.down(globalCharLocation);
    await gesture.up();
    await tester.pump();
    expect(renderEditable.selectWordCalled, isFalse);
    expect(renderEditable.selectPositionCalled, isFalse);
  },
    variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android, TargetPlatform.fuchsia, TargetPlatform.linux, TargetPlatform.windows }),
  );

  testWidgets('test TextSelectionGestureDetectorBuilder tap', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester);
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: 0,
    );
    addTearDown(gesture.removePointer);
    await gesture.up();
    await tester.pumpAndSettle();

    final FakeEditableTextState state = tester.state(find.byType(FakeEditableText));
    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    expect(state.showToolbarCalled, isFalse);

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        expect(renderEditable.selectWordEdgeCalled, isTrue);
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(renderEditable.selectPositionAtCalled, isTrue);
        break;
    }
  }, variant: TargetPlatformVariant.all());

  testWidgets('test TextSelectionGestureDetectorBuilder double tap', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester);
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: 0,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await gesture.down(const Offset(200.0, 200.0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    final FakeEditableTextState state = tester.state(find.byType(FakeEditableText));
    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    expect(state.showToolbarCalled, isTrue);
    expect(renderEditable.selectWordCalled, isTrue);
  });

  testWidgets('test TextSelectionGestureDetectorBuilder forcePress enabled', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester);
    final TestGesture gesture = await tester.createGesture();
    addTearDown(gesture.removePointer);
    await gesture.downWithCustomEvent(
      const Offset(200.0, 200.0),
      const PointerDownEvent(
        position: Offset(200.0, 200.0),
        pressure: 3.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    await gesture.updateWithCustomEvent(
      const PointerUpEvent(
        position: Offset(200.0, 200.0),
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    await tester.pump();

    final FakeEditableTextState state = tester.state(find.byType(FakeEditableText));
    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    expect(state.showToolbarCalled, isTrue);
    expect(renderEditable.selectWordsInRangeCalled, isTrue);
  });

  testWidgets('Mouse drag does not show handles nor toolbar', (WidgetTester tester) async {
    // Regressing test for https://github.com/flutter/flutter/issues/69001
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectableText('I love Flutter!'),
        ),
      ),
    );

    final Offset textFieldStart = tester.getTopLeft(find.byType(SelectableText));

    final TestGesture gesture = await tester.startGesture(textFieldStart, kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(textFieldStart + const Offset(50.0, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final EditableTextState editableText = tester.state(find.byType(EditableText));
    expect(editableText.selectionOverlay!.handlesAreVisible, isFalse);
    expect(editableText.selectionOverlay!.toolbarIsVisible, isFalse);
  });

  testWidgets('test TextSelectionGestureDetectorBuilder drag with RenderEditable viewport offset change', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester);
    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));

    // Reconfigure the RenderEditable for multi-line.
    renderEditable.maxLines = null;
    renderEditable.offset = ViewportOffset.fixed(20.0);
    renderEditable.layout(const BoxConstraints.tightFor(width: 400, height: 300.0));
    await tester.pumpAndSettle();

    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pumpAndSettle();
    expect(renderEditable.selectPositionAtCalled, isFalse);

    await gesture.moveTo(const Offset(300.0, 200.0));
    await tester.pumpAndSettle();
    expect(renderEditable.selectPositionAtCalled, isTrue);
    expect(renderEditable.selectPositionAtFrom, const Offset(200.0, 200.0));
    expect(renderEditable.selectPositionAtTo, const Offset(300.0, 200.0));

    // Move the viewport offset (scroll).
    renderEditable.offset = ViewportOffset.fixed(150.0);
    renderEditable.layout(const BoxConstraints.tightFor(width: 400, height: 300.0));
    await tester.pumpAndSettle();

    await gesture.moveTo(const Offset(300.0, 400.0));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(renderEditable.selectPositionAtCalled, isTrue);
    expect(renderEditable.selectPositionAtFrom, const Offset(200.0, 70.0));
    expect(renderEditable.selectPositionAtTo, const Offset(300.0, 400.0));
  });

  testWidgets('test TextSelectionGestureDetectorBuilder selection disabled', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester, selectionEnabled: false);
    final TestGesture gesture = await tester.startGesture(
      const Offset(200.0, 200.0),
      pointer: 0,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.pumpAndSettle();

    final FakeEditableTextState state = tester.state(find.byType(FakeEditableText));
    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    expect(state.showToolbarCalled, isTrue);
    expect(renderEditable.selectWordsInRangeCalled, isFalse);
  });

  testWidgets('test TextSelectionGestureDetectorBuilder mouse drag disabled', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester, selectionEnabled: false);
    final TestGesture gesture = await tester.startGesture(
      Offset.zero,
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(const Offset(50.0, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    expect(renderEditable.selectPositionAtCalled, isFalse);
  });

  testWidgets('test TextSelectionGestureDetectorBuilder forcePress disabled', (WidgetTester tester) async {
    await pumpTextSelectionGestureDetectorBuilder(tester, forcePressEnabled: false);
    final TestGesture gesture = await tester.createGesture();
    addTearDown(gesture.removePointer);
    await gesture.downWithCustomEvent(
      const Offset(200.0, 200.0),
      const PointerDownEvent(
        position: Offset(200.0, 200.0),
        pressure: 3.0,
        pressureMax: 6.0,
        pressureMin: 0.0,
      ),
    );
    await gesture.up();
    await tester.pump();

    final FakeEditableTextState state = tester.state(find.byType(FakeEditableText));
    final FakeRenderEditable renderEditable = tester.renderObject(find.byType(FakeEditable));
    expect(state.showToolbarCalled, isFalse);
    expect(renderEditable.selectWordsInRangeCalled, isFalse);
  });

  // Regression test for https://github.com/flutter/flutter/issues/37032.
  testWidgets("selection handle's GestureDetector should not cover the entire screen", (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(text: 'a');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            autofocus: true,
            controller: controller,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final Finder gestureDetector = find.descendant(
      of: find.byType(CompositedTransformFollower),
      matching: find.descendant(
        of: find.byType(FadeTransition),
        matching: find.byType(GestureDetector),
      ),
    );

    expect(gestureDetector, findsOneWidget);
    // The GestureDetector's size should not exceed that of the TextField.
    final Rect hitRect = tester.getRect(gestureDetector);
    final Rect textFieldRect = tester.getRect(find.byType(TextField));

    expect(hitRect.size.width, lessThan(textFieldRect.size.width));
    expect(hitRect.size.height, lessThan(textFieldRect.size.height));
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS }));

  group('SelectionOverlay', () {
    Future<SelectionOverlay> pumpApp(WidgetTester tester, {
      ValueChanged<DragStartDetails>? onStartDragStart,
      ValueChanged<DragUpdateDetails>? onStartDragUpdate,
      ValueChanged<DragEndDetails>? onStartDragEnd,
      ValueChanged<DragStartDetails>? onEndDragStart,
      ValueChanged<DragUpdateDetails>? onEndDragUpdate,
      ValueChanged<DragEndDetails>? onEndDragEnd,
      VoidCallback? onSelectionHandleTapped,
      TextSelectionControls? selectionControls,
    }) async {
      final UniqueKey column = UniqueKey();
      final LayerLink startHandleLayerLink = LayerLink();
      final LayerLink endHandleLayerLink = LayerLink();
      final LayerLink toolbarLayerLink = LayerLink();
      await tester.pumpWidget(MaterialApp(
        home: Column(
          key: column,
          children: <Widget>[
            CompositedTransformTarget(
              link: startHandleLayerLink,
              child: const Text('start handle'),
            ),
            CompositedTransformTarget(
              link: endHandleLayerLink,
              child: const Text('end handle'),
            ),
            CompositedTransformTarget(
              link: toolbarLayerLink,
              child: const Text('toolbar'),
            ),
          ],
        ),
      ));

      return SelectionOverlay(
        context: tester.element(find.byKey(column)),
        onSelectionHandleTapped: onSelectionHandleTapped,
        startHandleType: TextSelectionHandleType.collapsed,
        startHandleLayerLink: startHandleLayerLink,
        lineHeightAtStart: 0.0,
        onStartHandleDragStart: onStartDragStart,
        onStartHandleDragUpdate: onStartDragUpdate,
        onStartHandleDragEnd: onStartDragEnd,
        endHandleType: TextSelectionHandleType.collapsed,
        endHandleLayerLink: endHandleLayerLink,
        lineHeightAtEnd: 0.0,
        onEndHandleDragStart: onEndDragStart,
        onEndHandleDragUpdate: onEndDragUpdate,
        onEndHandleDragEnd: onEndDragEnd,
        clipboardStatus: FakeClipboardStatusNotifier(),
        selectionDelegate: FakeTextSelectionDelegate(),
        selectionControls: selectionControls,
        selectionEndPoints: const <TextSelectionPoint>[],
        toolbarLayerLink: toolbarLayerLink,
      );
    }

    testWidgets('can show and hide handles', (WidgetTester tester) async {
      final TextSelectionControlsSpy spy = TextSelectionControlsSpy();
      final SelectionOverlay selectionOverlay = await pumpApp(
        tester,
        selectionControls: spy,
      );
      selectionOverlay
        ..startHandleType = TextSelectionHandleType.left
        ..endHandleType = TextSelectionHandleType.right
        ..selectionEndPoints = const <TextSelectionPoint>[
          TextSelectionPoint(Offset(10, 10), TextDirection.ltr),
          TextSelectionPoint(Offset(20, 20), TextDirection.ltr),
        ];
      selectionOverlay.showHandles();
      await tester.pump();
      expect(find.byKey(spy.leftHandleKey), findsOneWidget);
      expect(find.byKey(spy.rightHandleKey), findsOneWidget);

      selectionOverlay.hideHandles();
      await tester.pump();
      expect(find.byKey(spy.leftHandleKey), findsNothing);
      expect(find.byKey(spy.rightHandleKey), findsNothing);

      selectionOverlay.showToolbar();
      await tester.pump();
      expect(find.byKey(spy.toolBarKey), findsOneWidget);

      selectionOverlay.hideToolbar();
      await tester.pump();
      expect(find.byKey(spy.toolBarKey), findsNothing);

      selectionOverlay.showHandles();
      selectionOverlay.showToolbar();
      await tester.pump();
      expect(find.byKey(spy.leftHandleKey), findsOneWidget);
      expect(find.byKey(spy.rightHandleKey), findsOneWidget);
      expect(find.byKey(spy.toolBarKey), findsOneWidget);

      selectionOverlay.hide();
      await tester.pump();
      expect(find.byKey(spy.leftHandleKey), findsNothing);
      expect(find.byKey(spy.rightHandleKey), findsNothing);
      expect(find.byKey(spy.toolBarKey), findsNothing);
    });

    testWidgets('only paints one collapsed handle', (WidgetTester tester) async {
      final TextSelectionControlsSpy spy = TextSelectionControlsSpy();
      final SelectionOverlay selectionOverlay = await pumpApp(
        tester,
        selectionControls: spy,
      );
      selectionOverlay
        ..startHandleType = TextSelectionHandleType.collapsed
        ..endHandleType = TextSelectionHandleType.collapsed
        ..selectionEndPoints = const <TextSelectionPoint>[
          TextSelectionPoint(Offset(10, 10), TextDirection.ltr),
          TextSelectionPoint(Offset(20, 20), TextDirection.ltr),
        ];
      selectionOverlay.showHandles();
      await tester.pump();
      expect(find.byKey(spy.leftHandleKey), findsNothing);
      expect(find.byKey(spy.rightHandleKey), findsNothing);
      expect(find.byKey(spy.collapsedHandleKey), findsOneWidget);
    });

    testWidgets('can change handle parameter', (WidgetTester tester) async {
      final TextSelectionControlsSpy spy = TextSelectionControlsSpy();
      final SelectionOverlay selectionOverlay = await pumpApp(
        tester,
        selectionControls: spy,
      );
      selectionOverlay
        ..startHandleType = TextSelectionHandleType.left
        ..lineHeightAtStart = 10.0
        ..endHandleType = TextSelectionHandleType.right
        ..lineHeightAtEnd = 11.0
        ..selectionEndPoints = const <TextSelectionPoint>[
          TextSelectionPoint(Offset(10, 10), TextDirection.ltr),
          TextSelectionPoint(Offset(20, 20), TextDirection.ltr),
        ];
      selectionOverlay.showHandles();
      await tester.pump();
      Text leftHandle = tester.widget(find.byKey(spy.leftHandleKey)) as Text;
      Text rightHandle = tester.widget(find.byKey(spy.rightHandleKey)) as Text;
      expect(leftHandle.data, 'height 10');
      expect(rightHandle.data, 'height 11');

      selectionOverlay
        ..startHandleType = TextSelectionHandleType.right
        ..lineHeightAtStart = 12.0
        ..endHandleType = TextSelectionHandleType.left
        ..lineHeightAtEnd = 13.0;
      await tester.pump();
      leftHandle = tester.widget(find.byKey(spy.leftHandleKey)) as Text;
      rightHandle = tester.widget(find.byKey(spy.rightHandleKey)) as Text;
      expect(leftHandle.data, 'height 13');
      expect(rightHandle.data, 'height 12');
    });

    testWidgets('can trigger selection handle onTap', (WidgetTester tester) async {
      bool selectionHandleTapped = false;
      void handleTapped() => selectionHandleTapped = true;
      final TextSelectionControlsSpy spy = TextSelectionControlsSpy();
      final SelectionOverlay selectionOverlay = await pumpApp(
        tester,
        onSelectionHandleTapped: handleTapped,
        selectionControls: spy,
      );
      selectionOverlay
        ..startHandleType = TextSelectionHandleType.left
        ..lineHeightAtStart = 10.0
        ..endHandleType = TextSelectionHandleType.right
        ..lineHeightAtEnd = 11.0
        ..selectionEndPoints = const <TextSelectionPoint>[
          TextSelectionPoint(Offset(10, 10), TextDirection.ltr),
          TextSelectionPoint(Offset(20, 20), TextDirection.ltr),
        ];
      selectionOverlay.showHandles();
      await tester.pump();
      expect(find.byKey(spy.leftHandleKey), findsOneWidget);
      expect(find.byKey(spy.rightHandleKey), findsOneWidget);
      expect(selectionHandleTapped, isFalse);

      await tester.tap(find.byKey(spy.leftHandleKey));
      expect(selectionHandleTapped, isTrue);

      selectionHandleTapped = false;
      await tester.tap(find.byKey(spy.rightHandleKey));
      expect(selectionHandleTapped, isTrue);
    });

    testWidgets('can trigger selection handle drag', (WidgetTester tester) async {
      DragStartDetails? startDragStartDetails;
      DragUpdateDetails? startDragUpdateDetails;
      DragEndDetails? startDragEndDetails;
      DragStartDetails? endDragStartDetails;
      DragUpdateDetails? endDragUpdateDetails;
      DragEndDetails? endDragEndDetails;
      void startDragStart(DragStartDetails details) => startDragStartDetails = details;
      void startDragUpdate(DragUpdateDetails details) => startDragUpdateDetails = details;
      void startDragEnd(DragEndDetails details) => startDragEndDetails = details;
      void endDragStart(DragStartDetails details) => endDragStartDetails = details;
      void endDragUpdate(DragUpdateDetails details) => endDragUpdateDetails = details;
      void endDragEnd(DragEndDetails details) => endDragEndDetails = details;
      final TextSelectionControlsSpy spy = TextSelectionControlsSpy();
      final SelectionOverlay selectionOverlay = await pumpApp(
        tester,
        onStartDragStart: startDragStart,
        onStartDragUpdate: startDragUpdate,
        onStartDragEnd: startDragEnd,
        onEndDragStart: endDragStart,
        onEndDragUpdate: endDragUpdate,
        onEndDragEnd: endDragEnd,
        selectionControls: spy,
      );
      selectionOverlay
        ..startHandleType = TextSelectionHandleType.left
        ..lineHeightAtStart = 10.0
        ..endHandleType = TextSelectionHandleType.right
        ..lineHeightAtEnd = 11.0
        ..selectionEndPoints = const <TextSelectionPoint>[
          TextSelectionPoint(Offset(10, 10), TextDirection.ltr),
          TextSelectionPoint(Offset(20, 20), TextDirection.ltr),
        ];
      selectionOverlay.showHandles();
      await tester.pump();
      expect(find.byKey(spy.leftHandleKey), findsOneWidget);
      expect(find.byKey(spy.rightHandleKey), findsOneWidget);
      expect(startDragStartDetails, isNull);
      expect(startDragUpdateDetails, isNull);
      expect(startDragEndDetails, isNull);
      expect(endDragStartDetails, isNull);
      expect(endDragUpdateDetails, isNull);
      expect(endDragEndDetails, isNull);

      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byKey(spy.leftHandleKey)));
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 200));
      expect(startDragStartDetails!.globalPosition, tester.getCenter(find.byKey(spy.leftHandleKey)));

      const Offset newLocation = Offset(20, 20);
      await gesture.moveTo(newLocation);
      await tester.pump(const Duration(milliseconds: 20));
      expect(startDragUpdateDetails!.globalPosition, newLocation);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(startDragEndDetails, isNotNull);

      final TestGesture gesture2 = await tester.startGesture(tester.getCenter(find.byKey(spy.rightHandleKey)));
      addTearDown(gesture2.removePointer);
      await tester.pump(const Duration(milliseconds: 200));
      expect(endDragStartDetails!.globalPosition, tester.getCenter(find.byKey(spy.rightHandleKey)));

      await gesture2.moveTo(newLocation);
      await tester.pump(const Duration(milliseconds: 20));
      expect(endDragUpdateDetails!.globalPosition, newLocation);

      await gesture2.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(endDragEndDetails, isNotNull);
    });
  });

  group('ClipboardStatusNotifier', () {
    group('when Clipboard fails', () {
      setUp(() {
        final MockClipboard mockClipboard = MockClipboard(hasStringsThrows: true);
        TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, mockClipboard.handleMethodCall);
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      test('Clipboard API failure is gracefully recovered from', () async {
        final ClipboardStatusNotifier notifier = ClipboardStatusNotifier();
        expect(notifier.value, ClipboardStatus.unknown);

        await expectLater(notifier.update(), completes);
        expect(notifier.value, ClipboardStatus.unknown);
      });
    });

    group('when Clipboard succeeds', () {
      final MockClipboard mockClipboard = MockClipboard();

      setUp(() {
        TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, mockClipboard.handleMethodCall);
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      test('update sets value based on clipboard contents', () async {
        final ClipboardStatusNotifier notifier = ClipboardStatusNotifier();
        expect(notifier.value, ClipboardStatus.unknown);

        await expectLater(notifier.update(), completes);
        expect(notifier.value, ClipboardStatus.notPasteable);

        mockClipboard.handleMethodCall(const MethodCall(
          'Clipboard.setData',
          <String, dynamic>{
            'text': 'pasteablestring',
          },
        ));
        await expectLater(notifier.update(), completes);
        expect(notifier.value, ClipboardStatus.pasteable);
      });
    });
  });
}

class FakeTextSelectionGestureDetectorBuilderDelegate implements TextSelectionGestureDetectorBuilderDelegate {
  FakeTextSelectionGestureDetectorBuilderDelegate({
    required this.editableTextKey,
    required this.forcePressEnabled,
    required this.selectionEnabled,
  });

  @override
  final GlobalKey<EditableTextState> editableTextKey;

  @override
  final bool forcePressEnabled;

  @override
  final bool selectionEnabled;
}

class FakeEditableText extends EditableText {
  FakeEditableText({super.key}): super(
    controller: TextEditingController(),
    focusNode: FocusNode(),
    backgroundCursorColor: Colors.white,
    cursorColor: Colors.white,
    style: const TextStyle(),
  );

  @override
  FakeEditableTextState createState() => FakeEditableTextState();
}

class FakeEditableTextState extends EditableTextState {
  final GlobalKey _editableKey = GlobalKey();
  bool showToolbarCalled = false;

  @override
  RenderEditable get renderEditable => _editableKey.currentContext!.findRenderObject()! as RenderEditable;

  @override
  bool showToolbar() {
    showToolbarCalled = true;
    return true;
  }

  @override
  void toggleToolbar() {
    return;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FakeEditable(this, key: _editableKey);
  }
}

class FakeEditable extends LeafRenderObjectWidget {
  const FakeEditable(
    this.delegate, {
    super.key,
  });
  final EditableTextState delegate;

  @override
  RenderEditable createRenderObject(BuildContext context) {
    return FakeRenderEditable(delegate);
  }
}

class FakeRenderEditable extends RenderEditable {
  FakeRenderEditable(EditableTextState delegate) : super(
    text: const TextSpan(
      style: TextStyle(height: 1.0, fontSize: 10.0, fontFamily: 'Ahem'),
      text: 'placeholder',
    ),
    startHandleLayerLink: LayerLink(),
    endHandleLayerLink: LayerLink(),
    ignorePointer: true,
    textAlign: TextAlign.start,
    textDirection: TextDirection.ltr,
    locale: const Locale('en', 'US'),
    offset: ViewportOffset.fixed(10.0),
    textSelectionDelegate: delegate,
    selection: const TextSelection.collapsed(
      offset: 0,
    ),
  );

  bool selectWordsInRangeCalled = false;
  @override
  void selectWordsInRange({ required Offset from, Offset? to, required SelectionChangedCause cause }) {
    selectWordsInRangeCalled = true;
  }

  bool selectWordEdgeCalled = false;
  @override
  void selectWordEdge({ required SelectionChangedCause cause }) {
    selectWordEdgeCalled = true;
  }

  bool selectPositionAtCalled = false;
  Offset? selectPositionAtFrom;
  Offset? selectPositionAtTo;
  @override
  void selectPositionAt({ required Offset from, Offset? to, required SelectionChangedCause cause }) {
    selectPositionAtCalled = true;
    selectPositionAtFrom = from;
    selectPositionAtTo = to;
  }

  bool selectPositionCalled = false;
  @override
  void selectPosition({ required SelectionChangedCause cause }) {
    selectPositionCalled = true;
    return super.selectPosition(cause: cause);
  }

  bool selectWordCalled = false;
  @override
  void selectWord({ required SelectionChangedCause cause }) {
    selectWordCalled = true;
  }

  @override
  bool hasFocus = false;
}

class CustomTextSelectionControls extends TextSelectionControls {
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    throw UnimplementedError();
  }

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset position,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ClipboardStatusNotifier? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    throw UnimplementedError();
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    throw UnimplementedError();
  }

  @override
  Size getHandleSize(double textLineHeight) {
    throw UnimplementedError();
  }
}

class TextSelectionControlsSpy extends TextSelectionControls {
  UniqueKey leftHandleKey = UniqueKey();
  UniqueKey rightHandleKey = UniqueKey();
  UniqueKey collapsedHandleKey = UniqueKey();
  UniqueKey toolBarKey = UniqueKey();

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    switch (type) {
      case TextSelectionHandleType.left:
        return ElevatedButton(onPressed: onTap, child: Text('height ${textLineHeight.toInt()}', key: leftHandleKey));
      case TextSelectionHandleType.right:
        return ElevatedButton(onPressed: onTap, child: Text('height ${textLineHeight.toInt()}', key: rightHandleKey));
      case TextSelectionHandleType.collapsed:
        return ElevatedButton(onPressed: onTap, child: Text('height ${textLineHeight.toInt()}', key: collapsedHandleKey));
    }
  }

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset position,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ClipboardStatusNotifier? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    return Text('dummy', key: toolBarKey);
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return Offset.zero;
  }

  @override
  Size getHandleSize(double textLineHeight) {
    return Size(textLineHeight, textLineHeight);
  }
}

class FakeClipboardStatusNotifier extends ClipboardStatusNotifier {
  FakeClipboardStatusNotifier() : super(value: ClipboardStatus.unknown);

  bool updateCalled = false;
  @override
  Future<void> update() async {
    updateCalled = true;
  }
}

class FakeTextSelectionDelegate extends Fake implements TextSelectionDelegate {
  @override
  void cutSelection(SelectionChangedCause cause) { }

  @override
  void copySelection(SelectionChangedCause cause) { }
}
