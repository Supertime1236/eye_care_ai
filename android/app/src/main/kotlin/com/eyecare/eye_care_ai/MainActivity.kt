package com.eyecare.eye_care_ai

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// MainActivity thêm một MethodChannel riêng để:
// 1. Kiểm tra đã có quyền "Usage access" chưa (hasUsageAccess)
// 2. Đếm SỐ LẦN MỞ từng app hôm nay (getLaunchCounts) — dữ liệu này package
//    `app_usage` không cung cấp sẵn nên phải tự đọc UsageEvents của Android
//    (cùng nguồn dữ liệu UsageStatsManager, cùng quyền Usage access đã xin ở
//    trang Habits — không cần thêm quyền mới nào).
class MainActivity : FlutterActivity() {
    private val channelName = "eye_care_ai/usage_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccessPermission())
                "getLaunchCounts" -> {
                    val startMillis = (call.argument<Number>("startMillis"))?.toLong()
                    val endMillis = (call.argument<Number>("endMillis"))?.toLong()
                    if (startMillis == null || endMillis == null) {
                        result.error("BAD_ARGS", "startMillis/endMillis required", null)
                    } else {
                        result.success(getLaunchCounts(startMillis, endMillis))
                    }
                }
                else -> result.notImplemented()
            }
        }
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

    // Đếm số lần một app được đưa lên foreground (MOVE_TO_FOREGROUND) trong
    // khoảng thời gian [startMillis, endMillis) -> tương đương "số lần mở app".
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
}
