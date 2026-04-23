package com.evsmart.plus.evsmart_plus

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

class ImpactAlertActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var secondsLeft = 5
    private lateinit var countdownText: TextView
    private lateinit var progressBar: ProgressBar

    private val countdownRunnable = object : Runnable {
        override fun run() {
            secondsLeft -= 1
            updateCountdown()
            if (secondsLeft <= 0) {
                finish()
                return
            }
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        secondsLeft = intent.getIntExtra("countdown_seconds", 5)
        setContentView(buildContent())
        updateCountdown()
        handler.postDelayed(countdownRunnable, 1000)
    }

    override fun onDestroy() {
        handler.removeCallbacks(countdownRunnable)
        super.onDestroy()
    }

    private fun buildContent(): View {
        val level = intent.getIntExtra("impact_level", 1)
        val description = intent.getStringExtra("impact_description")
            ?: "A bump or impact was detected from the phone accelerometer."

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(24), dp(28), dp(24))
            setBackgroundColor(Color.argb(190, 0, 0, 0))
        }

        val cardBackground = GradientDrawable().apply {
            setColor(Color.rgb(247, 248, 240))
            cornerRadius = dp(28).toFloat()
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(28), dp(28), dp(28), dp(24))
            background = cardBackground
            elevation = dp(12).toFloat()
        }

        root.addView(
            card,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        card.addView(
            text(
                value = "Potential accident detected. Cancel if safe.",
                sizeSp = 27f,
                color = Color.rgb(35, 38, 35),
                typeface = Typeface.DEFAULT_BOLD
            )
        )

        card.addView(spacer(22))

        card.addView(
            text(
                value = "Level $level - $description",
                sizeSp = 16f,
                color = Color.rgb(38, 42, 39),
                lineSpacing = 4f
            )
        )

        card.addView(spacer(22))

        countdownText = text(
            value = "",
            sizeSp = 18f,
            color = Color.rgb(28, 31, 28),
            typeface = Typeface.DEFAULT_BOLD
        )
        card.addView(countdownText)

        card.addView(spacer(16))

        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = secondsLeft.coerceAtLeast(1)
            progress = secondsLeft
            progressDrawable.setTint(Color.rgb(46, 125, 50))
        }
        card.addView(
            progressBar,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(8)
            )
        )

        card.addView(spacer(18))

        card.addView(
            text(
                value = "This simulates vehicle IoT impact sensors using the phone accelerometer.",
                sizeSp = 14f,
                color = Color.rgb(100, 104, 99),
                gravity = Gravity.CENTER,
                lineSpacing = 4f
            )
        )

        card.addView(spacer(34))

        val cancelButton = text(
            value = "Cancel",
            sizeSp = 16f,
            color = Color.rgb(46, 125, 50),
            typeface = Typeface.DEFAULT_BOLD,
            gravity = Gravity.CENTER
        ).apply {
            setPadding(dp(18), dp(12), dp(18), dp(12))
            setOnClickListener {
                val cancelIntent = Intent(
                    this@ImpactAlertActivity,
                    ImpactForegroundService::class.java
                ).apply {
                    action = ImpactForegroundService.ACTION_CANCEL_PENDING
                }
                startService(cancelIntent)
                finish()
            }
        }

        val cancelParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.END
        }
        card.addView(cancelButton, cancelParams)

        return root
    }

    private fun updateCountdown() {
        countdownText.text = "This alert will be saved in $secondsLeft seconds."
        progressBar.progress = secondsLeft.coerceAtLeast(0)
    }

    private fun text(
        value: String,
        sizeSp: Float,
        color: Int,
        typeface: Typeface = Typeface.DEFAULT,
        gravity: Int = Gravity.START,
        lineSpacing: Float = 0f
    ): TextView {
        return TextView(this).apply {
            text = value
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
            setTypeface(typeface)
            this.gravity = gravity
            setLineSpacing(lineSpacing, 1.0f)
        }
    }

    private fun spacer(heightDp: Int): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(heightDp)
            )
        }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
