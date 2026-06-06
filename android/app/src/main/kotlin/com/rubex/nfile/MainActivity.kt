package com.rubex.nfile

import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInstaller
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.StatFs
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import android.provider.DocumentsContract
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import androidx.core.app.NotificationCompat
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.app.usage.StorageStatsManager
import android.app.AppOpsManager
import android.os.storage.StorageManager
import android.os.Process

class MainActivity : AudioServiceFragmentActivity() {
    private val CHANNEL = "com.rubex.nfile/root_shizuku"
    private val SHIZUKU_REQUEST_CODE = 10001
    private val executor = Executors.newCachedThreadPool()
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var safPermissionResult: MethodChannel.Result? = null
    private val SAF_REQUEST_CODE = 10002

    private val ACTION_CANCEL_OPERATION = "com.rubex.nfile.ACTION_CANCEL_OPERATION"
    private var notificationsChannel: MethodChannel? = null

    private val cancelReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_CANCEL_OPERATION) {
                notificationsChannel?.invokeMethod("cancelOperationFromNotification", null)
            }
        }
    }

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

        try {
            val filter = IntentFilter(ACTION_CANCEL_OPERATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(cancelReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(cancelReceiver, filter)
            }
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
        try {
            unregisterReceiver(cancelReceiver)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SAF_REQUEST_CODE) {
            val result = safPermissionResult
            safPermissionResult = null
            if (resultCode == RESULT_OK && data != null) {
                val treeUri = data.data
                if (treeUri != null) {
                    try {
                        val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        contentResolver.takePersistableUriPermission(treeUri, takeFlags)
                        
                        var name = "SAF Drive"
                        val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, DocumentsContract.getTreeDocumentId(treeUri))
                        contentResolver.query(docUri, null, null, null, null)?.use { cursor ->
                            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                            if (nameIndex != -1 && cursor.moveToFirst()) {
                                name = cursor.getString(nameIndex)
                            }
                        }

                        result?.success(mapOf(
                            "uri" to treeUri.toString(),
                            "name" to name
                        ))
                    } catch (e: Exception) {
                        result?.error("PERMISSION_ERROR", e.message, null)
                    }
                } else {
                    result?.success(null)
                }
            } else {
                result?.success(null)
            }
        }
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
                    val pathArg = call.argument<String>("path")
                    executor.execute {
                        try {
                            val path = pathArg ?: Environment.getExternalStorageDirectory().path
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
                            val contentResolver = applicationContext.contentResolver
                            
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

                            val cacheDir = applicationContext.cacheDir
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
                            val contentResolver = applicationContext.contentResolver
                            
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
                "getInstalledApps" -> {
                    val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                    executor.execute {
                        try {
                            val apps = getInstalledApps(includeSystem)
                            runOnUiThread { result.success(apps) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("APP_LIST_ERROR", e.message, null) }
                        }
                    }
                }
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    executor.execute {
                        try {
                            val bytes = getAppIcon(packageName)
                            runOnUiThread { result.success(bytes) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("ICON_ERROR", e.message, null) }
                        }
                    }
                }
                "getApkIcon" -> {
                    val apkPath = call.argument<String>("apkPath") ?: ""
                    executor.execute {
                        try {
                            val bytes = getApkIcon(apkPath)
                            runOnUiThread { result.success(bytes) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("ICON_ERROR", e.message, null) }
                        }
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    executor.execute {
                        try {
                            val pm = packageManager
                            val intent = pm.getLaunchIntentForPackage(packageName)
                            if (intent != null) {
                                startActivity(intent)
                                runOnUiThread { result.success(true) }
                            } else {
                                runOnUiThread { result.error("LAUNCH_ERROR", "Launch intent not found", null) }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("LAUNCH_ERROR", e.message, null) }
                        }
                    }
                }
                "openAppDetails" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    executor.execute {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DETAILS_ERROR", e.message, null) }
                        }
                    }
                }
                "uninstallApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    executor.execute {
                        try {
                            val intent = Intent(Intent.ACTION_DELETE).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("UNINSTALL_ERROR", e.message, null) }
                        }
                    }
                }
                "installSplitApks" -> {
                    val apkPaths = call.argument<List<String>>("apkPaths") ?: emptyList()
                    installSplitApks(apkPaths, result)
                }
                "checkUsageStatsPermission" -> {
                    val granted = isUsageStatsPermissionGranted()
                    result.success(granted)
                }
                "requestUsageStatsPermission" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", e.message, null)
                    }
                }
                "changeAppIcon" -> {
                    val iconAlias = call.argument<String>("alias") ?: "com.rubex.nfile.MainActivityDefault"
                    executor.execute {
                        try {
                            val aliases = listOf(
                                "com.rubex.nfile.MainActivityDefault",
                                "com.rubex.nfile.MainActivityLogo1",
                                "com.rubex.nfile.MainActivityLogo2",
                                "com.rubex.nfile.MainActivityLogo3",
                                "com.rubex.nfile.MainActivityLogo4"
                            )

                            for (alias in aliases) {
                                val componentName = android.content.ComponentName(packageName, alias)
                                val state = if (alias == iconAlias) {
                                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                } else {
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                                }
                                packageManager.setComponentEnabledSetting(
                                    componentName,
                                    state,
                                    PackageManager.DONT_KILL_APP
                                )
                            }
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("ICON_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rubex.nfile/saf").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSafDirectory" -> {
                    safPermissionResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                        startActivityForResult(intent, SAF_REQUEST_CODE)
                    } catch (e: Exception) {
                        safPermissionResult = null
                        result.error("ACTIVITY_NOT_FOUND", "No application found to handle folder selection: ${e.message}", null)
                    }
                }
                "listDirectory" -> {
                    val rootUriStr = call.argument<String>("rootUri") ?: ""
                    val pathUriStr = call.argument<String>("pathUri") ?: ""
                    executor.execute {
                        try {
                            val rootUri = Uri.parse(rootUriStr)
                            val targetDocId = if (pathUriStr.isNotEmpty()) {
                                DocumentsContract.getDocumentId(Uri.parse(pathUriStr))
                            } else {
                                DocumentsContract.getTreeDocumentId(rootUri)
                            }
                            
                            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(rootUri, targetDocId)
                            val resultList = mutableListOf<Map<String, Any>>()
                            
                            contentResolver.query(childrenUri, null, null, null, null)?.use { cursor ->
                                val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                                val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                                val mimeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                                val sizeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                                val dateIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                                
                                while (cursor.moveToNext()) {
                                    val childDocId = if (idIndex != -1) cursor.getString(idIndex) else ""
                                    val childName = if (nameIndex != -1) cursor.getString(nameIndex) else "unnamed"
                                    val mimeType = if (mimeIndex != -1) cursor.getString(mimeIndex) else ""
                                    val size = if (sizeIndex != -1) cursor.getLong(sizeIndex) else 0L
                                    val modified = if (dateIndex != -1) cursor.getLong(dateIndex) else 0L
                                    
                                    val childUri = DocumentsContract.buildDocumentUriUsingTree(rootUri, childDocId)
                                    val isDir = mimeType == DocumentsContract.Document.MIME_TYPE_DIR
                                    
                                    resultList.add(mapOf(
                                        "name" to childName,
                                        "path" to childUri.toString(),
                                        "isDirectory" to isDir,
                                        "size" to size,
                                        "modified" to modified
                                    ))
                                }
                            }
                            runOnUiThread { result.success(resultList) }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            runOnUiThread { result.error("LIST_ERROR", e.message, null) }
                        }
                    }
                }
                "createDirectory" -> {
                    val rootUriStr = call.argument<String>("rootUri") ?: ""
                    val parentUriStr = call.argument<String>("parentUri") ?: ""
                    val name = call.argument<String>("name") ?: "New Folder"
                    executor.execute {
                        try {
                            val rootUri = Uri.parse(rootUriStr)
                            val parentDocId = if (parentUriStr.isNotEmpty()) {
                                DocumentsContract.getDocumentId(Uri.parse(parentUriStr))
                            } else {
                                DocumentsContract.getTreeDocumentId(rootUri)
                            }
                            val parentUri = DocumentsContract.buildDocumentUriUsingTree(rootUri, parentDocId)
                            val newUri = DocumentsContract.createDocument(
                                contentResolver,
                                parentUri,
                                DocumentsContract.Document.MIME_TYPE_DIR,
                                name
                            )
                            runOnUiThread { result.success(newUri?.toString()) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("CREATE_ERROR", e.message, null) }
                        }
                    }
                }
                "delete" -> {
                    val rootUriStr = call.argument<String>("rootUri") ?: ""
                    val uriStr = call.argument<String>("uri") ?: ""
                    executor.execute {
                        try {
                            val rootUri = Uri.parse(rootUriStr)
                            val docId = DocumentsContract.getDocumentId(Uri.parse(uriStr))
                            val docUri = DocumentsContract.buildDocumentUriUsingTree(rootUri, docId)
                            val deleted = DocumentsContract.deleteDocument(contentResolver, docUri)
                            runOnUiThread { result.success(deleted) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DELETE_ERROR", e.message, null) }
                        }
                    }
                }
                "downloadFile" -> {
                    val rootUriStr = call.argument<String>("rootUri") ?: ""
                    val uriStr = call.argument<String>("uri") ?: ""
                    val localPath = call.argument<String>("localPath") ?: ""
                    executor.execute {
                        try {
                            val rootUri = Uri.parse(rootUriStr)
                            val docId = DocumentsContract.getDocumentId(Uri.parse(uriStr))
                            val docUri = DocumentsContract.buildDocumentUriUsingTree(rootUri, docId)
                            
                            val file = File(localPath)
                            file.parentFile?.mkdirs()
                            
                            contentResolver.openInputStream(docUri)?.use { inputStream ->
                                FileOutputStream(file).use { outputStream ->
                                    inputStream.copyTo(outputStream)
                                }
                            }
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DOWNLOAD_ERROR", e.message, null) }
                        }
                    }
                }
                "uploadFile" -> {
                    val rootUriStr = call.argument<String>("rootUri") ?: ""
                    val parentUriStr = call.argument<String>("parentUri") ?: ""
                    val localPath = call.argument<String>("localPath") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "file"
                    executor.execute {
                        try {
                            val rootUri = Uri.parse(rootUriStr)
                            val parentDocId = if (parentUriStr.isNotEmpty()) {
                                DocumentsContract.getDocumentId(Uri.parse(parentUriStr))
                            } else {
                                DocumentsContract.getTreeDocumentId(rootUri)
                            }
                            val parentUri = DocumentsContract.buildDocumentUriUsingTree(rootUri, parentDocId)
                            
                            val ext = fileName.substringAfterLast(".", "")
                            val mimeType = if (ext.isNotEmpty()) {
                                MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase()) ?: "application/octet-stream"
                            } else {
                                "application/octet-stream"
                            }
                            
                            val docUri = DocumentsContract.createDocument(
                                contentResolver,
                                parentUri,
                                mimeType,
                                fileName
                            )
                            
                            if (docUri != null) {
                                val file = File(localPath)
                                contentResolver.openOutputStream(docUri)?.use { outputStream ->
                                    file.inputStream().use { inputStream ->
                                        inputStream.copyTo(outputStream)
                                    }
                                }
                                runOnUiThread { result.success(true) }
                            } else {
                                runOnUiThread { result.error("UPLOAD_ERROR", "Failed to create document in tree", null) }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("UPLOAD_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rubex.nfile/gesture_exclusion").setMethodCallHandler { call, result ->
            if (call.method == "setSystemGestureExclusionRects") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val rectsArg = call.argument<List<Map<String, Int>>>("rects")
                    val exclusionRects = mutableListOf<android.graphics.Rect>()
                    if (rectsArg != null) {
                        for (r in rectsArg) {
                            val left = r["left"] ?: 0
                            val top = r["top"] ?: 0
                            val right = r["right"] ?: 0
                            val bottom = r["bottom"] ?: 0
                            exclusionRects.add(android.graphics.Rect(left, top, right, bottom))
                        }
                    }
                    runOnUiThread {
                        try {
                            window.decorView.systemGestureExclusionRects = exclusionRects
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                } else {
                    result.success(false)
                }
            } else {
                result.notImplemented()
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

        notificationsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rubex.nfile/notifications")
        notificationsChannel?.setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "nfile_archive_channel"
            val channelName = "NFile Archive Operations"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shows progress of file compression and extraction"
                }
                notificationManager.createNotificationChannel(channel)
            }

            when (call.method) {
                "showProgressNotification" -> {
                    val id = call.argument<Int>("id") ?: 100
                    val title = call.argument<String>("title") ?: "Processing..."
                    val message = call.argument<String>("message") ?: ""
                    val progress = call.argument<Int>("progress") ?: 0
                    val max = call.argument<Int>("max") ?: 100
                    val indeterminate = call.argument<Boolean>("indeterminate") ?: false

                    var iconId = applicationContext.resources.getIdentifier("ic_launcher", "mipmap", packageName)
                    if (iconId == 0) {
                        iconId = android.R.drawable.ic_dialog_info
                    }

                    val cancelIntent = Intent(ACTION_CANCEL_OPERATION).apply {
                        setPackage(packageName)
                    }
                    val cancelPendingIntent = PendingIntent.getBroadcast(
                        this@MainActivity,
                        id,
                        cancelIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                    )

                    val openIntent = Intent(this@MainActivity, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val openPendingIntent = PendingIntent.getActivity(
                        this@MainActivity,
                        0,
                        openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                    )

                    val builder = NotificationCompat.Builder(this@MainActivity, channelId)
                        .setContentTitle(title)
                        .setContentText(message)
                        .setSmallIcon(iconId)
                        .setOngoing(progress < max)
                        .setAutoCancel(progress >= max)
                        .setContentIntent(openPendingIntent)

                    if (progress < max) {
                        builder.addAction(android.R.drawable.ic_menu_view, "Open", openPendingIntent)
                        builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", cancelPendingIntent)
                    }

                    if (indeterminate) {
                        builder.setProgress(0, 0, true)
                    } else {
                        builder.setProgress(max, progress, false)
                    }

                    notificationManager.notify(id, builder.build())
                    result.success(true)
                }
                "cancelNotification" -> {
                    val id = call.argument<Int>("id") ?: 100
                    notificationManager.cancel(id)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installSplitApks(apkPaths: List<String>, result: MethodChannel.Result) {
        executor.execute {
            try {
                val pm = packageManager
                val packageInstaller = pm.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                
                val sessionId = packageInstaller.createSession(params)
                val session = packageInstaller.openSession(sessionId)
                
                for (path in apkPaths) {
                    val file = File(path)
                    if (!file.exists()) continue
                    val name = file.name
                    val size = file.length()
                    
                    val out = session.openWrite(name, 0, size)
                    file.inputStream().use { input ->
                        input.copyTo(out)
                    }
                    session.fsync(out)
                    out.close()
                }
                
                // Create a status intent
                val intent = Intent("com.rubex.nfile.INSTALL_STATUS")
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getBroadcast(this, sessionId, intent, flags)
                
                session.commit(pendingIntent.intentSender)
                session.close()
                
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                e.printStackTrace()
                runOnUiThread { result.error("INSTALL_ERROR", e.message, null) }
            }
        }
    }

    private fun getInstalledApps(includeSystem: Boolean): List<Map<String, Any>> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val resultList = mutableListOf<Map<String, Any>>()
        
        val hasUsageStats = isUsageStatsPermissionGranted()
        var storageStatsManager: StorageStatsManager? = null
        var storageUuid: java.util.UUID? = null
        var user: android.os.UserHandle? = null

        if (hasUsageStats && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                storageStatsManager = getSystemService(Context.STORAGE_STATS_SERVICE) as? StorageStatsManager
                storageUuid = StorageManager.UUID_DEFAULT
                user = Process.myUserHandle()
            } catch (e: Exception) {}
        }

        for (appInfo in apps) {
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (!includeSystem && isSystem) {
                continue
            }
            
            val packageName = appInfo.packageName
            val apkFile = File(appInfo.sourceDir)
            val apkSize = if (apkFile.exists()) apkFile.length() else 0L
            
            var totalSize = apkSize
            if (storageStatsManager != null && storageUuid != null && user != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    val stats = storageStatsManager.queryStatsForPackage(storageUuid, packageName, user)
                    totalSize = stats.appBytes + stats.dataBytes + stats.cacheBytes
                } catch (e: Exception) {}
            }
            
            val appName = appInfo.loadLabel(pm).toString()
            
            var versionName = ""
            var installTime = 0L
            try {
                val pkgInfo = pm.getPackageInfo(packageName, 0)
                versionName = pkgInfo.versionName ?: ""
                installTime = pkgInfo.firstInstallTime
            } catch (e: Exception) {}

            val splitDirs = appInfo.splitSourceDirs?.toList() ?: emptyList<String>()
            val appMap = mapOf(
                "name" to appName,
                "packageName" to packageName,
                "version" to versionName,
                "apkSize" to totalSize,
                "isSystem" to isSystem,
                "installTime" to installTime,
                "sourceDir" to appInfo.sourceDir,
                "splitSourceDirs" to splitDirs
            )
            resultList.add(appMap)
        }
        return resultList
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val pm = packageManager
            val iconDrawable = pm.getApplicationIcon(packageName)
            val bitmap = when (iconDrawable) {
                is BitmapDrawable -> iconDrawable.bitmap
                else -> {
                    val width = iconDrawable.intrinsicWidth.coerceAtLeast(1)
                    val height = iconDrawable.intrinsicHeight.coerceAtLeast(1)
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)
                    iconDrawable.setBounds(0, 0, canvas.width, canvas.height)
                    iconDrawable.draw(canvas)
                    bitmap
                }
            }
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun getApkIcon(apkPath: String): ByteArray? {
        val lowerPath = apkPath.lowercase()
        if (lowerPath.endsWith(".xapk") || lowerPath.endsWith(".apks") || lowerPath.endsWith(".apkm")) {
            return try {
                val zipFile = java.util.zip.ZipFile(apkPath)
                var iconBytes: ByteArray? = null
                
                // For XAPK, look for icon.png/icon.webp first
                if (lowerPath.endsWith(".xapk")) {
                    val entries = zipFile.entries()
                    while (entries.hasMoreElements()) {
                        val entry = entries.nextElement()
                        if (entry.name.equals("icon.png", ignoreCase = true) || 
                            entry.name.equals("icon.webp", ignoreCase = true)) {
                            val stream = zipFile.getInputStream(entry)
                            val outStream = ByteArrayOutputStream()
                            val buffer = ByteArray(1024)
                            var length: Int
                            while (stream.read(buffer).also { length = it } != -1) {
                                outStream.write(buffer, 0, length)
                            }
                            iconBytes = outStream.toByteArray()
                            stream.close()
                            break
                        }
                    }
                }
                
                // If icon is not found, extract base.apk or the first/largest apk
                if (iconBytes == null) {
                    var apkEntry: java.util.zip.ZipEntry? = null
                    val entries = zipFile.entries()
                    var maxApkSize = 0L
                    
                    while (entries.hasMoreElements()) {
                        val entry = entries.nextElement()
                        if (entry.name.endsWith(".apk", ignoreCase = true)) {
                            // base.apk is preferred, otherwise take largest apk
                            if (entry.name.equals("base.apk", ignoreCase = true) || 
                                entry.name.split("/").last().equals("base.apk", ignoreCase = true)) {
                                apkEntry = entry
                                break
                            } else if (entry.size > maxApkSize) {
                                apkEntry = entry
                                maxApkSize = entry.size
                            }
                        }
                    }
                    
                    if (apkEntry != null) {
                        val tempFile = java.io.File.createTempFile("temp_base", ".apk", cacheDir)
                        val stream = zipFile.getInputStream(apkEntry)
                        val outStream = java.io.FileOutputStream(tempFile)
                        val buffer = ByteArray(4096)
                        var length: Int
                        while (stream.read(buffer).also { length = it } != -1) {
                            outStream.write(buffer, 0, length)
                        }
                        outStream.close()
                        stream.close()
                        
                        iconBytes = getApkIconFromPath(tempFile.absolutePath)
                        tempFile.delete()
                    }
                }
                zipFile.close()
                iconBytes
            } catch (e: Exception) {
                null
            }
        }
        return getApkIconFromPath(apkPath)
    }

    private fun getApkIconFromPath(apkPath: String): ByteArray? {
        return try {
            val pm = packageManager
            val info = pm.getPackageArchiveInfo(apkPath, 0)
            if (info != null) {
                val appInfo = info.applicationInfo
                if (appInfo != null) {
                    appInfo.sourceDir = apkPath
                    appInfo.publicSourceDir = apkPath
                    val iconDrawable = appInfo.loadIcon(pm)
                    val bitmap = when (iconDrawable) {
                        is BitmapDrawable -> iconDrawable.bitmap
                        else -> {
                            val width = iconDrawable.intrinsicWidth.coerceAtLeast(1)
                            val height = iconDrawable.intrinsicHeight.coerceAtLeast(1)
                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                            val canvas = Canvas(bitmap)
                            iconDrawable.setBounds(0, 0, canvas.width, canvas.height)
                            iconDrawable.draw(canvas)
                            bitmap
                        }
                    }
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    stream.toByteArray()
                } else {
                    null
                }
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun isUsageStatsPermissionGranted(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
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
        val process: java.lang.Process = if (useRoot) {
            Runtime.getRuntime().exec(arrayOf("su", "-c", command))
        } else {
            val method = Shizuku::class.java.getDeclaredMethod("newProcess", Array<String>::class.java, Array<String>::class.java, String::class.java)
            method.isAccessible = true
            method.invoke(null, arrayOf("sh", "-c", command), null, null) as java.lang.Process
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
