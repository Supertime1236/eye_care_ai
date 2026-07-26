package com.eyecare.eye_care_ai

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// MainActivity thêm một MethodChannel riêng cho các dữ liệu mà package
// `app_usage` không cung cấp đủ chính xác/đầy đủ:
// 1. hasUsageAccess: đã có quyền Usage access chưa
// 2. getLaunchCounts: số lần mở mỗi app hôm nay
// 3. getUsageBreakdown: thời gian dùng THẬT của từng app, tính bằng cách
//    ghép cặp sự kiện MOVE_TO_FOREGROUND/MOVE_TO_BACKGROUND — đây CHÍNH LÀ
//    cách Digital Wellbeing của Google tính toán nội bộ (không có API công
//    khai nào để đọc thẳng số liệu đã tính sẵn của Digital Wellbeing, nhưng
//    dùng cùng phương pháp thô này sẽ cho kết quả sát với nó hơn nhiều so với
//    UsageStatsManager.queryUsageStats() (cách cũ), vốn hay bị lệch do cách
//    Android gộp dữ liệu theo nhiều khung thời gian chồng lấn.
class MainActivity : FlutterActivity() {
    private val channelName = "eye_care_ai/usage_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccessPermission())
                "getLaunchCounts" -> {
                    val (start, end) = extractRange(call) ?: return@setMethodCallHandler result.error("BAD_ARGS", "startMillis/endMillis required", null)
                    result.success(getLaunchCounts(start, end))
                }
                "getUsageBreakdown" -> {
                    val (start, end) = extractRange(call) ?: return@setMethodCallHandler result.error("BAD_ARGS", "startMillis/endMillis required", null)
                    result.success(getUsageBreakdown(start, end))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extractRange(call: io.flutter.plugin.common.MethodCall): Pair<Long, Long>? {
        val start = (call.argument<Number>("startMillis"))?.toLong() ?: return null
        val end = (call.argument<Number>("endMillis"))?.toLong() ?: return null
        return start to end
    }

    private fun hasUsageAccessPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getLaunchCounts(startMillis: Long, endMillis: Long): Map<String, Int> {
        val counts = mutableMapOf<String, Int>()
        if (!hasUsageAccessPermission()) return counts

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events: UsageEvents = usageStatsManager.queryEvents(startMillis, endMillis)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                counts[event.packageName] = (counts[event.packageName] ?: 0) + 1
            }
        }
        return counts
    }

    // Ghép cặp MOVE_TO_FOREGROUND -> MOVE_TO_BACKGROUND (hoặc kết thúc
    // khoảng truy vấn nếu app vẫn đang mở) để tính tổng thời gian foreground
    // thật sự của từng app, kèm tên hiển thị (app label) để không cần gọi
    // thêm package_manager phía Dart.
    private fun getUsageBreakdown(startMillis: Long, endMillis: Long): List<Map<String, Any>> {
        if (!hasUsageAccessPermission()) return emptyList()

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events: UsageEvents = usageStatsManager.queryEvents(startMillis, endMillis)
        val event = UsageEvents.Event()

        val openTimestamps = mutableMapOf<String, Long>()
        val totalMillis = mutableMapOf<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    openTimestamps[event.packageName] = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val openedAt = openTimestamps.remove(event.packageName)
                    if (openedAt != null && event.timeStamp > openedAt) {
                        val duration = event.timeStamp - openedAt
                        totalMillis[event.packageName] = (totalMillis[event.packageName] ?: 0L) + duration
                    }
                }
            }
        }
        // Bất kỳ app nào còn "đang mở" (chưa có sự kiện background tương ứng
        // trước khi hết khoảng truy vấn) -> tính tới thời điểm endMillis.
        for ((pkg, openedAt) in openTimestamps) {
            if (endMillis > openedAt) {
                totalMillis[pkg] = (totalMillis[pkg] ?: 0L) + (endMillis - openedAt)
            }
        }

        val pm = packageManager
        return totalMillis.entries
            .filter { it.value >= 30_000 } // bỏ qua app dùng dưới 30 giây (nhiễu)
            .sortedByDescending { it.value }
            .map { (pkg, millis) ->
                val label = try {
                    pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    pkg
                }
                mapOf(
                    "packageName" to pkg,
                    "appName" to label,
                    "usageMillis" to millis
                )
            }
    }
}
