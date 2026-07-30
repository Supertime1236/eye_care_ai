package com.eyecare.eye_care_ai

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.app.usage.UsageStatsManager
import java.util.Calendar
import android.content.pm.PackageManager
class UsageStatsHandler(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "eye_care/usage"
    }

    fun register(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(
        
        call: MethodCall,
        result: MethodChannel.Result
    ) {

        when (call.method) {

            "checkUsagePermission" -> {
                result.success(checkUsagePermission())
            }

            "openUsageSettings" -> {
                openUsageSettings()
                result.success(true)
            }

            "getTodayUsage" -> {
                try {
                    result.success(getTodayUsage())
                } catch (e: Exception) {
                    result.error(
                        "USAGE_ERROR",
                        e.message,
                        null
                    )
                }
            }
            "getWeeklyUsage" -> {
                result.success(getWeeklyUsage())
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Kiểm tra quyền Usage Access
     */
    private fun checkUsagePermission(): Boolean {

        val appOps =
            context.getSystemService(Context.APP_OPS_SERVICE)
                    as AppOpsManager

        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {

                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )

            } else {

                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )

            }

        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Mở màn hình cấp quyền Usage Access
     */
    private fun openUsageSettings() {

        // Thử mở thẳng tới đúng app trong danh sách Usage Access trước
        // (một số máy OEM như Xiaomi/Oppo cần data URI mới hiện đúng app).
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.data = android.net.Uri.fromParts("package", context.packageName, null)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            return
        } catch (e: Exception) {
            // fallthrough
        }

        // Fallback: mở danh sách chung Usage Access (không kèm package)
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            return
        } catch (e: Exception) {
            // fallthrough
        }

        // Fallback cuối: mở trang chi tiết app, người dùng tự vào Permissions
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = android.net.Uri.fromParts("package", context.packageName, null)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            // Không còn cách nào khác, bỏ qua
        }
    }

    private fun getAppName(packageName: String): String {

        return try {

            val appInfo =
                context.packageManager.getApplicationInfo(packageName, 0)

            context.packageManager
                .getApplicationLabel(appInfo)
                .toString()

        } catch (e: PackageManager.NameNotFoundException) {

            packageName

        }
    }
    
    /**
    * Lấy Usage Stats từ 00:00 hôm nay đến hiện tại.
    */
    private fun getTodayUsage(): List<Map<String, Any>> {
        if (!checkUsagePermission()) {
            throw Exception("Usage permission not granted")
        }

        val usageManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE)
                    as UsageStatsManager

        // 00:00 hôm nay
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageManager.queryAndAggregateUsageStats(
            startTime,
            endTime
        )

        val result = mutableListOf<Map<String, Any>>()
        val ignoredPackages = setOf(
            "android",
            "com.android.systemui",
            "com.google.android.gms"
        )

        for ((packageName, usage) in stats) {
            if (packageName in ignoredPackages)
                continue

            val totalTime =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    usage.totalTimeVisible
                else
                    @Suppress("DEPRECATION")
                    usage.totalTimeInForeground

            if (totalTime <= 0)
                continue

            val item = hashMapOf<String, Any>()

            item["packageName"] = packageName

            item["appName"] = getAppName(packageName)

            item["totalTime"] = totalTime

            item["lastTimeUsed"] = usage.lastTimeUsed

            result.add(item)
        }

        result.sortByDescending {

            (it["totalTime"] as Long)

        }

        return result
    }

    private fun getWeeklyUsage(): Map<String, List<Map<String, Any>>> {
        if (!checkUsagePermission()) {
            throw Exception("Usage permission not granted")
        }

        val usageManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE)
                    as UsageStatsManager

        val calendar = Calendar.getInstance()

        // Bắt đầu tuần (thứ 2)
        calendar.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageManager.queryAndAggregateUsageStats(
            startTime,
            endTime
        )

        val result = mutableMapOf<String, MutableList<Map<String, Any>>>()
        val ignoredPackages = setOf(
            "android",
            "com.android.systemui",
            "com.google.android.gms"
        )

        for ((packageName, usage) in stats) {
            if (packageName in ignoredPackages)
                continue

            val totalTime =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    usage.totalTimeVisible
                else
                    @Suppress("DEPRECATION")
                    usage.totalTimeInForeground

            if (totalTime <= 0)
                continue

            val item = hashMapOf<String, Any>()

            item["packageName"] = packageName

            item["appName"] = getAppName(packageName)

            item["totalTime"] = totalTime

            item["lastTimeUsed"] = usage.lastTimeUsed

            // Lấy ngày sử dụng
            val dayCalendar = Calendar.getInstance().apply {
                timeInMillis = usage.lastTimeUsed
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            val dayKey =
                "${dayCalendar.get(Calendar.YEAR)}-${dayCalendar.get(Calendar.MONTH) + 1}-${dayCalendar.get(Calendar.DAY_OF_MONTH)}"

            if (!result.containsKey(dayKey)) {
                result[dayKey] = mutableListOf()
            }

            result[dayKey]?.add(item)
        }

        return result
    }
}
