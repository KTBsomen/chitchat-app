import 'dart:async';
import 'dart:io';

import 'package:better_open_file/better_open_file.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/filePreview.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:vs_media_picker/vs_media_picker.dart';

class CameraAwesomeApp extends StatelessWidget {
  const CameraAwesomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'camerAwesome',
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  // late StreamSubscription<MediaCapture?> _captureStateSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to the captureState$ stream
    //   _captureStateSubscription = CameraState.captureState$
    //   .listen((MediaCaptureStatus state) {
    // print("Camera capture state changed: $state");
    // });
  }

  @override
  void dispose() {
    // Cancel the subscription to prevent memory leaks
    // _captureStateSubscription.cancel();

    super.dispose();
  }

  final ScrollController _scrollController2 = ScrollController();

  void show(BuildContext parentContext) {
    ValueNotifier<bool> isNextButtonVisible = ValueNotifier(false);
    List<PickedAssetModel> selectedFiles = <PickedAssetModel>[];

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: AppColors.bottomSheetBackground,
      builder: (context) => Stack(
        children: [
          VSMediaPicker(
            maxPickImages: 100,
            gridViewController: _scrollController2,
            singlePick: false,
            onlyImages: false,
            appBarColor: Colors.black,
            gridViewPhysics: const ScrollPhysics(),
            pathList: (path) {
              if (path.isNotEmpty) {
                print("path: ${path.map((e) => e.type).toList()}");
              }
              selectedFiles = path;
              isNextButtonVisible.value = selectedFiles.isNotEmpty;
            },
            appBarLeadingWidget: Padding(
              padding: const EdgeInsets.only(bottom: 15, right: 15),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.2,
                            )),
                        child: const Row(
                          children: [
                            Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    RepaintBoundary(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isNextButtonVisible,
                        builder: (context, isVisible, child) {
                          return isVisible
                              ? InkWell(
                                  onTap: () async {
                                    Navigator.pop(context); // Close bottom sheet cleanly
                                    Navigator.push(
                                      parentContext,
                                      MaterialPageRoute(
                                          builder: (context) => FilePreviewPage(
                                                files: selectedFiles,
                                              )),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.2,
                                        )),
                                    child: const Row(
                                      children: [
                                        Text(
                                          'Next',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Text(
                  'Select files to send',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to save the file to the gallery
  List<String> _filePaths = [];
  Future<void> _saveToGallery(String filePath, bool isVideo) async {
    if (filePath.isEmpty) {
      debugPrint('File path is empty');
      return;
    }
    final selectedFiles = PickedAssetModel(
      file: File(filePath),
      path: filePath,
      type: isVideo ? 'video' : 'image',
    );
    // Check if the file path is already saved to avoid duplicates
    if (!_filePaths.contains(filePath)) {
      _filePaths.add(filePath);
    } else {
      debugPrint('File already saved: $filePath');
      return;
    }
    if (isVideo) {
      GallerySaver.saveVideo(filePath).then((success) {
        if (success == true) {
          debugPrint('Video saved to gallery: $filePath');
        } else {
          debugPrint('Failed to save video: $filePath');
        }
      });
    } else {
      GallerySaver.saveImage(filePath).then((success) {
        if (success == true) {
          debugPrint('Image saved to gallery: $filePath');
        } else {
          debugPrint('Failed to save image: $filePath');
        }
      });
    }
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => FilePreviewPage(
                files: [selectedFiles],
              )),
    );
  }

  // Function to preview the file
  void _previewFile(String filePath) {
    OpenFile.open(filePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: CameraAwesomeBuilder.awesome(
          progressIndicator: null,
          saveConfig: SaveConfig.photoAndVideo(
            initialCaptureMode: CaptureMode.photo,
            photoPathBuilder: (sensors) async {
              final Directory extDir = await getTemporaryDirectory();
              final testDir = await Directory(
                '${extDir.path}/camerawesome',
              ).create(recursive: true);
              if (sensors.length == 1) {
                final String filePath =
                    '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                return SingleCaptureRequest(filePath, sensors.first);
              }
              // Separate pictures taken with front and back camera
              return MultipleCaptureRequest(
                {
                  for (final sensor in sensors)
                    sensor:
                        '${testDir.path}/${sensor.position == SensorPosition.front ? 'front_' : "back_"}${DateTime.now().millisecondsSinceEpoch}.jpg',
                },
              );
            },
            videoOptions: VideoOptions(
              enableAudio: true,
              ios: CupertinoVideoOptions(
                fps: 10,
              ),
              android: AndroidVideoOptions(
                bitrate: 6000000,
                fallbackStrategy: QualityFallbackStrategy.lower,
              ),
            ),
            exifPreferences: ExifPreferences(saveGPSLocation: false),
          ),
          sensorConfig: SensorConfig.single(
            sensor: Sensor.position(SensorPosition.back),
            flashMode: FlashMode.auto,
            aspectRatio: CameraAspectRatios.ratio_16_9,
            zoom: 0.0,
          ),
          enablePhysicalButton: true,
          previewAlignment: Alignment.center,
          previewFit: CameraPreviewFit.contain,
          availableFilters: awesomePresetFiltersList,
          bottomActionsBuilder: (state) => AwesomeBottomActions(
            state: state,
            right: SizedBox(
              width: 60,
              child: StreamBuilder<MediaCapture?>(
                stream: state.captureState$,
                builder: (_, snapshot) {
                  if (snapshot.hasData) {
                    final event = snapshot.data!;
                    // This function now handles both saving and previewing
                    switch ((event.status, event.isPicture, event.isVideo)) {
                      // For photos
                      case (MediaCaptureStatus.capturing, true, false):
                        debugPrint('Capturing picture...');
                      case (MediaCaptureStatus.success, true, false):
                        event.captureRequest.when(
                          single: (single) {
                            if (single.file != null) {
                              // Save to gallery automatically when captured
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _saveToGallery(single.file!.path, false);
                              });
                              // Open for preview after saving
                              // _previewFile(single.file!.path);
                            }
                          },
                          multiple: (multiple) {
                            multiple.fileBySensor.forEach((key, value) {
                              if (value != null) {
                                // Save to gallery automatically

                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _saveToGallery(value.path, false);
                                });
                              }
                            });
                          },
                        );
                      case (MediaCaptureStatus.failure, true, false):
                        debugPrint(
                            'Failed to capture picture: ${event.exception}');

                      // For videos
                      case (MediaCaptureStatus.capturing, false, true):
                        debugPrint('Capturing video...');
                      case (MediaCaptureStatus.success, false, true):
                        event.captureRequest.when(
                          single: (single) {
                            if (single.file != null) {
                              // Save to gallery automatically when video captured
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _saveToGallery(single.file!.path, true);
                              });
                            }
                          },
                          multiple: (multiple) {
                            multiple.fileBySensor.forEach((key, value) {
                              if (value != null) {
                                // Save to gallery automatically
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _saveToGallery(value.path, true);
                                });
                              }
                            });
                          },
                        );
                      case (MediaCaptureStatus.failure, false, true):
                        debugPrint(
                            'Failed to capture video: ${event.exception}');
                      default:
                        debugPrint('Unknown event: $event');
                    }
                  }
                  if (snapshot.data == null) {
                    return InkWell(
                      onTap: () {
                        show(context);
                      },
                      child: Column(
                        children: [
                          const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 30,
                          ),
                          const Text('Gallery',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              )),
                        ],
                      ),
                    );
                  }
                  return AwesomeMediaPreview(
                    mediaCapture: snapshot.data!,
                    onMediaTap: (MediaCapture mediaCapture) {
                      // ignore: avoid_print
                      print("Tap on $mediaCapture");
                      show(context);
                    },
                  );
                },
              ),
            ),
            left: AwesomeCameraSwitchButton(
              state: state,
              scale: 1.0,
              onSwitchTap: (state) {
                state.switchCameraSensor(
                  aspectRatio: state.sensorConfig.aspectRatio,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
