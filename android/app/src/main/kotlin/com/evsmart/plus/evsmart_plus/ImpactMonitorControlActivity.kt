package com.evsmart.plus.evsmart_plus

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

class ImpactMonitorControlActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        setContentView(buildContent())
    }

    private fun buildContent(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(26), dp(24), dp(26), dp(24))
            setBackgroundColor(Color.argb(155, 0, 0, 0))
        }

        val cardBackground = GradientDrawable().apply {
            setColor(Color.rgb(247, 248, 240))
            cornerRadius = dp(26).toFloat()
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(24), dp(24), dp(22))
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
                value = "Pause background impact monitoring?",
                sizeSp = 23f,
                color = Color.rgb(35, 38, 35),
                typeface = Typeface.DEFAULT_BOLD
            )
        )
        card.addView(spacer(12))
        card.addView(
            text(
                value = "Use this when normal phone movement is causing false Level 1 alerts. Monitoring can be resumed anytime.",
                sizeSp = 15f,
                color = Color.rgb(90, 96, 90),
                lineSpacing = 4f
            )
        )
        card.addView(spacer(20))

        addOption(card, "Pause 1 hour", 60)
        addOption(card, "Pause 5 hours", 300)
        addOption(card, "Pause 8 hours", 480)
        addOption(card, "Pause 10 hours", 600)
        addOption(card, "Until I turn it back on", -1)
        addOption(card, "Turn monitoring back on", 0)

        card.addView(spacer(8))
        card.addView(
            text(
                value = "Cancel",
                sizeSp = 16f,
                color = Color.rgb(46, 125, 50),
                typeface = Typeface.DEFAULT_BOLD,
                gravity = Gravity.CENTER
            ).apply {
                setPadding(dp(12), dp(12), dp(12), dp(12))
                setOnClickListener { finish() }
            }
        )

        return root
    }

    private fun addOption(parent: LinearLayout, label: String, minutes: Int) {
        val background = GradientDrawable().apply {
            setColor(Color.WHITE)
            setStroke(dp(1), Color.rgb(218, 226, 215))
            cornerRadius = dp(16).toFloat()
        }
        val option = text(
            value = label,
            sizeSp = 16f,
            color = Color.rgb(35, 75, 38),
            typeface = Typeface.DEFAULT_BOLD,
            gravity = Gravity.CENTER
        ).apply {
            setPadding(dp(14), dp(14), dp(14), dp(14))
            this.background = background
            setOnClickListener {
                val intent = Intent(
                    this@ImpactMonitorControlActivity,
                    ImpactForegroundService::class.java
                ).apply {
                    action = ImpactForegroundService.ACTION_SNOOZE
                    putExtra(ImpactForegroundService.EXTRA_SNOOZE_MINUTES, minutes)
                }
                startService(intent)
                finish()
            }
        }
        val params = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = dp(10)
        }
        parent.addView(option, params)
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
