package com.eyecare.eye_care_ai

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

// Chế độ Focus: trong lúc đang đếm ngược giữa 2 lần nghỉ mắt ("đang làm
// việc"), bật Do Not Disturb của hệ thống ở mức "chỉ báo thức" để chặn
// thông báo từ app khác — tránh giật mình/mất tập trung/mỏi mắt do liên tục
// bị làm phiền. Tự tắt lại khi đến giờ nghỉ mắt hoặc người dùng dừng nhắc.
//
// LƯU Ý QUAN TRỌNG: "Notification policy access" (quyền bật/tắt DND) là
// quyền ĐẶC BIỆT của Android — KHÔNG có hộp thoại xin quyền runtime bình
// thường như camera/vị trí. Người dùng bắt buộc phải tự vào đúng màn hình
// Cài đặt hệ thống để bật tay (openAccessSettings() chỉ mở đúng màn hình đó
// giúp, không tự bật được).
class FocusModeHandler(private val context: Context) {
    private val channelName = "eye_care_ai/focus_mode"

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasAccess())
                "openAccessSettings" -> {
                    openAccessSettings()
                    result.success(null)
                }
                "enable" -> result.success(setFocus(true))
                "disable" -> result.success(setFocus(false))
                "isEnabled" -> result.success(isCurrentlyEnabled())
                else -> result.notImplemented()
            }
        }
    }

    private fun notificationManager(): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun hasAccess(): Boolean = notificationManager().isNotificationPolicyAccessGranted

    private fun openAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    // INTERRUPTION_FILTER_PRIORITY: chặn hầu hết thông báo app khác, chỉ cho
    // qua báo thức + những gì người dùng đã đánh dấu "ưu tiên" trong Cài đặt
    // hệ thống — vẫn nghe được báo thức nghỉ mắt của chính app này (được
    // đăng ký như thông báo ưu tiên cao/full-screen intent).
    private fun setFocus(enabled: Boolean): Boolean {
        if (!hasAccess()) return false
        val nm = notificationManager()
        nm.setInterruptionFilter(
            if (enabled) NotificationManager.INTERRUPTION_FILTER_PRIORITY
            else NotificationManager.INTERRUPTION_FILTER_ALL
        )
        return true
    }

    private fun isCurrentlyEnabled(): Boolean =
        notificationManager().currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY
}