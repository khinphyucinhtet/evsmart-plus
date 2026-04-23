package com.evsmart.plus.evsmart_plus

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {

    private val voiceChannel = "voice_channel"
    private val backgroundImpactChannel = "evsmart/background_impact"
    private val voiceReq = 100
    private var resultCallback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, voiceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVoice" -> {
                        try {
                            resultCallback = result

                            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                            intent.putExtra(
                                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                            )
                            intent.putExtra(
                                RecognizerIntent.EXTRA_LANGUAGE,
                                Locale.getDefault()
                            )
                            intent.putExtra(
                                RecognizerIntent.EXTRA_PROMPT,
                                "Say command..."
                            )

                            startActivityForResult(intent, voiceReq)
                        } catch (e: Exception) {
                            result.error("VOICE_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backgroundImpactChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        getSharedPreferences(
                            ImpactForegroundService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        ).edit()
                            .remove(ImpactForegroundService.KEY_SNOOZED_UNTIL_MS)
                            .apply()

                        val intent = Intent(this, ImpactForegroundService::class.java).apply {
                            action = ImpactForegroundService.ACTION_START
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    }

                    "stopService" -> {
                        val intent = Intent(this, ImpactForegroundService::class.java).apply {
                            action = ImpactForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }

                    "updateContext" -> {
                        val prefs = getSharedPreferences(
                            ImpactForegroundService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        val latitude = call.argument<Double>("latitude") ?: 0.0
                        val longitude = call.argument<Double>("longitude") ?: 0.0
                        val locationName = call.argument<String>("location_name") ?: "Unknown location"
                        val roadName = call.argument<String>("road_name") ?: "Unknown road"

                        prefs.edit()
                            .putString(ImpactForegroundService.KEY_LATITUDE, latitude.toString())
                            .putString(ImpactForegroundService.KEY_LONGITUDE, longitude.toString())
                            .putString(ImpactForegroundService.KEY_LOCATION_NAME, locationName)
                            .putString(ImpactForegroundService.KEY_ROAD_NAME, roadName)
                            .apply()

                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == voiceReq) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val matches = data.getStringArrayListExtra(
                    RecognizerIntent.EXTRA_RESULTS
                )

                if (!matches.isNullOrEmpty()) {
                    resultCallback?.success(matches[0])
                } else {
                    resultCallback?.success("")
                }
            } else {
                resultCallback?.success("")
            }
        }
    }
}
