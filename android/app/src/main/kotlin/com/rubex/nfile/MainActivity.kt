package com.rubex.nfile

import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.StatFs
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
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
                "getStorageSpace" -> {
                    executor.execute {
                        try {
                            val path = Environment.getExternalStorageDirectory().path
                            val stat = StatFs(path)
                            val blockSize = stat.blockSizeLong
                            val totalBlocks = stat.blockCountLong
                            val availableBlocks = stat.availableBlocksLong

                            val totalBytes = totalBlocks * blockSize
                            val availableBytes = availableBlocks * blockSize
                            val usedBytes = totalBytes - availableBytes

                            val res = mapOf(
                                "totalBytes" to totalBytes,
                                "availableBytes" to availableBytes,
                                "usedBytes" to usedBytes
                            )
                            runOnUiThread { result.success(res) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("STORAGE_ERROR", e.message, null) }
                        }
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
                "resolveContentUri" -> {
                    val uriString = call.argument<String>("uri") ?: ""
                    executor.execute {
                        try {
                            val uri = Uri.parse(uriString)
                            val contentResolver = context.contentResolver
                            
                            var fileName = "temp_file"
                            var mimeType = contentResolver.getType(uri) ?: ""
                            
                            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                if (nameIndex != -1 && cursor.moveToFirst()) {
                                    fileName = cursor.getString(nameIndex)
                                }
                            }

                            if (mimeType.isEmpty()) {
                                val ext = MimeTypeMap.getFileExtensionFromUrl(uriString)
                                if (ext != null) {
                                    mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: ""
                                }
                            }

                            val cacheDir = context.cacheDir
                            val prefix = "incoming_" + System.currentTimeMillis() + "_"
                            val ext = if (fileName.contains(".")) {
                                "." + fileName.substringAfterLast(".")
                            } else {
                                ""
                            }
                            
                            val tempFile = File.createTempFile(prefix, ext, cacheDir)
                            
                            contentResolver.openInputStream(uri)?.use { inputStream ->
                                FileOutputStream(tempFile).use { outputStream ->
                                    inputStream.copyTo(outputStream)
                                }
                            }

                            val res = mapOf(
                                "success" to true,
                                "cachePath" to tempFile.absolutePath,
                                "fileName" to fileName,
                                "mimeType" to mimeType
                            )
                            runOnUiThread { result.success(res) }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            runOnUiThread { result.error("RESOLVE_ERROR", e.message, null) }
                        }
                    }
                }
                "writeContentUri" -> {
                    val uriString = call.argument<String>("uri") ?: ""
                    val content = call.argument<String>("content") ?: ""
                    executor.execute {
                        try {
                            val uri = Uri.parse(uriString)
                            val contentResolver = context.contentResolver
                            
                            contentResolver.openOutputStream(uri, "w")?.use { outputStream ->
                                outputStream.write(content.toByteArray(Charsets.UTF_8))
                            }

                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            runOnUiThread { result.error("WRITE_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rubex.nfile/ftp_service").setMethodCallHandler { call, result ->
            when (call.method) {
                "startFtpService" -> {
                    val ip = call.argument<String>("ip") ?: "127.0.0.1"
                    val port = call.argument<Int>("port") ?: 9999
                    try {
                        val intent = Intent(this, FtpForegroundService::class.java).apply {
                            putExtra("ip", ip)
                            putExtra("port", port)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopFtpService" -> {
                    try {
                        val intent = Intent(this, FtpForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rubex.nfile/web_sharing_service").setMethodCallHandler { call, result ->
            when (call.method) {
                "startWebSharingService" -> {
                    val url = call.argument<String>("url") ?: "http://127.0.0.1:8080"
                    val isInternet = call.argument<Boolean>("isInternet") ?: false
                    try {
                        val intent = Intent(this, WebSharingForegroundService::class.java).apply {
                            putExtra("url", url)
                            putExtra("isInternet", isInternet)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopWebSharingService" -> {
                    try {
                        val intent = Intent(this, WebSharingForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
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
