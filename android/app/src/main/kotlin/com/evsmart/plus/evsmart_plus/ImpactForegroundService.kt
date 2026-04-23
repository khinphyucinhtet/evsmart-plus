package com.evsmart.plus.evsmart_plus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.sqrt

class ImpactForegroundService : Service(), SensorEventListener {

    companion object {
        const val ACTION_START = "com.evsmart.plus.evsmart_plus.action.START_IMPACT_MONITOR"
        const val ACTION_STOP = "com.evsmart.plus.evsmart_plus.action.STOP_IMPACT_MONITOR"
        const val ACTION_CANCEL_PENDING = "com.evsmart.plus.evsmart_plus.action.CANCEL_PENDING_IMPACT"
        const val ACTION_SNOOZE = "com.evsmart.plus.evsmart_plus.action.SNOOZE_IMPACT_MONITOR"
        const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"

        const val PREFS_NAME = "evsmart_background_impact"
        const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_LATITUDE = "latitude"
        const val KEY_LONGITUDE = "longitude"
        const val KEY_LOCATION_NAME = "location_name"
        const val KEY_ROAD_NAME = "road_name"
        const val KEY_SNOOZED_UNTIL_MS = "snoozed_until_ms"
        const val KEY_FLUTTER_BACKGROUND_PROMPTED = "flutter.impact_background_prompted"
        const val KEY_FLUTTER_BACKGROUND_ENABLED = "flutter.impact_background_alerts_enabled"

        private const val DATABASE_URL =
            "https://evsmart-2694c-default-rtdb.asia-southeast1.firebasedatabase.app"
        private const val SERVICE_CHANNEL_ID = "evsmart_background_impact_service"
        private const val ALERT_CHANNEL_ID = "evsmart_background_impact_alerts"
        private const val SERVICE_NOTIFICATION_ID = 44001
        private const val PENDING_NOTIFICATION_ID = 44002
        private const val RESULT_NOTIFICATION_ID = 44003
        private const val MINIMUM_IMPACT_THRESHOLD = 20.0
        private const val MINIMUM_SHOCK_DELTA = 8.0
        private const val TRIGGER_COOLDOWN_MS = 8000L
        private const val PENDING_COUNTDOWN_MS = 10000L
    }

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private lateinit var notificationManager: NotificationManager
    private val handler = Handler(Looper.getMainLooper())

    private var lastMagnitude = 9.8
    private var lastTriggerAt = 0L
    private var pendingImpact: PendingImpact? = null
    private var pendingRunnable: Runnable? = null
    private var monitoring = false

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopMonitoring()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_CANCEL_PENDING -> {
                cancelPendingImpact("Driver cancelled the background impact warning.")
                return START_STICKY
            }

            ACTION_SNOOZE -> {
                snoozeMonitoring(intent.getIntExtra(EXTRA_SNOOZE_MINUTES, 10))
                return START_STICKY
            }
        }

        startMonitoring()
        return START_STICKY
    }

    override fun onDestroy() {
        stopMonitoring()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || pendingImpact != null || isSnoozed()) {
            return
        }

        val magnitude = sqrt(
            event.values[0].toDouble().pow(2.0) +
                event.values[1].toDouble().pow(2.0) +
                event.values[2].toDouble().pow(2.0)
        )

        val shockDelta = abs(magnitude - lastMagnitude)
        lastMagnitude = magnitude

        if (magnitude < MINIMUM_IMPACT_THRESHOLD || shockDelta < MINIMUM_SHOCK_DELTA) {
            return
        }

        val now = System.currentTimeMillis()
        if (now - lastTriggerAt < TRIGGER_COOLDOWN_MS) {
            return
        }

        val level = classifyImpactLevel(magnitude)
        if (level == 0) {
            return
        }

        lastTriggerAt = now
        schedulePendingImpact(
            PendingImpact(
                level = level,
                magnitude = magnitude,
                detectedAtMs = now,
                description = impactDescription(level)
            )
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun startMonitoring() {
        if (monitoring) {
            return
        }

        startForeground(SERVICE_NOTIFICATION_ID, buildServiceNotification())
        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        monitoring = true
    }

    private fun stopMonitoring() {
        if (!monitoring) {
            return
        }

        sensorManager.unregisterListener(this)
        monitoring = false
        cancelPendingImpact(null)
    }

    private fun schedulePendingImpact(impact: PendingImpact) {
        pendingImpact = impact
        showPendingImpactNotification(impact)

        val runnable = Runnable {
            val currentImpact = pendingImpact ?: return@Runnable
            pendingImpact = null
            pendingRunnable = null
            notificationManager.cancel(PENDING_NOTIFICATION_ID)
            syncImpactToFirebase(currentImpact)
            showResultNotification(currentImpact)
        }

        pendingRunnable = runnable
        handler.postDelayed(runnable, PENDING_COUNTDOWN_MS)
    }

    private fun cancelPendingImpact(reason: String?) {
        pendingRunnable?.let(handler::removeCallbacks)
        pendingRunnable = null
        pendingImpact = null
        notificationManager.cancel(PENDING_NOTIFICATION_ID)
        if (reason != null) {
            notificationManager.notify(
                RESULT_NOTIFICATION_ID,
                NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("Impact alert cancelled")
                    .setContentText(reason)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setAutoCancel(true)
                    .build()
            )
        }
    }

    private fun snoozeMonitoring(minutes: Int) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val untilMs = if (minutes <= 0) {
            if (minutes < 0) Long.MAX_VALUE else 0L
        } else {
            System.currentTimeMillis() + minutes * 60_000L
        }
        prefs.edit().putLong(KEY_SNOOZED_UNTIL_MS, untilMs).apply()
        if (minutes < 0) {
            getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_FLUTTER_BACKGROUND_PROMPTED, false)
                .putBoolean(KEY_FLUTTER_BACKGROUND_ENABLED, false)
                .apply()
        }
        cancelPendingImpact(null)
        notificationManager.notify(SERVICE_NOTIFICATION_ID, buildServiceNotification())
    }

    private fun isSnoozed(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val untilMs = prefs.getLong(KEY_SNOOZED_UNTIL_MS, 0L)
        if (untilMs <= 0L) {
            return false
        }
        if (untilMs == Long.MAX_VALUE) {
            return true
        }
        if (System.currentTimeMillis() >= untilMs) {
            prefs.edit().remove(KEY_SNOOZED_UNTIL_MS).apply()
            notificationManager.notify(SERVICE_NOTIFICATION_ID, buildServiceNotification())
            return false
        }
        return true
    }

    private fun showPendingImpactNotification(impact: PendingImpact) {
        val alertIntent = Intent(this, ImpactAlertActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("impact_level", impact.level)
            putExtra("impact_description", impact.description)
            putExtra("countdown_seconds", (PENDING_COUNTDOWN_MS / 1000L).toInt())
        }
        val alertPendingIntent = PendingIntent.getActivity(
            this,
            21,
            alertIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(
            this,
            23,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val cancelIntent = Intent(this, ImpactForegroundService::class.java).apply {
            action = ACTION_CANCEL_PENDING
        }
        val cancelPendingIntent = PendingIntent.getService(
            this,
            22,
            cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val body = if (impact.level >= 4) {
            "Severe impact detected. Cancel within 5 seconds if it is a false alarm."
        } else {
            "A bump or light impact was detected. Cancel within 5 seconds if it is safe."
        }

        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(severityLabel(impact.level))
            .setContentText(body)
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "$body ${impact.description}"
                )
            )
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setVibrate(longArrayOf(0, 350, 180, 350))
            .setContentIntent(alertPendingIntent)
            .setFullScreenIntent(alertPendingIntent, true)
            .addAction(0, "Open App", openPendingIntent)
            .addAction(0, "Cancel", cancelPendingIntent)
            .build()

        notificationManager.notify(PENDING_NOTIFICATION_ID, notification)
        try {
            startActivity(alertIntent)
        } catch (_: Exception) {
            // Android may block direct background activity launches; the
            // full-screen notification above is the compliant fallback.
        }
    }

    private fun showResultNotification(impact: PendingImpact) {
        val body = if (impact.level >= 4) {
            "Auto alert synced to the hospital and insurance dashboards."
        } else {
            "Impact log synced to the insurance dashboard and support feeds."
        }

        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("${severityLabel(impact.level)} logged")
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(RESULT_NOTIFICATION_ID, notification)
    }

    private fun buildServiceNotification(): Notification {
        val controlIntent = Intent(this, ImpactMonitorControlActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val controlPendingIntent = PendingIntent.getActivity(
            this,
            24,
            controlIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val snoozedUntilMs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(KEY_SNOOZED_UNTIL_MS, 0L)
        val contentText = if (snoozedUntilMs == Long.MAX_VALUE) {
            "Paused until you turn it back on. Open EVSmart+ to enable again."
        } else if (snoozedUntilMs > System.currentTimeMillis()) {
            "Paused until ${clockLabel(snoozedUntilMs)}. Tap to change pause time."
        } else {
            "Background EV impact detection is running. Tap to pause false alarms."
        }

        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("EVSmart+ impact monitoring active")
            .setContentText(contentText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(controlPendingIntent)
            .addAction(0, "Pause", controlPendingIntent)
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val serviceChannel = NotificationChannel(
            SERVICE_CHANNEL_ID,
            "EVSmart Background Impact Service",
            NotificationManager.IMPORTANCE_LOW
        )

        val alertChannel = NotificationChannel(
            ALERT_CHANNEL_ID,
            "EVSmart Background Impact Alerts",
            NotificationManager.IMPORTANCE_HIGH
        )

        notificationManager.createNotificationChannel(serviceChannel)
        notificationManager.createNotificationChannel(alertChannel)
    }

    private fun syncImpactToFirebase(impact: PendingImpact) {
        val user = FirebaseAuth.getInstance().currentUser ?: return
        val database = FirebaseDatabase.getInstance(DATABASE_URL).reference
        val uid = user.uid

        database.child("users").child(uid).get().addOnSuccessListener { userSnapshot ->
            database.child("vehicles").child(uid).get().addOnSuccessListener { vehicleSnapshot ->
                val userData = userSnapshot.value as? Map<*, *> ?: emptyMap<String, Any>()
                val vehicleData = vehicleSnapshot.value as? Map<*, *> ?: emptyMap<String, Any>()
                val alertsRef = database.child("alerts").push()
                val alertId = alertsRef.key ?: UUID.randomUUID().toString()
                val timestampIso = isoTimestamp(impact.detectedAtMs)
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val latitude = prefs.getString(KEY_LATITUDE, "3.1390")?.toDoubleOrNull() ?: 3.1390
                val longitude = prefs.getString(KEY_LONGITUDE, "101.6869")?.toDoubleOrNull() ?: 101.6869
                val locationName = prefs.getString(KEY_LOCATION_NAME, inferLocationName(latitude, longitude))
                    ?: inferLocationName(latitude, longitude)
                val roadName = prefs.getString(KEY_ROAD_NAME, inferRoadName(locationName))
                    ?: inferRoadName(locationName)
                val driverName =
                    userData["fullName"]?.toString()
                        ?: userData["username"]?.toString()
                        ?: "EVSmart Driver"
                val vehicleLabel = vehicleLabel(userData, vehicleData)
                val emergencyTriggered = impact.level >= 4

                val alertData = hashMapOf<String, Any?>(
                    "alert_id" to alertId,
                    "user_id" to uid,
                    "vehicle_id" to (vehicleData["vehicle_id"]?.toString() ?: uid),
                    "driver" to driverName,
                    "vehicle" to vehicleLabel,
                    "impact_level" to impact.level,
                    "impact_label" to severityLabel(impact.level),
                    "type" to "auto",
                    "severity" to severityCategory(impact.level),
                    "severity_explanation" to severityExplanation(impact.level),
                    "timestamp" to timestampIso,
                    "latitude" to latitude,
                    "longitude" to longitude,
                    "location_name" to locationName,
                    "road_name" to roadName,
                    "vehicle_status" to vehicleStatusForLevel(impact.level),
                    "emergency_triggered" to emergencyTriggered,
                    "source" to "sensor",
                    "source_detail" to "android_foreground_service",
                    "title" to if (emergencyTriggered) {
                        "Emergency impact detected"
                    } else {
                        "Impact level ${impact.level} logged"
                    },
                    "status" to if (emergencyTriggered) {
                        "Awaiting hospital response"
                    } else {
                        "Logged"
                    },
                    "assigned_role" to if (emergencyTriggered) "hospital" else "technician",
                    "number_of_people" to 1,
                    "incident_description" to "${severityLabel(impact.level)} recorded. Vehicle status: ${vehicleStatusForLevel(impact.level)}",
                    "recommended_response" to recommendedResponse(impact.level),
                    "insurance_status" to "Pending review",
                    "notification_synced" to true,
                    "acceleration_magnitude" to impact.magnitude,
                    "gps_location" to "${"%.5f".format(latitude)}, ${"%.5f".format(longitude)}",
                    "impact_detected_by" to "Android foreground impact service",
                )

                alertsRef.setValue(alertData)
                database.child("accident_reports").child(alertId).setValue(alertData)

                pushNotification(
                    database = database,
                    audience = "driver",
                    userId = uid,
                    type = if (emergencyTriggered) "Alert" else "System",
                    title = alertData["title"].toString(),
                    message = if (emergencyTriggered) {
                        "Emergency Alert\nUser: $driverName\nLocation: $locationName - $roadName\nSeverity: ${severityLabel(impact.level)}"
                    } else {
                        "${severityLabel(impact.level)} recorded at $locationName and synced to EVSmart+."
                    },
                    alertId = alertId
                )

                if (emergencyTriggered) {
                    pushNotification(
                        database,
                        "hospital",
                        null,
                        "Alert",
                        "Emergency Alert",
                        "Emergency impact detected at $locationName - $roadName.",
                        alertId
                    )
                    pushNotification(
                        database,
                        "emergency_contact",
                        null,
                        "Alert",
                        "Emergency Alert",
                        "Emergency impact detected at $locationName - $roadName.",
                        alertId
                    )
                }

                pushNotification(
                    database,
                    "insurance",
                    null,
                    "Alert",
                    "Insurance analytics updated",
                    "$locationName logged with ${severityLabel(impact.level)}.",
                    alertId
                )
            }
        }
    }

    private fun pushNotification(
        database: com.google.firebase.database.DatabaseReference,
        audience: String,
        userId: String?,
        type: String,
        title: String,
        message: String,
        alertId: String
    ) {
        val ref = database.child("notifications").push()
        ref.setValue(
            hashMapOf(
                "notification_id" to ref.key,
                "alert_id" to alertId,
                "user_id" to userId,
                "audience" to audience,
                "type" to type,
                "title" to title,
                "message" to message,
                "timestamp" to isoTimestamp(System.currentTimeMillis()),
            )
        )
    }

    private fun isoTimestamp(epochMs: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return formatter.format(Date(epochMs))
    }

    private fun clockLabel(epochMs: Long): String {
        return SimpleDateFormat("h:mm a", Locale.US).format(Date(epochMs))
    }

    private fun classifyImpactLevel(magnitude: Double): Int {
        return when {
            magnitude >= 20 && magnitude < 40 -> 1
            magnitude >= 41 && magnitude < 70 -> 2
            magnitude >= 71 && magnitude < 90 -> 3
            magnitude >= 91 && magnitude < 100 -> 4
            magnitude >= 101 -> 5
            else -> 0
        }
    }

    private fun impactDescription(level: Int): String {
        return when (level) {
            1 -> "Minor vibration or bump detected."
            2 -> "Light impact detected."
            3 -> "Moderate impact detected."
            4 -> "Serious accident pattern detected."
            5 -> "Critical collision pattern detected."
            else -> "Impact trigger detected."
        }
    }

    private fun severityLabel(level: Int): String {
        return when (level) {
            1 -> "Level 1 - Minor bump"
            2 -> "Level 2 - Light impact"
            3 -> "Level 3 - Moderate impact"
            4 -> "Level 4 - Serious accident"
            5 -> "Level 5 - Critical accident"
            else -> "Unknown"
        }
    }

    private fun severityCategory(level: Int): String {
        return when {
            level >= 4 -> "high"
            level == 3 -> "medium"
            else -> "low"
        }
    }

    private fun severityExplanation(level: Int): String {
        return when (level) {
            1 -> "A small bump was recorded and should be monitored for minor exterior damage."
            2 -> "A light impact was detected. The driver should inspect the vehicle and continue with caution."
            3 -> "A moderate impact was detected. Mechanical inspection and incident review are recommended."
            4 -> "A serious accident pattern was detected and hospital response should be prepared immediately."
            5 -> "A critical accident pattern was detected. Full emergency response is strongly recommended."
            else -> "Impact severity is unavailable."
        }
    }

    private fun recommendedResponse(level: Int): String {
        return when (level) {
            1 -> "Log the bump, inspect the vehicle, and continue monitoring."
            2 -> "Inspect the driver and vehicle, then schedule technician follow-up."
            3 -> "Open the incident details, notify technician support, and review the scene."
            4 -> "Hospital users should accept the case, notify the emergency team, and dispatch immediately."
            5 -> "Dispatch emergency services, prepare trauma support, and treat the location as high priority."
            else -> "Review the incident manually."
        }
    }

    private fun vehicleStatusForLevel(level: Int): String {
        return when (level) {
            1 -> "Small bump detected. Driver should inspect vehicle body and bumper alignment."
            2 -> "Minor collision suspected. Brake, tire, and sensor checks recommended."
            3 -> "Moderate accident detected. Vehicle diagnostics and technician support required."
            4 -> "Severe accident suspected. Emergency support and ambulance dispatch initiated."
            5 -> "Critical crash pattern detected. Immediate emergency response required."
            else -> "Vehicle status unavailable."
        }
    }

    private fun inferLocationName(latitude: Double, longitude: Double): String {
        val zones = listOf(
            Triple("Shah Alam", 3.0733, 101.5185),
            Triple("Subang Jaya", 3.0738, 101.5853),
            Triple("Federal Highway", 3.0982, 101.5968),
            Triple("PLUS Highway KM 23", 3.0060, 101.4455),
            Triple("Petaling Jaya", 3.1467, 101.6151),
            Triple("Kuala Lumpur", 3.1579, 101.7123),
            Triple("Putrajaya", 2.9694, 101.7137),
            Triple("Cyberjaya", 2.9213, 101.6559),
        )

        return zones.minByOrNull {
            sqrt((it.second - latitude).pow(2.0) + (it.third - longitude).pow(2.0))
        }?.first ?: "Unknown location"
    }

    private fun inferRoadName(locationName: String): String {
        return when (locationName) {
            "Shah Alam" -> "Persiaran Kayangan"
            "Subang Jaya" -> "Subang Jaya Link"
            "Federal Highway" -> "Federal Highway"
            "PLUS Highway KM 23" -> "PLUS Highway KM 23"
            "Petaling Jaya" -> "Damansara-Puchong Expressway"
            "Kuala Lumpur" -> "Jalan Tun Razak"
            "Putrajaya" -> "Persiaran Selatan"
            "Cyberjaya" -> "Lingkaran Cyber Point"
            else -> "Unknown Road"
        }
    }

    private fun vehicleLabel(
        profile: Map<*, *>,
        vehicle: Map<*, *>
    ): String {
        val brand = vehicle["brand"]?.toString() ?: profile["brand"]?.toString() ?: ""
        val model = vehicle["model"]?.toString()
            ?: profile["vehicle_model"]?.toString()
            ?: profile["model"]?.toString()
            ?: ""
        val plate = vehicle["plate"]?.toString()
            ?: profile["vehicle_plate"]?.toString()
            ?: profile["plate"]?.toString()
            ?: ""
        val label = "$brand $model".trim()
        return when {
            plate.isNotEmpty() && label.isNotEmpty() -> "$label ($plate)"
            label.isNotEmpty() -> label
            else -> "EV Vehicle"
        }
    }

    data class PendingImpact(
        val level: Int,
        val magnitude: Double,
        val detectedAtMs: Long,
        val description: String
    )
}
