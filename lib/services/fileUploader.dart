import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';

/// Enum to represent different stages of file upload
enum UploadStage {
  custom,
  preparing,
  resizing,
  fetchingPresignedUrls,
  uploading,
  completed,
  failed
}

/// Detailed progress model for file upload
class FileUploadProgress {
  final String fileName;
  UploadStage stage;
  double stageProgress; // Progress within current stage (0.0 - 1.0)
  String? errorMessage;
  int? totalFiles;
  int? currentFileIndex;
  String? customStageText;
  String? customStageTextDetail;

  FileUploadProgress({
    required this.fileName,
    this.stage = UploadStage.preparing,
    this.stageProgress = 0.0,
    this.errorMessage,
    this.totalFiles,
    this.currentFileIndex,
    this.customStageText,
    this.customStageTextDetail,
  });

  FileUploadProgress copyWith({
    UploadStage? stage,
    double? stageProgress,
    String? errorMessage,
    int? totalFiles,
    int? currentFileIndex,
    String? customStageText,
    String? customStageTextDetail,
  }) {
    return FileUploadProgress(
      fileName: fileName,
      stage: stage ?? this.stage,
      stageProgress: stageProgress ?? this.stageProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      totalFiles: totalFiles ?? this.totalFiles,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      customStageText: customStageText ?? this.customStageText,
      customStageTextDetail:
          customStageTextDetail ?? this.customStageTextDetail,
    );
  }
}

class S3Uploader {
  final String presignedUrlEndpoint;
  ValueNotifier<FileUploadProgress> progressNotifier;

  final Dio dio;

  S3Uploader({
    required this.presignedUrlEndpoint,
    required this.progressNotifier,
    Dio? dioInstance,
  }) : dio = dioInstance ?? Dio();

  /// Main upload function with detailed progress tracking
  Future<List<String>> uploadFiles({
    required List<dynamic> files,
    Map<String, dynamic>? compressionParams,
    bool showResizingProgress = true,
    bool showPresignedUrlProgress = false,
  }) async {
    // Create progress tracker
    progressNotifier.value = progressNotifier.value.copyWith(
      stage: UploadStage.preparing,
      totalFiles: files.length,
      currentFileIndex: 0,
    );

    try {
      final processedFiles = <File>[];

      // Step 1: Resize Images
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final resolvedFile = await _resolveFile(file);
        final mimeType = lookupMimeType(resolvedFile.path);

        if (showResizingProgress &&
            (mimeType != null &&
                mimeType.startsWith('image/') &&
                compressionParams != null)) {
          progressNotifier.value = progressNotifier.value.copyWith(
            stage: UploadStage.resizing,
            currentFileIndex: i + 1,
            stageProgress: 0.0,
          );
        }

        if (mimeType != null &&
            mimeType.startsWith('image/') &&
            compressionParams != null) {
          final resizedFile = await _compressAndResizeImage(
              resolvedFile, compressionParams, (progress) {
            if (showResizingProgress) {
              progressNotifier.value = progressNotifier.value.copyWith(
                stageProgress: progress,
              );
            }
          });
          processedFiles.add(resizedFile);
        } else {
          processedFiles.add(resolvedFile);
        }
      }

      // Step 2: Get Presigned URLs
      List<String> presignedUrls;
      if (showPresignedUrlProgress) {
        progressNotifier.value = progressNotifier.value.copyWith(
          stage: UploadStage.fetchingPresignedUrls,
          stageProgress: 0.0,
        );
      }

      final contentTypes = processedFiles
          .map(
              (file) => lookupMimeType(file.path) ?? 'application/octet-stream')
          .toList();

      presignedUrls = await _fetchPresignedUrls(contentTypes);

      // Step 3: Upload to S3
      progressNotifier.value = progressNotifier.value.copyWith(
        stage: UploadStage.uploading,
        stageProgress: 0.0,
      );

      final uploadTasks = <Future<String>>[]; // List to hold the tasks

      for (int i = 0; i < processedFiles.length; i++) {
        final file = processedFiles[i];
        final url = presignedUrls[i];

        // Create a task for each upload operation
        final uploadTask = _uploadFileToS3(file, url, (progress, total) {
          progressNotifier.value = progressNotifier.value.copyWith(
            currentFileIndex: i + 1,
            stageProgress: progress / total,
          );
        }).catchError((e) {
          // Handle any error specific to this file upload
          print("Error uploading file: $e");
        });

        // Add the task to the list
        uploadTasks.add(uploadTask);
      }

// Wait for all tasks to complete
      final uploadedUrls = await Future.wait(uploadTasks);

// uploadedUrls now contains all the uploaded file URLs

      // Mark as completed
      progressNotifier.value = progressNotifier.value.copyWith(
        stage: UploadStage.completed,
        stageProgress: 1.0,
      );

      return uploadedUrls;
    } catch (e) {
      // Update progress to failed state
      progressNotifier.value = progressNotifier.value.copyWith(
        stage: UploadStage.failed,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Compress and resize image with progress callback
  Future<File> _compressAndResizeImage(File file, Map<String, dynamic> params,
      Function(double)? progressCallback) async {
    progressCallback?.call(0.0);

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image != null) {
      // Maintain aspect ratio
      int newWidth = params['width'] ?? image.width;
      int newHeight = params['height'] ?? image.height;

      // Calculate aspect ratio
      final aspectRatio = image.width / image.height;

      if (params['width'] != null && params['height'] == null) {
        // Adjust height to maintain aspect ratio
        newHeight = (newWidth / aspectRatio).round();
      } else if (params['height'] != null && params['width'] == null) {
        // Adjust width to maintain aspect ratio
        newWidth = (newHeight * aspectRatio).round();
      } else if (params['width'] != null && params['height'] != null) {
        // If both are provided, ensure they respect aspect ratio
        final heightForWidth = (newWidth / aspectRatio).round();
        final widthForHeight = (newHeight * aspectRatio).round();

        if (heightForWidth <= newHeight) {
          newHeight = heightForWidth;
        } else {
          newWidth = widthForHeight;
        }
      }

      progressCallback?.call(0.5);

      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
      );

      // Compress the image
      final compressedBytes =
          img.encodeJpg(resizedImage, quality: params['quality'] ?? 90);

      progressCallback?.call(0.8);

      // Create a temporary file for the resized image
      final tempPath =
          path.join(Directory.systemTemp.path, path.basename(file.path));
      final resizedFile = File(tempPath)..writeAsBytesSync(compressedBytes);

      progressCallback?.call(1.0);
      return resizedFile;
    } else {
      throw Exception("Failed to decode image for resizing.");
    }
  }

  /// Resolve different file types to File
  Future<File> _resolveFile(dynamic file) async {
    if (file is File) return file;
    if (file is String) return File(file);
    if (file is XFile) return File(file.path);

    throw Exception("Unsupported file type: ${file.runtimeType}");
  }

  /// Fetch pre-signed URLs
  Future<List<String>> _fetchPresignedUrls(List<String> contentTypes) async {
    final response = await dio.post(
      presignedUrlEndpoint,
      data: {'files': contentTypes},
      options: Options(
        contentType: Headers.jsonContentType,
      ),
    );

    if (response.statusCode == 200) {
      final urls = (response.data['urls'] as List)
          .map((urlData) => urlData['signedUrl'] as String)
          .toList();
      return urls;
    } else {
      throw Exception("Failed to fetch pre-signed URLs: ${response.data}");
    }
  }

  /// Upload individual file to S3 using Dio
  Future<String> _uploadFileToS3(
    File file,
    String presignedUrl,
    Function(double, double)? progressCallback,
  ) async {
    try {
      // Ensure file exists before proceeding
      if (!file.existsSync()) {
        throw Exception("File not found at path: ${file.path}");
      }

      // Get file length
      final fileLength = await file.length();

      // Validate presigned URL
      if (!Uri.tryParse(presignedUrl)!.hasAbsolutePath ?? true) {
        throw Exception("Invalid presigned URL");
      }

      // Dio PUT request
      final response = await dio.put(
        presignedUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            'Content-Type': lookupMimeType(file.path) ??
                'application/octet-stream', // Set correct content type
            'Content-Length': fileLength.toString(), // Explicit content length
          },
        ),
        onSendProgress: (sent, total) {
          progressCallback?.call(sent.toDouble(), total.toDouble());
        },
      );

      // Handle response
      if (response.statusCode == 200) {
        // Return the public URL without query parameters
        return presignedUrl.split('?').first;
      } else {
        throw Exception(
            "Failed to upload file: ${response.statusCode} ${response.statusMessage}");
      }
    } on DioException catch (dioError) {
      final errorMessage = dioError.response?.statusMessage ?? dioError.message;
      throw Exception("DioError during file upload: $errorMessage");
    } catch (e) {
      throw Exception("Error uploading file: $e");
    }
  }
}

/// Reusable Upload Progress Widget
class UploadProgressWidget extends StatelessWidget {
  final ValueNotifier<FileUploadProgress> progressNotifier;
  final bool showStageText;
  final bool showErrorOnFail;
  final TextStyle? stageTextStyle;
  final TextStyle? progressTextStyle;
  final String? customStageText;
  final String? customStageTextDetail;

  final Widget Function(
          BuildContext context, FileUploadProgress progress, Widget child)?
      progressBuilder;

  const UploadProgressWidget({
    Key? key,
    required this.progressNotifier,
    this.showStageText = true,
    this.showErrorOnFail = true,
    this.stageTextStyle,
    this.progressTextStyle,
    this.progressBuilder,
    this.customStageText,
    this.customStageTextDetail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FileUploadProgress>(
      valueListenable: progressNotifier,
      builder: (context, progress, child) {
        if (progressBuilder != null) {
          return progressBuilder!(context, progress, child!);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stage Text
            if (showStageText)
              Text(
                progress.customStageText ?? _getStageText(progress.stage),
                style: stageTextStyle ??
                    const TextStyle(fontWeight: FontWeight.bold),
              ),

            // Progress Indicator
            LinearProgressIndicator(
              value: progress.stageProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(progress.stage),
              ),
            ),

            // Progress Details
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                progress.customStageTextDetail ?? _getProgressDetails(progress),
                style: progressTextStyle,
              ),
            ),

            // Error Message
            if (progress.stage == UploadStage.failed &&
                showErrorOnFail &&
                progress.errorMessage != null)
              Text(
                'Error: ${progress.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        );
      },
    );
  }

  /// Get readable stage text
  String _getStageText(UploadStage stage) {
    switch (stage) {
      case UploadStage.preparing:
        return 'Preparing Files';
      case UploadStage.resizing:
        return 'Resizing Images';
      case UploadStage.fetchingPresignedUrls:
        return 'Fetching Upload URLs';
      case UploadStage.uploading:
        return 'Uploading Files';
      case UploadStage.completed:
        return 'Upload Completed';
      case UploadStage.failed:
        return 'Upload Failed';
      default:
        return '';
    }
  }

  /// Get progress color based on stage
  Color _getProgressColor(UploadStage stage) {
    switch (stage) {
      case UploadStage.completed:
        return Colors.green;
      case UploadStage.failed:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// Get detailed progress text
  String _getProgressDetails(FileUploadProgress progress) {
    switch (progress.stage) {
      case UploadStage.resizing:
        return 'Resizing image ${progress.currentFileIndex}/${progress.totalFiles}';
      case UploadStage.uploading:
        return 'Uploading file ${progress.currentFileIndex}/${progress.totalFiles} '
            '(${(progress.stageProgress * 100).toStringAsFixed(1)}%)';
      case UploadStage.fetchingPresignedUrls:
        return 'Preparing upload URLs';
      case UploadStage.preparing:
        return 'Preparing ${progress.totalFiles} files';
      case UploadStage.completed:
        return 'Successfully uploaded ${progress.totalFiles} files';
      case UploadStage.failed:
        return 'Upload failed';
      case UploadStage.custom:
        return progress.customStageTextDetail ?? '';
    }
  }
}
