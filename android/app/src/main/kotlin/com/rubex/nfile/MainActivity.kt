package com.rubex.nfile

import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rubex.nfile/root_shizuku"
    private val SHIZUKU_REQUEST_CODE = 10001
    private val executor = Executors.newCachedThreadPool()
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val onRequestPermissionResultListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode == SHIZUKU_REQUEST_CODE) {
            val granted = grantResult == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            Shizuku.addBinderReceivedListenerSticky {
                // Binder ready
            }
            Shizuku.addRequestPermissionResultListener(onRequestPermissionResultListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        try {
            Shizuku.removeRequestPermissionResultListener(onRequestPermissionResultListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkStatus" -> {
                    executor.execute {
                        val isRootAvailable = checkRootAvailable()
                        var isShizukuAvailable = false
                        var shizukuPermissionGranted = false

                        try {
                            if (!Shizuku.pingBinder()) {
                                try {
                                    rikka.shizuku.ShizukuProvider.requestBinderForNonProviderProcess(this)
                                } catch (e: Throwable) {}
                            }
                            isShizukuAvailable = Shizuku.pingBinder()
                            if (isShizukuAvailable) {
                                shizukuPermissionGranted = Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                            }
                        } catch (e: Throwable) {
                            // Shizuku not installed or unavailable
                        }

                        val res = mapOf(
                            "isRootAvailable" to isRootAvailable,
                            "isShizukuAvailable" to isShizukuAvailable,
                            "shizukuPermissionGranted" to shizukuPermissionGranted
                        )
                        runOnUiThread { result.success(res) }
                    }
                }
                "requestShizukuPermission" -> {
                    try {
                        if (!Shizuku.pingBinder()) {
                            try {
                                rikka.shizuku.ShizukuProvider.requestBinderForNonProviderProcess(this)
                            } catch (e: Throwable) {}
                        }
                        if (Shizuku.pingBinder()) {
                            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                                result.success(true)
                            } else {
                                pendingPermissionResult = result
                                Shizuku.requestPermission(SHIZUKU_REQUEST_CODE)
                            }
                        } else {
                            pendingPermissionResult = result
                            Shizuku.requestPermission(SHIZUKU_REQUEST_CODE)
                        }
                    } catch (e: Throwable) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "runCommand" -> {
                    val command = call.argument<String>("command") ?: ""
                    val useRoot = call.argument<Boolean>("useRoot") ?: false

                    executor.execute {
                        try {
                            val output = runShellCommand(command, useRoot)
                            runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("EXEC_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkRootAvailable(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
            val exitCode = process.waitFor()
            exitCode == 0
        } catch (e: Exception) {
            false
        }
    }

    private fun runShellCommand(command: String, useRoot: Boolean): String {
        val process: Process = if (useRoot) {
            Runtime.getRuntime().exec(arrayOf("su", "-c", command))
        } else {
            val method = Shizuku::class.java.getDeclaredMethod("newProcess", Array<String>::class.java, Array<String>::class.java, String::class.java)
            method.isAccessible = true
            method.invoke(null, arrayOf("sh", "-c", command), null, null) as Process
        }

        val reader = BufferedReader(InputStreamReader(process.inputStream))
        val errReader = BufferedReader(InputStreamReader(process.errorStream))

        val output = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            output.append(line).append("\n")
        }

        val errOutput = StringBuilder()
        while (errReader.readLine().also { line = it } != null) {
            errOutput.append(line).append("\n")
        }

        val exitCode = process.waitFor()
        if (exitCode != 0 && output.isEmpty() && errOutput.isNotEmpty()) {
            throw Exception(errOutput.toString().trim())
        }
        return output.toString()
    }
}
