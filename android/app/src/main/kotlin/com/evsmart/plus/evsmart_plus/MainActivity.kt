package com.evsmart.plus.evsmart_plus

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "voice_channel"
    private val VOICE_REQ = 100
    private var resultCallback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    // 🎤 Start Voice Recognition
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

                            startActivityForResult(intent, VOICE_REQ)

                        } catch (e: Exception) {
                            result.error("VOICE_ERROR", e.message, null)
                        }
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

        if (requestCode == VOICE_REQ) {

            if (resultCode == Activity.RESULT_OK && data != null) {

                val matches =
                    data.getStringArrayListExtra(
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