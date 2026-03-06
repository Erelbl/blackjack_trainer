import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Debug-only rebuild counter. All methods are no-ops in release mode.
///
/// Usage:
///   In build(): RebuildCounter.increment('WidgetName');
///   At a trigger point: RebuildCounter.printAndReset('trigger_label');
class RebuildCounter {
  RebuildCounter._();

  static final Map<String, int> _counts = {};

  /// Increment the rebuild count for [name]. No-op in release mode.
  static void increment(String name) {
    if (!kDebugMode) return;
    _counts[name] = (_counts[name] ?? 0) + 1;
  }

  /// Print accumulated counts with [trigger] label, then clear. No-op in release.
  static void printAndReset(String trigger) {
    if (!kDebugMode) return;
    if (_counts.isEmpty) return;
    debugPrint('[RebuildCounter] trigger=$trigger | $_counts');
    _counts.clear();
  }
}

/// Debug-only frame timing monitor. Accumulates slow-frame stats across frames
/// and prints a summary only at explicit trigger points (no per-frame spam).
///
/// Usage:
///   Once at startup: FramePerfMonitor.start();
///   At trigger points: FramePerfMonitor.printAndReset('trigger_label');
class FramePerfMonitor {
  FramePerfMonitor._();

  static int _droppedFrames = 0;
  static double _worstBuildMs = 0;
  static double _worstRasterMs = 0;
  static bool _registered = false;

  /// Register the timings callback. Safe to call multiple times; registers once.
  static void start() {
    if (!kDebugMode || _registered) return;
    _registered = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      if (buildMs > 16 || rasterMs > 16) _droppedFrames++;
      if (buildMs > _worstBuildMs) _worstBuildMs = buildMs;
      if (rasterMs > _worstRasterMs) _worstRasterMs = rasterMs;
    }
  }

  /// Print accumulated summary, then reset counters. No-op in release mode.
  static void printAndReset(String trigger) {
    if (!kDebugMode) return;
    debugPrint(
      '[FramePerf] trigger=$trigger | '
      'droppedFrames=$_droppedFrames '
      'worstBuildMs=${_worstBuildMs.toStringAsFixed(1)} '
      'worstRasterMs=${_worstRasterMs.toStringAsFixed(1)}',
    );
    _droppedFrames = 0;
    _worstBuildMs = 0;
    _worstRasterMs = 0;
  }
}
