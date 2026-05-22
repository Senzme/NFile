import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

class VaultFileRecord {
  final String id;
  final String originalName;
  final String originalPath;
  final String scrambledPath;
  final int size;
  final String lockedAt;
  final bool isInPlace;
  final bool isFolder;

  VaultFileRecord({
    required this.id,
    required this.originalName,
    required this.originalPath,
    required this.scrambledPath,
    required this.size,
    required this.lockedAt,
    required this.isInPlace,
    this.isFolder = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalName': originalName,
    'originalPath': originalPath,
    'scrambledPath': scrambledPath,
    'size': size,
    'lockedAt': lockedAt,
    'isInPlace': isInPlace,
    'isFolder': isFolder,
  };

  factory VaultFileRecord.fromJson(Map<String, dynamic> json) => VaultFileRecord(
    id: json['id'] as String,
    originalName: json['originalName'] as String,
    originalPath: json['originalPath'] as String,
    scrambledPath: json['scrambledPath'] as String,
    size: json['size'] as int,
    lockedAt: json['lockedAt'] as String,
    isInPlace: json['isInPlace'] as bool,
    isFolder: json['isFolder'] as bool? ?? false,
  );
}

class VaultService {
  static const String _magicTag = 'NFILE_VAULT_V1';
  static const int _scrambleSize = 8192; // 8 KB

  // Hashing and Password Management
  static Future<bool> isPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('vault_password_hash');
  }

  static Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final saltedPassword = password + salt;
    final hash = sha256.convert(utf8.encode(saltedPassword)).toString();
    await prefs.setString('vault_salt', salt);
    await prefs.setString('vault_password_hash', hash);
  }

  static Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString('vault_salt');
    final hash = prefs.getString('vault_password_hash');
    if (salt == null || hash == null) return false;
    final checkHash = sha256.convert(utf8.encode(password + salt)).toString();
    return hash == checkHash;
  }

  // Get Vault Directory
  static Future<Directory> getVaultDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(docDir.path, 'vault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  // Get Metadata JSON File path
  static Future<File> getMetadataFile() async {
    final vaultDir = await getVaultDir();
    return File(p.join(vaultDir.path, 'metadata.json'));
  }

  // Load locked file records
  static Future<List<VaultFileRecord>> loadRecords() async {
    final file = await getMetadataFile();
    if (!await file.exists()) return [];
    try {
      final str = await file.readAsString();
      final list = jsonDecode(str) as List;
      return list.map((e) => VaultFileRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // Save locked file records
  static Future<void> saveRecords(List<VaultFileRecord> records) async {
    final file = await getMetadataFile();
    final str = jsonEncode(records.map((e) => e.toJson()).toList());
    await file.writeAsString(str);
  }

  // Derives the repeating XOR key from the password
  static List<int> _deriveKey(String password, int length) {
    final hash = sha256.convert(utf8.encode(password)).bytes;
    final key = List<int>.filled(length, 0);
    for (int i = 0; i < length; i++) {
      key[i] = hash[i % hash.length] ^ (i & 0xFF);
    }
    return key;
  }

  // Obfuscates/Deobfuscates a list of bytes using XOR
  static List<int> _xorBytes(List<int> bytes, List<int> key) {
    final result = List<int>.from(bytes);
    for (int i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ key[i % key.length];
    }
    return result;
  }

  // Locks and obfuscates a file
  static Future<VaultFileRecord> lockFile({
    required File file,
    required String password,
    required bool inPlace,
    String? customName,
    String? customPath,
    bool isFolder = false,
  }) async {
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final originalPath = customPath ?? file.path;
    final originalName = customName ?? p.basename(originalPath);
    final size = await file.length();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Determine target scrambled path
    String scrambledPath;
    if (inPlace) {
      // Scramble in the same directory, starting with a dot (hidden on Linux/Android)
      final dir = isFolder ? originalPath : p.dirname(originalPath);
      scrambledPath = p.join(dir, '.vault_$timestamp.nfv');
    } else {
      // Isolate inside app's private documents vault folder
      final vaultDir = await getVaultDir();
      scrambledPath = p.join(vaultDir.path, 'vault_$timestamp.nfv');
    }

    // Read file bytes
    final fileBytes = await file.readAsBytes();

    // Partition bytes
    final scrambleLen = min(_scrambleSize, fileBytes.length);
    final scrambleBytes = fileBytes.sublist(0, scrambleLen);
    final restBytes = fileBytes.sublist(scrambleLen);

    // Encrypt the signature part
    final key = _deriveKey(password, scrambleLen);
    final obfuscatedBytes = _xorBytes(scrambleBytes, key);

    // Build metadata payload
    final metadata = {
      'name': originalName,
      'path': originalPath,
      'size': size,
      'timestamp': timestamp,
      'isFolder': isFolder,
    };
    final metadataStr = jsonEncode(metadata);
    final metadataBytes = utf8.encode(metadataStr);

    // Obfuscate metadata payload too so it's fully private
    final metaKey = _deriveKey(password, metadataBytes.length);
    final obfuscatedMetadata = _xorBytes(metadataBytes, metaKey);

    // Create the scrambled file format:
    // [MAGIC_TAG] (14 bytes)
    // [METADATA_LENGTH] (4 bytes int)
    // [OBFUSCATED_METADATA]
    // [OBFUSCATED_SIGNATURE]
    // [REST_OF_FILE]
    final headerBytes = BytesBuilder();
    headerBytes.add(utf8.encode(_magicTag)); // 14 bytes
    
    // Add metadata length as 4-byte big endian int
    final metaLen = obfuscatedMetadata.length;
    headerBytes.add([
      (metaLen >> 24) & 0xFF,
      (metaLen >> 16) & 0xFF,
      (metaLen >> 8) & 0xFF,
      metaLen & 0xFF,
    ]);
    
    headerBytes.add(obfuscatedMetadata);
    headerBytes.add(obfuscatedBytes);
    headerBytes.add(restBytes);

    // Write to the scrambled target path
    final targetFile = File(scrambledPath);
    await targetFile.writeAsBytes(headerBytes.toBytes());

    // Clean up original file
    await file.delete();

    // Create record
    final record = VaultFileRecord(
      id: timestamp,
      originalName: originalName,
      originalPath: originalPath,
      scrambledPath: scrambledPath,
      size: size,
      lockedAt: DateTime.now().toIso8601String(),
      isInPlace: inPlace,
      isFolder: isFolder,
    );

    // Save record to metadata.json
    final records = await loadRecords();
    records.add(record);
    await saveRecords(records);

    return record;
  }

  // Unlocks and restores an obfuscated file
  static Future<File> unlockFile({
    required VaultFileRecord record,
    required String password,
  }) async {
    final scrambledFile = File(record.scrambledPath);
    if (!await scrambledFile.exists()) {
      throw Exception('Scrambled vault file not found: ${record.scrambledPath}');
    }

    final bytes = await scrambledFile.readAsBytes();
    
    // Verify magic tag
    if (bytes.length < _magicTag.length + 4) {
      throw Exception('Invalid vault file format (Too short)');
    }
    final magicBytes = bytes.sublist(0, _magicTag.length);
    final magic = utf8.decode(magicBytes);
    if (magic != _magicTag) {
      throw Exception('Invalid vault file format (Magic tag mismatch)');
    }

    // Read metadata length
    final lenBytes = bytes.sublist(_magicTag.length, _magicTag.length + 4);
    final metaLen = (lenBytes[0] << 24) | (lenBytes[1] << 16) | (lenBytes[2] << 8) | lenBytes[3];

    // Extract obfuscated metadata
    final metaStart = _magicTag.length + 4;
    final metaEnd = metaStart + metaLen;
    if (bytes.length < metaEnd) {
      throw Exception('Invalid vault file format (Corrupted header)');
    }
    final obfuscatedMetadata = bytes.sublist(metaStart, metaEnd);

    // Decrypt metadata
    final metaKey = _deriveKey(password, obfuscatedMetadata.length);
    final decryptedMetadataBytes = _xorBytes(obfuscatedMetadata, metaKey);
    
    Map<String, dynamic> metadata;
    try {
      final decryptedMetadataStr = utf8.decode(decryptedMetadataBytes);
      metadata = jsonDecode(decryptedMetadataStr) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Incorrect password or corrupted file');
    }

    // Extract scrambled signature bytes
    final fileDataStart = metaEnd;
    final originalSize = metadata['size'] as int;
    final scrambleLen = min(_scrambleSize, originalSize);
    
    if (bytes.length < fileDataStart + scrambleLen) {
      throw Exception('Invalid vault file format (Corrupted payload)');
    }
    final obfuscatedSignature = bytes.sublist(fileDataStart, fileDataStart + scrambleLen);
    final restBytes = bytes.sublist(fileDataStart + scrambleLen);

    // Decrypt signature bytes
    final key = _deriveKey(password, scrambleLen);
    final decryptedSignature = _xorBytes(obfuscatedSignature, key);

    // Reconstruct original file bytes
    final originalBytes = BytesBuilder();
    originalBytes.add(decryptedSignature);
    originalBytes.add(restBytes);

    final originalFile = File(record.originalPath);

    if (record.isFolder) {
      // Reconstruct folder structure recursively
      final archive = ZipDecoder().decodeBytes(originalBytes.toBytes());
      final destinationDir = p.dirname(record.originalPath);

      for (final file in archive) {
        final filename = file.name;
        final fullPath = p.join(destinationDir, filename);
        if (file.isFile) {
          final data = file.content as List<int>;
          final destFile = File(fullPath);
          await destFile.parent.create(recursive: true);
          await destFile.writeAsBytes(data);
        } else {
          await Directory(fullPath).create(recursive: true);
        }
      }
    } else {
      // Recreate original parent folder if deleted
      final originalDir = originalFile.parent;
      if (!await originalDir.exists()) {
        await originalDir.create(recursive: true);
      }

      // Write original bytes back to original path
      await originalFile.writeAsBytes(originalBytes.toBytes());
    }

    // Clean up scrambled nfv file
    await scrambledFile.delete();

    // Remove record from metadata
    final records = await loadRecords();
    records.removeWhere((e) => e.id == record.id);
    await saveRecords(records);

    return originalFile;
  }

  // Locks and obfuscates a directory by zipping it recursively first
  static Future<VaultFileRecord> lockDirectory({
    required Directory directory,
    required String password,
    required bool inPlace,
  }) async {
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: ${directory.path}');
    }

    final originalPath = directory.path;
    final originalName = p.basename(originalPath);

    // List all files recursively
    final list = directory.listSync(recursive: true);
    final archive = Archive();

    for (final entity in list) {
      if (entity is File) {
        // Calculate relative path from the parent of the directory being zipped
        // So that the zipped file path starts with the folder name itself (e.g. "myfolder/file.txt")
        final relPath = p.relative(entity.path, from: p.dirname(originalPath)).replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      }
    }

    // Encode the archive as a ZIP
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw Exception('Failed to zip directory contents');
    }

    // Write zip to a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempZipFile = File(p.join(tempDir.path, 'temp_vault_zip_${DateTime.now().millisecondsSinceEpoch}.zip'));
    await tempZipFile.writeAsBytes(zipBytes);

    try {
      // Call lockFile on the temporary zip file, flag it as isFolder: true
      final record = await lockFile(
        file: tempZipFile,
        password: password,
        inPlace: inPlace,
        customName: originalName,
        customPath: originalPath,
        isFolder: true,
      );

      // Clean up original directory contents (or keep folder for in-place)
      if (inPlace) {
        final children = directory.listSync();
        for (final child in children) {
          if (child.path != record.scrambledPath) {
            await child.delete(recursive: true);
          }
        }
      } else {
        await directory.delete(recursive: true);
      }

      return record;
    } finally {
      // Always ensure the temporary zip is deleted
      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }
    }
  }

  // Temporarily decrypts a vault file to cache directory for in-app viewing
  static Future<File> decryptTemporary({
    required VaultFileRecord record,
    required String password,
  }) async {
    final scrambledFile = File(record.scrambledPath);
    if (!await scrambledFile.exists()) {
      throw Exception('Scrambled vault file not found');
    }

    final bytes = await scrambledFile.readAsBytes();
    
    // Read metadata
    final lenBytes = bytes.sublist(_magicTag.length, _magicTag.length + 4);
    final metaLen = (lenBytes[0] << 24) | (lenBytes[1] << 16) | (lenBytes[2] << 8) | lenBytes[3];
    
    final metaStart = _magicTag.length + 4;
    final metaEnd = metaStart + metaLen;
    final obfuscatedMetadata = bytes.sublist(metaStart, metaEnd);
    final metaKey = _deriveKey(password, obfuscatedMetadata.length);
    final decryptedMetadataBytes = _xorBytes(obfuscatedMetadata, metaKey);
    final decryptedMetadataStr = utf8.decode(decryptedMetadataBytes);
    final metadata = jsonDecode(decryptedMetadataStr) as Map<String, dynamic>;

    final originalSize = metadata['size'] as int;
    final scrambleLen = min(_scrambleSize, originalSize);
    
    final fileDataStart = metaEnd;
    final obfuscatedSignature = bytes.sublist(fileDataStart, fileDataStart + scrambleLen);
    final restBytes = bytes.sublist(fileDataStart + scrambleLen);

    final key = _deriveKey(password, scrambleLen);
    final decryptedSignature = _xorBytes(obfuscatedSignature, key);

    final originalBytes = BytesBuilder();
    originalBytes.add(decryptedSignature);
    originalBytes.add(restBytes);

    // Write to a temporary file in cache directory
    final cacheDir = await getTemporaryDirectory();
    final extension = record.isFolder ? '.zip' : '';
    final tempFilePath = p.join(cacheDir.path, 'temp_vault_${record.id}_${record.originalName}$extension');
    final tempFile = File(tempFilePath);
    
    await tempFile.writeAsBytes(originalBytes.toBytes());
    return tempFile;
  }
}
