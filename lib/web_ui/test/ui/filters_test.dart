// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;
import 'package:web_engine_tester/golden_tester.dart';

import '../common/test_initialization.dart';
import 'utils.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

// TODO(jacksongardner): Skwasm doesn't support image codecs yet. Once it does,
// we can just replace this roundabout loading mechanism with a normal image
// load using flutter APIs.
Future<Uint8ClampedList> rgbaTestImageData() async {
  final DomHTMLImageElement image = createDomHTMLImageElement();
  image.src = '/test_images/mandrill_128.png';
  await image.decode();
  final DomCanvasElement canvas = createDomCanvasElement(width: 128, height: 128);
  final DomCanvasRenderingContext2D context = canvas.getContext('2d')! as DomCanvasRenderingContext2D;
  context.drawImage(image, 0, 0);
  return context.getImageData(0, 0, 128, 128).data;
}

Future<void> testMain() async {
  setUpUnitTests(
    setUpTestViewDimensions: false,
  );

  final Uint8List testImageData = Uint8List.fromList(await rgbaTestImageData());
  const ui.Rect region = ui.Rect.fromLTWH(0, 0, 128, 128);

  Future<void> drawTestImageWithPaint(ui.Paint paint) async {
    final Completer<ui.Image> imageCompleter = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      testImageData,
      128,
      128,
      ui.PixelFormat.rgba8888,
      (ui.Image image) => imageCompleter.complete(image),
    );
    final ui.Image image = await imageCompleter.future;
    expect(image.width, 128);
    expect(image.height, 128);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder, region);
    canvas.drawImage(
      image,
      ui.Offset.zero,
      paint,
    );

    await drawPictureUsingCurrentRenderer(recorder.endRecording());
  }

  test('blur filter', () async {
    await drawTestImageWithPaint(ui.Paint()..imageFilter = ui.ImageFilter.blur(
        sigmaX: 5.0,
        sigmaY: 5.0,
    ));
    await matchGoldenFile('ui_filter_blur_imagefilter.png', region: region);
  });

  test('dilate filter', () async {
    await drawTestImageWithPaint(ui.Paint()..imageFilter = ui.ImageFilter.dilate(
        radiusX: 5.0,
        radiusY: 5.0,
    ));
    await matchGoldenFile('ui_filter_dilate_imagefilter.png', region: region);
  }, skip: !isSkwasm); // Only skwasm supports dilate filter right now

  test('erode filter', () async {
    await drawTestImageWithPaint(ui.Paint()..imageFilter = ui.ImageFilter.erode(
        radiusX: 5.0,
        radiusY: 5.0,
    ));
    await matchGoldenFile('ui_filter_erode_imagefilter.png', region: region);
  }, skip: !isSkwasm); // Only skwasm supports erode filter

  test('matrix filter', () async {
    await drawTestImageWithPaint(ui.Paint()..imageFilter = ui.ImageFilter.matrix(
      Matrix4.rotationZ(math.pi / 6).toFloat64(),
      filterQuality: ui.FilterQuality.high,
    ));
    await matchGoldenFile('ui_filter_matrix_imagefilter.png', region: region);
  });

  test('composed filters', () async {
    final ui.ImageFilter filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.matrix(
        Matrix4.rotationZ(math.pi / 6).toFloat64(),
        filterQuality: ui.FilterQuality.high,
      ),
      inner: ui.ImageFilter.blur(
        sigmaX: 5.0,
        sigmaY: 5.0,
      )
    );
    await drawTestImageWithPaint(ui.Paint()..imageFilter = filter);
    await matchGoldenFile('ui_filter_composed_imagefilters.png', region: region);
  }, skip: !isSkwasm); // Only Skwasm implements composable filters right now.

  test('compose with colorfilter', () async {
    final ui.ImageFilter filter = ui.ImageFilter.compose(
      outer: const ui.ColorFilter.mode(
        ui.Color.fromRGBO(0, 0, 255, 128),
        ui.BlendMode.srcOver,
      ),
      inner: ui.ImageFilter.blur(
        sigmaX: 5.0,
        sigmaY: 5.0,
      )
    );
    await drawTestImageWithPaint(ui.Paint()..imageFilter = filter);
    await matchGoldenFile('ui_filter_composed_colorfilter.png', region: region);
  }, skip: !isSkwasm); // Only Skwasm implements composable filters right now.

  test('color filter as image filter', () async {
    const ui.ColorFilter colorFilter = ui.ColorFilter.mode(
      ui.Color.fromRGBO(0, 0, 255, 128),
      ui.BlendMode.srcOver,
    );
    await drawTestImageWithPaint(ui.Paint()..imageFilter = colorFilter);
    await matchGoldenFile('ui_filter_colorfilter_as_imagefilter.png', region: region);
  });

  test('mode color filter', () async {
    const ui.ColorFilter colorFilter = ui.ColorFilter.mode(
      ui.Color.fromRGBO(0, 0, 255, 128),
      ui.BlendMode.srcOver,
    );
    await drawTestImageWithPaint(ui.Paint()..colorFilter = colorFilter);
    await matchGoldenFile('ui_filter_mode_colorfilter.png', region: region);
  });

  test('linearToSRGBGamma color filter', () async {
    const ui.ColorFilter colorFilter = ui.ColorFilter.linearToSrgbGamma();
    await drawTestImageWithPaint(ui.Paint()..colorFilter = colorFilter);
    await matchGoldenFile('ui_filter_linear_to_srgb_colorfilter.png', region: region);
  }, skip: isHtml); // HTML renderer hasn't implemented this.

  test('srgbToLinearGamma color filter', () async {
    const ui.ColorFilter colorFilter = ui.ColorFilter.srgbToLinearGamma();
    await drawTestImageWithPaint(ui.Paint()..colorFilter = colorFilter);
    await matchGoldenFile('ui_filter_srgb_to_linear_colorfilter.png', region: region);
  }, skip: isHtml); // HTML renderer hasn't implemented this.

  test('matrix color filter', () async {
    const ui.ColorFilter sepia = ui.ColorFilter.matrix(<double>[
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0,     0,     0,     1, 0,
    ]);
    await drawTestImageWithPaint(ui.Paint()..colorFilter = sepia);
    await matchGoldenFile('ui_filter_matrix_colorfilter.png', region: region);
  });

  test('invert colors', () async {
    await drawTestImageWithPaint(ui.Paint()..invertColors = true);
    await matchGoldenFile('ui_filter_invert_colors.png', region: region);
  });

  test('invert colors with color filter', () async {
    const ui.ColorFilter sepia = ui.ColorFilter.matrix(<double>[
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0,     0,     0,     1, 0,
    ]);

    await drawTestImageWithPaint(ui.Paint()
      ..invertColors = true
      ..colorFilter = sepia);
    await matchGoldenFile('ui_filter_invert_colors_with_colorfilter.png', region: region);
  });

  test('mask filter', () async {
    const ui.MaskFilter maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 25.0);
    await drawTestImageWithPaint(ui.Paint()..maskFilter = maskFilter);
    await matchGoldenFile('ui_filter_blur_maskfilter.png', region: region);
  });
}
