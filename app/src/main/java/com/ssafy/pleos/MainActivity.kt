package com.ssafy.pleos

import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import ai.pleos.playground.vehicle.Vehicle
import ai.pleos.playground.vehicle.api.model.area.DoorArea
import ai.pleos.playground.vehicle.constant.area.DoorValue

class MainActivity : Activity() {
    private var vehicle: Vehicle? = null
    private lateinit var status: TextView
    private lateinit var readButton: Button
    private val handler = Handler(Looper.getMainLooper())
    private var requestId = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(48), dp(32), dp(48), dp(32))
            setBackgroundColor(Color.rgb(18, 25, 36))
        }
        fun text(value: String, size: Float): TextView = TextView(this).apply {
            text = value
            textSize = size
            setTextColor(Color.WHITE)
            setPadding(0, dp(8), 0, dp(8))
            layout.addView(this)
        }
        text(getString(R.string.app_name), 32f)
        text(getString(R.string.subtitle), 20f)
        text(getString(R.string.device_info, Build.MODEL, Build.VERSION.SDK_INT), 16f)
        status = text(getString(R.string.ready), 20f).apply {
            accessibilityLiveRegion = android.view.View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        readButton = Button(this).apply {
            text = getString(R.string.read_door)
            minHeight = dp(64)
            setOnClickListener { requestDoor() }
            layout.addView(this, LinearLayout.LayoutParams(dp(360), dp(72)))
        }
        setContentView(ScrollView(this).apply {
            isFillViewport = true
            addView(layout)
        })
    }

    private fun requestDoor() {
        if (checkSelfPermission(DOOR_PERMISSION) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(DOOR_PERMISSION), PERMISSION_REQUEST)
        } else {
            readDoor()
        }
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == PERMISSION_REQUEST) {
            if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) readDoor()
            else status.text = getString(R.string.permission_denied)
        }
    }

    private fun readDoor() {
        val id = ++requestId
        readButton.isEnabled = false
        status.text = getString(R.string.reading)
        val timeout = Runnable {
            complete(id, getString(R.string.timeout))
        }
        handler.postDelayed(timeout, 10_000)
        try {
            val sdk = vehicle ?: Vehicle(this).also {
                vehicle = it
                it.initialize()
            }
            sdk.getDoor().getCurrentDoorPosition(
                area = DoorArea(DoorValue.ROW_1_LEFT),
                onComplete = { position: Int? ->
                    runOnUiThread {
                        handler.removeCallbacks(timeout)
                        complete(id, position?.let { getString(R.string.door_position, it) }
                            ?: getString(R.string.no_value))
                    }
                },
                onFailed = { error: Exception ->
                    Log.e(TAG, "Vehicle door read failed", error)
                    runOnUiThread {
                        handler.removeCallbacks(timeout)
                        complete(id, getString(R.string.sdk_error, error.message ?: error.javaClass.simpleName))
                    }
                }
            )
        } catch (error: Exception) {
            Log.e(TAG, "Vehicle SDK initialization/read failed", error)
            handler.removeCallbacks(timeout)
            complete(id, getString(R.string.sdk_error, error.message ?: error.javaClass.simpleName))
        }
    }

    private fun complete(id: Int, message: String) {
        if (isDestroyed || id != requestId) return
        ++requestId // Ignore callbacks arriving after completion or timeout.
        status.text = message
        readButton.isEnabled = true
    }

    override fun onDestroy() {
        ++requestId
        handler.removeCallbacksAndMessages(null)
        try {
            vehicle?.release()
        } catch (error: Exception) {
            Log.e(TAG, "Vehicle SDK release failed", error)
        }
        vehicle = null
        super.onDestroy()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val TAG = "PleosStarter"
        private const val DOOR_PERMISSION = "pleos.car.permission.CAR_DOORS"
        private const val PERMISSION_REQUEST = 100
    }
}
