package com.rubex.nfile

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException

class NFileDocumentsProvider : DocumentsProvider() {

    private val DEFAULT_ROOT_PROJECTION = arrayOf(
        DocumentsContract.Root.COLUMN_ROOT_ID,
        DocumentsContract.Root.COLUMN_MIME_TYPES,
        DocumentsContract.Root.COLUMN_FLAGS,
        DocumentsContract.Root.COLUMN_ICON,
        DocumentsContract.Root.COLUMN_TITLE,
        DocumentsContract.Root.COLUMN_SUMMARY,
        DocumentsContract.Root.COLUMN_DOCUMENT_ID,
        DocumentsContract.Root.COLUMN_AVAILABLE_BYTES
    )

    private val DEFAULT_DOCUMENT_PROJECTION = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_FLAGS,
        DocumentsContract.Document.COLUMN_SIZE
    )

    override fun onCreate(): Boolean {
        return true
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val flags = DocumentsContract.Root.FLAG_LOCAL_ONLY or 
                    DocumentsContract.Root.FLAG_SUPPORTS_CREATE or 
                    DocumentsContract.Root.FLAG_SUPPORTS_IS_CHILD

        val result = MatrixCursor(projection ?: DEFAULT_ROOT_PROJECTION)
        val row = result.newRow()
        row.add(DocumentsContract.Root.COLUMN_ROOT_ID, "primary")
        row.add(DocumentsContract.Root.COLUMN_DOCUMENT_ID, getDocIdForFile(File("/storage/emulated/0")))
        row.add(DocumentsContract.Root.COLUMN_MIME_TYPES, "*/*")
        row.add(DocumentsContract.Root.COLUMN_FLAGS, flags)
        row.add(DocumentsContract.Root.COLUMN_TITLE, "NFile Storage")
        row.add(DocumentsContract.Root.COLUMN_SUMMARY, "Internal storage via NFile")
        row.add(DocumentsContract.Root.COLUMN_ICON, android.R.drawable.sym_def_app_icon)
        
        try {
            val stat = android.os.StatFs("/storage/emulated/0")
            val availableBytes = stat.availableBlocksLong * stat.blockSizeLong
            row.add(DocumentsContract.Root.COLUMN_AVAILABLE_BYTES, availableBytes)
        } catch (e: Exception) {
            row.add(DocumentsContract.Root.COLUMN_AVAILABLE_BYTES, 0L)
        }

        return result
    }

    override fun queryDocument(documentId: String?, projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val file = getFileForDocId(documentId ?: "primary:")
        includeFile(result, documentId, file)
        return result
    }

    override fun queryChildDocuments(
        parentDocumentId: String?,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val parent = getFileForDocId(parentDocumentId ?: "primary:")
        parent.listFiles()?.forEach { file ->
            val childId = getDocIdForFile(file)
            includeFile(result, childId, file)
        }
        return result
    }

    override fun openDocument(
        documentId: String?,
        mode: String?,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        val file = getFileForDocId(documentId ?: "")
        val accessMode = ParcelFileDescriptor.parseMode(mode ?: "r")
        return ParcelFileDescriptor.open(file, accessMode)
    }

    override fun createDocument(
        parentDocumentId: String?,
        mimeType: String?,
        displayName: String?
    ): String {
        val parent = getFileForDocId(parentDocumentId ?: "")
        val file = File(parent, displayName ?: "unnamed")
        try {
            if (DocumentsContract.Document.MIME_TYPE_DIR == mimeType) {
                file.mkdirs()
            } else {
                file.createNewFile()
            }
        } catch (e: Exception) {
            throw FileNotFoundException("Failed to create document: ${e.message}")
        }
        return getDocIdForFile(file)
    }

    override fun deleteDocument(documentId: String?) {
        val file = getFileForDocId(documentId ?: "")
        if (!file.deleteRecursively()) {
            throw FileNotFoundException("Failed to delete document: $documentId")
        }
    }

    override fun isChildDocument(parentDocumentId: String?, documentId: String?): Boolean {
        if (parentDocumentId == null || documentId == null) return false
        val parent = getFileForDocId(parentDocumentId)
        val child = getFileForDocId(documentId)
        return child.absolutePath.startsWith(parent.absolutePath)
    }

    // Helper functions to map DocumentId to File path and vice versa
    private fun getFileForDocId(documentId: String): File {
        val target = if (documentId.startsWith("primary:")) {
            val relPath = documentId.substring("primary:".length)
            File("/storage/emulated/0", relPath)
        } else {
            File("/storage/emulated/0")
        }
        return target
    }

    private fun getDocIdForFile(file: File): String {
        val rootPath = "/storage/emulated/0"
        val path = file.absolutePath
        return if (path.startsWith(rootPath)) {
            var relPath = path.substring(rootPath.length)
            if (relPath.startsWith("/")) {
                relPath = relPath.substring(1)
            }
            "primary:$relPath"
        } else {
            "primary:"
        }
    }

    private fun includeFile(result: MatrixCursor, docId: String?, file: File) {
        val flags = DocumentsContract.Document.FLAG_SUPPORTS_DELETE or
                    DocumentsContract.Document.FLAG_SUPPORTS_WRITE

        val mimeType = getMimeType(file)
        val finalFlags = if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
            flags or DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE
        } else {
            flags
        }

        val row = result.newRow()
        row.add(DocumentsContract.Document.COLUMN_DOCUMENT_ID, docId)
        row.add(DocumentsContract.Document.COLUMN_DISPLAY_NAME, file.name)
        row.add(DocumentsContract.Document.COLUMN_SIZE, file.length())
        row.add(DocumentsContract.Document.COLUMN_MIME_TYPE, mimeType)
        row.add(DocumentsContract.Document.COLUMN_LAST_MODIFIED, file.lastModified())
        row.add(DocumentsContract.Document.COLUMN_FLAGS, finalFlags)
    }

    private fun getMimeType(file: File): String {
        if (file.isDirectory) {
            return DocumentsContract.Document.MIME_TYPE_DIR
        }
        val name = file.name
        val lastDot = name.lastIndexOf('.')
        if (lastDot >= 0) {
            val extension = name.substring(lastDot + 1).lowercase()
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            if (mime != null) return mime
        }
        return "application/octet-stream"
    }
}
