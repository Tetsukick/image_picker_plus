import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker_plus/image_picker_plus.dart';
import 'package:image_picker_plus/src/child_grid_view_image.dart';
import 'package:image_picker_plus/src/crop_image_view.dart';
import 'package:image_picker_plus/src/custom_packages/crop_image/crop_image.dart';
import 'package:image_picker_plus/src/custom_packages/crop_image/main/image_crop.dart';
import 'package:image_picker_plus/src/image.dart';
import 'package:image_picker_plus/src/multi_selection_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_plus/src/utilities/datetime_extention.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shimmer/shimmer.dart';

class ImagesViewPage extends StatefulWidget {
  final ValueNotifier<List<AssetEntity>> multiSelectedImages;
  final ValueNotifier<bool> multiSelectionMode;
  final TabsTexts tabsTexts;
  final bool cropImage;
  final bool multiSelection;
  final bool byDate;
  final bool showInternalVideos;
  final bool showInternalImages;
  final int maximumSelection;
  final AsyncValueSetter<SelectedImagesDetails>? callbackFunction;

  /// To avoid lag when you interacting with image when it expanded
  final AppTheme appTheme;
  final VoidCallback clearMultiImages;
  final Color whiteColor;
  final Color blackColor;
  final bool showImagePreview;
  final SliverGridDelegateWithFixedCrossAxisCount gridDelegate;

  const ImagesViewPage({
    super.key,
    required this.multiSelectedImages,
    required this.multiSelectionMode,
    required this.clearMultiImages,
    required this.appTheme,
    required this.tabsTexts,
    required this.whiteColor,
    required this.cropImage,
    required this.multiSelection,
    required this.byDate,
    required this.showInternalVideos,
    required this.showInternalImages,
    required this.blackColor,
    required this.showImagePreview,
    required this.gridDelegate,
    required this.maximumSelection,
    this.callbackFunction,
  });

  @override
  State<ImagesViewPage> createState() => _ImagesViewPageState();
}

class _ImagesViewPageState extends State<ImagesViewPage>
    with AutomaticKeepAliveClientMixin<ImagesViewPage> {
  final ValueNotifier<List<FutureBuilder<Uint8List?>>> _mediaList =
      ValueNotifier([]);

  ValueNotifier<List<AssetEntity?>> allImages = ValueNotifier([]);

  ValueNotifier<Map<String, List<(int, FutureBuilder<Uint8List?>)>>>
      mediaListByDate = ValueNotifier({});

  final ValueNotifier<List<double?>> scaleOfCropsKeys = ValueNotifier([]);
  final ValueNotifier<List<Rect?>> areaOfCropsKeys = ValueNotifier([]);

  ValueNotifier<AssetEntity?> selectedImage = ValueNotifier(null);
  ValueNotifier<List<int>> indexOfSelectedImages = ValueNotifier([]);

  ScrollController scrollController = ScrollController();

  final expandImage = ValueNotifier(false);
  final expandHeight = ValueNotifier(0.0);
  final moveAwayHeight = ValueNotifier(0.0);
  final expandImageView = ValueNotifier(false);

  final isImagesReady = ValueNotifier(false);
  final currentPage = ValueNotifier(0);
  final lastPage = ValueNotifier(0);
  final dataIndex = ValueNotifier(0);
  final isFetchLoading = ValueNotifier(false);

  /// To avoid lag when you interacting with image when it expanded
  final enableVerticalTapping = ValueNotifier(false);
  final cropKey = ValueNotifier(GlobalKey<CustomCropState>());
  bool noPaddingForGridView = false;

  List<AssetPathEntity> _cachedAlbums = [];
  ValueNotifier<AssetPathEntity?> selectedAlbum = ValueNotifier(null);
  double scrollPixels = 0.0;
  bool isScrolling = false;
  bool noImages = false;
  bool isGrantGalleryPermission = false;
  final noDuration = ValueNotifier(false);
  int indexOfLatestImage = -1;

  @override
  void dispose() {
    _mediaList.dispose();
    mediaListByDate.dispose();
    allImages.dispose();
    scrollController.dispose();
    isImagesReady.dispose();
    lastPage.dispose();
    expandImage.dispose();
    expandHeight.dispose();
    moveAwayHeight.dispose();
    expandImageView.dispose();
    enableVerticalTapping.dispose();
    cropKey.dispose();
    noDuration.dispose();
    scaleOfCropsKeys.dispose();
    areaOfCropsKeys.dispose();
    indexOfSelectedImages.dispose();
    isFetchLoading.dispose();
    super.dispose();
  }

  late Widget forBack;

  @override
  void initState() {
    _fetchNewMedia(currentPageValue: 0);
    super.initState();
  }

  bool _handleScrollEvent(ScrollNotification scroll,
      {required int currentPageValue, required int lastPageValue}) {
    if (scroll.metrics.pixels / scroll.metrics.maxScrollExtent > 0.33 &&
        currentPageValue != lastPageValue) {
      _fetchNewMedia(currentPageValue: currentPageValue);
      return true;
    }
    return false;
  }

  _fetchNewMedia({required int currentPageValue}) async {
    if (isImagesReady.value) {
      if (isFetchLoading.value) {
        return;
      }
      isFetchLoading.value = true;
    }  
    lastPage.value = currentPageValue;

    PermissionState result = await PhotoManager.requestPermissionExtend();
    if (result == PermissionState.authorized || result == PermissionState.limited) {
      setState(() => isGrantGalleryPermission = true);
      RequestType type = widget.showInternalVideos && widget.showInternalImages
          ? RequestType.common
          : (widget.showInternalImages ? RequestType.image : RequestType.video);

      if (_cachedAlbums.isEmpty) {
        _cachedAlbums =
          await PhotoManager.getAssetPathList(onlyAll: false, type: type);
        if (_cachedAlbums.isEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => setState(() => noImages = true));
          return;
        } else {
          setState(() {
            noImages = false;
            selectedAlbum.value = _cachedAlbums[0];
          });
        }
      }
      List<AssetEntity> media =
          await (selectedAlbum.value ?? _cachedAlbums[0]).getAssetListPaged(page: currentPageValue, size: currentPageValue <= 1 ? 30 : 60);
      List<FutureBuilder<Uint8List?>> temp = [];

      for (int i = 0; i < media.length; i++) {
        FutureBuilder<Uint8List?> gridViewImage =
            await getImageGallery(media, i);
        DateTime exifDate = media[i].createDateTime;
        mediaListByDate.value.update(
          exifDate.toYyyyMMdd(widget.appTheme.locale),
          (value) => [...value, (dataIndex.value, gridViewImage)],
          ifAbsent: () => [(dataIndex.value, gridViewImage)],
        );
        temp.add(gridViewImage);
        dataIndex.value++;
      }
      _mediaList.value.addAll(temp);
      allImages.value.addAll(media);
      currentPage.value++;
      isImagesReady.value = true;
      isFetchLoading.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else if (result == PermissionState.notDetermined) {
      result = await PhotoManager.requestPermissionExtend();
      if (result.isAuth) {
        _fetchNewMedia(currentPageValue: currentPageValue);
      }
    } else {
      setState(() => isGrantGalleryPermission = false);
    }
  }

  _changeAlbum(AssetPathEntity album) async {
    setState(() {
      isImagesReady.value = false;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      dataIndex.value = 0;
      selectedAlbum.value = album;
      _mediaList.value = [];
      mediaListByDate.value = {};
      allImages.value = [];
      currentPage.value = 0;
      lastPage.value = 0;
    });
    _fetchNewMedia(currentPageValue: 0);
  }

  _showLoadingSnackBar() {
    final snackBar = SnackBar(
      duration: const Duration(seconds: 15),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16,),
              Text(widget.tabsTexts.loading),
            ],
          ),
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<FutureBuilder<Uint8List?>> getImageGallery(
      List<AssetEntity> media, int i) async {
    bool highResolution = widget.gridDelegate.crossAxisCount <= 3;
    FutureBuilder<Uint8List?> futureBuilder = FutureBuilder(
      future: media[i].thumbnailDataWithSize(highResolution
          ? const ThumbnailSize(350, 350)
          : const ThumbnailSize(200, 200)),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          Uint8List? image = snapshot.data;
          if (image != null) {
            return Container(
              color: const Color.fromARGB(255, 189, 189, 189),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: MemoryImageDisplay(
                        imageBytes: image, appTheme: widget.appTheme),
                  ),
                  if (media[i].type == AssetType.video)
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 5, bottom: 5),
                        child: Icon(
                          Icons.slow_motion_video_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
        }
        return const SizedBox();
      },
    );
    return futureBuilder;
  }

  Future<File?> highQualityImage(List<AssetEntity> media, int i) async =>
      media[i].file;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return isGrantGalleryPermission ? noImages
        ? Center(
            child: Text(
              widget.tabsTexts.noImagesFounded,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          )
        : ValueListenableBuilder(
            valueListenable: widget.multiSelectedImages,
            builder: (context, List<AssetEntity> selectedImagesValue, child) {
              return Stack(
                children: [
                  buildGridView(),
                  // Positioned(
                  //   right: 24,
                  //   bottom: 24,
                  //   child: Visibility(
                  //     visible: selectedImagesValue.isNotEmpty,
                  //     child: clearSelectedImages()),
                  // ),
                ],
              );
          })
    : permissionRequestDescriptionView();
  }

  Widget permissionRequestDescriptionView() {

    return Center(
        child: FutureBuilder(
            future: getAppName(),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              if (snapshot.hasData) {
                return Column(
                  children: [
                    normalAppBar(isShowDone: false),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            widget.tabsTexts.requestPhotoAccessPermission
                                ?? "${snapshot.data} doesn’t have permission to access your photos. Please allow ${snapshot.data} to access your photos.",
                            style: const TextStyle(
                              color: Color(0xFF444444),
                              fontSize: 20,
                              fontFamily: 'Dosis',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.20,
                            ),
                          ),
                          const SizedBox(height: 24,),
                          Text(
                            widget.tabsTexts.requestPhotoAccessPermissionDescription
                                ?? 'Selecting “Allow” does not give ${snapshot.data} permission to upload photos without your knowledge or consent',
                            style: const TextStyle(
                              color: Color(0xFF444444),
                              fontSize: 18,
                              fontFamily: 'Dosis',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.08,
                            ),
                          ),
                          const SizedBox(height: 48,),
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: widget.appTheme.accentColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                              onPressed: () async {
                                await PhotoManager.requestPermissionExtend();
                                PhotoManager.openSetting();
                              },
                              child: Text(
                                widget.tabsTexts.changeSetting,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Dosis',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.60,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return const SizedBox();
              }
            }
        )
    );
  }

  Future<String> getAppName() async {
    return (await PackageInfo.fromPlatform()).appName;
  }

  ValueListenableBuilder<bool> buildGridView() {
    return ValueListenableBuilder(
      valueListenable: isImagesReady,
      builder: (context, bool isImagesReadyValue, child) {
        if (isImagesReadyValue) {
          return ValueListenableBuilder(
            valueListenable: _mediaList,
            builder: (context, List<FutureBuilder<Uint8List?>> mediaListValue,
                child) {
              return ValueListenableBuilder(
                valueListenable: mediaListByDate,
                builder: (context,
                    Map<String, List<(int, FutureBuilder<Uint8List?>)>>
                        mediaListByDateValue,
                    child) {
                  return ValueListenableBuilder(
                    valueListenable: lastPage,
                    builder: (context, int lastPageValue, child) => ValueListenableBuilder(
                      valueListenable: currentPage,
                      builder: (context, int currentPageValue, child) {
                        if (!widget.showImagePreview) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              normalAppBar(),
                              Flexible(
                                child: widget.byDate
                                    ? gridViewWithDate(mediaListByDateValue,
                                        currentPageValue, lastPageValue)
                                    : normalGridView(mediaListValue,
                                        currentPageValue, lastPageValue),
                              ),
                              uploadButton(),
                            ],
                          );
                        } else {
                          return instagramGridView(
                              mediaListValue, currentPageValue, lastPageValue);
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        } else {
          return loadingWidget();
        }
      },
    );
  }

  Widget uploadButton() {
    return Container(
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: widget.appTheme.accentColor,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: widget.multiSelectedImages.value.isEmpty ? null : () {
              done();
            },
            child: Text(widget.tabsTexts.done,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'Dosis',
                fontWeight: FontWeight.w700,
                height: 0,
                letterSpacing: 1.60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget loadingWidget() {
    return SingleChildScrollView(
      child: Column(
        children: [
          appBar(),
          Shimmer.fromColors(
            baseColor: widget.appTheme.shimmerBaseColor,
            highlightColor: widget.appTheme.shimmerHighlightColor,
            child: Column(
              children: [
                if (widget.showImagePreview) ...[
                  Container(
                      color: const Color(0xff696969),
                      height: 360,
                      width: double.infinity),
                  const SizedBox(height: 1),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: widget.gridDelegate.crossAxisSpacing),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    primary: false,
                    gridDelegate: widget.gridDelegate,
                    itemBuilder: (context, index) {
                      return Container(
                          color: const Color(0xff696969),
                          width: double.infinity);
                    },
                    itemCount: 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      backgroundColor: widget.appTheme.primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.clear_rounded,
            color: widget.appTheme.focusColor, size: 30),
        onPressed: () {
          Navigator.of(context).maybePop(null);
        },
      ),
    );
  }

  Widget normalAppBar({bool isShowDone = false}) {
    double width = MediaQuery.of(context).size.width;
    return ValueListenableBuilder(
        valueListenable: selectedAlbum,
        builder: (context, AssetPathEntity? selectedAlbumValue, child) {
          return Container(
            color: widget.whiteColor,
            height: 56,
            width: width,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                existButton(),
                const Spacer(),
                if (selectedAlbumValue != null) TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700
                    )
                  ),
                  onPressed: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      enableDrag: true,
                      barrierColor: Colors.black.withOpacity(0.5),
                      builder: (context) {
                        return albumListBottomSheet();
                      }
                    );
                  },
                  child: Row(
                    children: [
                      Text(selectedAlbumValue.name),
                      const SizedBox(width: 2,),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 28,
                        color: widget.appTheme.accentColor,
                      )
                    ],
                  ),
                ),
                const Spacer(),
                isShowDone ? doneButton() : const SizedBox(width: 30,),
              ],
            ),
          );
        });
  }

  Widget albumListBottomSheet() {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      margin: const EdgeInsets.only(top: 80),
      child: ListView.builder(
        itemCount: _cachedAlbums.length,
        itemBuilder: (context, index) {
          final album = _cachedAlbums[index];
          return SafeArea(
            child: ListTile(
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    FutureBuilder(
                      future: album.getAssetListPaged(page: 0, size: 1),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null
                            && snapshot.data!.isNotEmpty && snapshot.data!.first.type == AssetType.image) {
                          return FutureBuilder(future: snapshot.data!.first.file,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.file(
                                    snapshot.data!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  );
                                } else {
                                  return Container(width: 50, height: 50, color: Colors.grey,);
                                }
                              });
                        } else {
                          return Container(width: 50, height: 50, color: Colors.grey,);
                        }
                      }),
                    const SizedBox(width: 8,),
                    FutureBuilder(future: album.assetCountAsync, builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text('${album.name} (${snapshot.data})');
                      } else {
                        return const SizedBox();
                      }
                    }),
                    const Spacer(),
                    if (selectedAlbum.value == album) Icon(
                      Icons.check,
                      color: widget.appTheme.accentColor,
                    ),
                  ],
                ),
              ),
              onTap: () {
                _changeAlbum(album);
                Navigator.pop(context);
              },
            ),
          );
        }
      ),
    );
  }

  Widget clearSelectedImages() {
    return Stack(
      alignment: const Alignment(1.5, -1.5),
      children: [
        FloatingActionButton(
          onPressed: () {
            widget.clearMultiImages();
            widget.multiSelectedImages.value.clear();
          },
          shape: const CircleBorder(),
          foregroundColor: Colors.white,
          backgroundColor: widget.appTheme.accentColor,
          child: const Image(
              width: 32,
              height: 32,
              image: AssetImage('packages/image_picker_plus/assets/image_unselect.png')),
        ),
        ValueListenableBuilder(
          valueListenable: widget.multiSelectedImages,
          builder: (context, List<AssetEntity> selectedImagesValue, child) {
            return Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                height: 24,
                width: 24,
                decoration: BoxDecoration(
                  color: widget.appTheme.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                  ),
                ),
                child: Center(
                  child: Text(
                    "${selectedImagesValue.length}",
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              ),
            );
          }
        ),
      ],
    );
  }

  IconButton existButton() {
    return IconButton(
      icon: Icon(Icons.clear_rounded, color: widget.blackColor, size: 30),
      onPressed: () {
        Navigator.of(context).maybePop(null);
      },
    );
  }

  Future<void> done() async {
    double aspect = expandImage.value ? 6 / 8 : 1.0;
    if (widget.multiSelectionMode.value && widget.multiSelection) {
      if (areaOfCropsKeys.value.length !=
          widget.multiSelectedImages.value.length) {
        scaleOfCropsKeys.value.add(cropKey.value.currentState?.scale);
        areaOfCropsKeys.value.add(cropKey.value.currentState?.area);
      } else {
        if (indexOfLatestImage != -1) {
          scaleOfCropsKeys.value[indexOfLatestImage] =
              cropKey.value.currentState?.scale;
          areaOfCropsKeys.value[indexOfLatestImage] =
              cropKey.value.currentState?.area;
        }
      }

      List<SelectedByte> selectedBytes = [];
      for (int i = 0; i < widget.multiSelectedImages.value.length; i++) {
        File? currentImage = await widget.multiSelectedImages.value[i].file;
        if (currentImage == null) {
          continue;
        }
        String path = currentImage.path;
        bool isThatVideo = path.contains("mp4", path.length - 5);
        File? croppedImage = !isThatVideo && widget.cropImage
            ? await cropImage(currentImage, indexOfCropImage: i)
            : null;
        File image = croppedImage ?? currentImage;
        Uint8List byte = await image.readAsBytes();
        SelectedByte img = SelectedByte(
          isThatImage: !isThatVideo,
          selectedFile: image,
          selectedByte: byte,
          entity: widget.multiSelectedImages.value[i],
        );
        selectedBytes.add(img);
      }
      if (selectedBytes.isNotEmpty) {
        SelectedImagesDetails details = SelectedImagesDetails(
          selectedFiles: selectedBytes,
          multiSelectionMode: true,
          aspectRatio: aspect,
        );
        if (!mounted) return;

        if (widget.callbackFunction != null) {
          await widget.callbackFunction!(details);
        } else {
          Navigator.of(context).maybePop(details);
        }
      }
    } else {
      AssetEntity? imageEntity = selectedImage.value;
      File? image = await imageEntity?.file;
      if (image == null || imageEntity == null) return;
      String path = image.path;

      bool isThatVideo = path.contains("mp4", path.length - 5);
      File? croppedImage = !isThatVideo && widget.cropImage
          ? await cropImage(image)
          : null;
      File img = croppedImage ?? image;
      Uint8List byte = await img.readAsBytes();

      SelectedByte selectedByte = SelectedByte(
        isThatImage: !isThatVideo,
        selectedFile: img,
        selectedByte: byte,
        entity: selectedImage.value!,
      );
      SelectedImagesDetails details = SelectedImagesDetails(
        multiSelectionMode: false,
        aspectRatio: aspect,
        selectedFiles: [selectedByte],
      );
      if (!mounted) return;

      if (widget.callbackFunction != null) {
        await widget.callbackFunction!(details);
      } else {
        Navigator.of(context).maybePop(details);
      }
    }
  }

  Widget doneButton() {
    return ValueListenableBuilder(
      valueListenable: indexOfSelectedImages,
      builder: (context, List<int> indexOfSelectedImagesValue, child) =>
          IconButton(
        icon: Icon(Icons.arrow_forward_rounded,
            color: widget.appTheme.accentColor, size: 30),
        onPressed: () async {
          done();
        },
      ),
    );
  }

  Widget normalGridView(List<FutureBuilder<Uint8List?>> mediaListValue,
      int currentPageValue, int lastPageValue) {
    return NotificationListener(
      onNotification: (ScrollNotification notification) {
        _handleScrollEvent(notification,
            currentPageValue: currentPageValue, lastPageValue: lastPageValue);
        return true;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: widget.gridDelegate.crossAxisSpacing),
        child: GridView.builder(
          gridDelegate: widget.gridDelegate,
          itemBuilder: (context, index) {
            return buildImage(mediaListValue, index);
          },
          itemCount: mediaListValue.length,
        ),
      ),
    );
  }

  Widget gridViewWithDate(
      Map<String, List<(int, FutureBuilder<Uint8List?>)>> mediaListByDateValue,
      int currentPageValue,
      int lastPageValue) {
    return NotificationListener(
        onNotification: (ScrollNotification notification) {
          _handleScrollEvent(notification,
              currentPageValue: currentPageValue, lastPageValue: lastPageValue);
          return true;
        },
        child: SingleChildScrollView(
          child: Column(
            children: mediaListByDateValue.entries
                .map((e) => gridViewByDate(e.key, e.value))
                .toList(),
          ),
        ));
  }

  Widget gridViewByDate(
      String dateLabel, List<(int, FutureBuilder<Uint8List?>)> mediaList) {
    return Column(
      children: [
        dateSectionHeader(dateLabel, mediaList),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: widget.gridDelegate.crossAxisSpacing),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: widget.gridDelegate,
            itemBuilder: (context, index) {
              return buildImage(
                  mediaList.map((e) => e.$2).toList(), mediaList[index].$1);
            },
            itemCount: mediaList.length,
          ),
        ),
      ],
    );
  }

  Widget dateSectionHeader(
      String date, List<(int, FutureBuilder<Uint8List?>)> mediaList) {
    return ValueListenableBuilder(
        valueListenable: allImages,
        builder: (context, List<AssetEntity?> allImagesValue, child) {
          if (allImagesValue.length < mediaList.length) {
            return const SizedBox();
          }
          List<(AssetEntity?, int)> allImagesInDate;
          try {
            allImagesInDate =
              mediaList.map((e) => (allImagesValue[e.$1], e.$1)).toList();
          } catch (e) {
            log(e.toString());
            return const SizedBox();
          }
          onTapDateHeader({
              required List<(AssetEntity?, int)> allImagesInDate,
              required List<AssetEntity> selectedImagesValue,
              required bool forceRemove,
              required bool forceAdd,
            }) {
              for (var image in allImagesInDate) {
                if (image.$1 != null) {
                  selectionImageCheck(image.$1!, selectedImagesValue, image.$2,
                    forceRemove: forceRemove, forceAdd: forceAdd);
                }
              }
            }

          return ValueListenableBuilder(
              valueListenable: isImagesReady,
              builder: (context, bool isImagesReadyValue, child) {
                return ValueListenableBuilder(
                    valueListenable: widget.multiSelectedImages,
                    builder: (context, List<AssetEntity> selectedImagesValue, child) {
                      bool imageSelected = allImagesInDate.every((element) =>
                          selectedImagesValue.contains(element.$1));
                      return Container(
                        color: widget.appTheme.backgroundColor,
                        height: 48,
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(DateTime.parse(date).toMMMdy(widget.appTheme.locale)),
                            ),
                            InkWell(
                              onTap: () => onTapDateHeader(
                                allImagesInDate: allImagesInDate,
                                selectedImagesValue: selectedImagesValue,
                                forceRemove: imageSelected,
                                forceAdd: !imageSelected,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Container(
                                  height: 25,
                                  width: 25,
                                  decoration: BoxDecoration(
                                    color: imageSelected
                                        ? widget.appTheme.accentColor
                                        : const Color.fromARGB(
                                            115, 222, 222, 222),
                                    border: Border.all(
                                      color: Colors.white,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: imageSelected ?
                                    const Icon(Icons.check, size: 18, color: Colors.white,)
                                    : Container(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    });
              });
        });
  }

  ValueListenableBuilder<AssetEntity?> buildImage(
      List<FutureBuilder<Uint8List?>> mediaListValue, int index) {
    return ValueListenableBuilder(
      valueListenable: selectedImage,
      builder: (context, AssetEntity? selectedImageValue, child) {
        return ValueListenableBuilder(
          valueListenable: allImages,
          builder: (context, List<AssetEntity?> allImagesValue, child) {
            return ValueListenableBuilder(
              valueListenable: _mediaList,
              builder: (context, List<FutureBuilder<Uint8List?>> mediaListValue, child) {
                return ValueListenableBuilder(
                  valueListenable: widget.multiSelectedImages,
                  builder: (context, List<AssetEntity> selectedImagesValue, child) {
                    if (mediaListValue.length < index + 1) {
                      return const SizedBox();
                    }
                    FutureBuilder<Uint8List?> mediaList = mediaListValue[index];
                    AssetEntity? image = allImagesValue[index];
                    if (image != null) {
                      bool imageSelected = selectedImagesValue.contains(image);
                      List<AssetEntity> multiImages = selectedImagesValue;
                      return Stack(
                        children: [
                          ChildGridViewImage(
                            image: image,
                            index: index,
                            childWidget: mediaList,
                            onTap: onTapImage,
                            multiSelectedImages: widget.multiSelectedImages,
                            multiSelectionMode: widget.multiSelectionMode,
                            appTheme: widget.appTheme,
                          ),
                          if (selectedImageValue == image)
                            IgnorePointer(ignoring: true, child: blurContainer()),
                          IgnorePointer(
                            ignoring: true,
                            child: MultiSelectionMode(
                              image: image,
                              multiSelectionMode: widget.multiSelectionMode,
                              imageSelected: imageSelected,
                              multiSelectedImage: multiImages,
                              appTheme: widget.appTheme,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return const SizedBox();
                    }
                  },
                );
              }
            );
          },
        );
      },
    );
  }

  Container blurContainer() {
    return Container(
      width: double.infinity,
      color: const Color.fromARGB(184, 234, 234, 234),
      height: double.maxFinite,
    );
  }

  onTapImage(AssetEntity image, List<AssetEntity> selectedImagesValue, int index) {
    setState(() {
      if (widget.multiSelectionMode.value) {
        bool close = selectionImageCheck(image, selectedImagesValue, index);
        if (close) return;
      }
      selectedImage.value = image;
      expandImageView.value = false;
      moveAwayHeight.value = 0;
      enableVerticalTapping.value = false;
      noPaddingForGridView = true;
    });
  }

  bool selectionImageCheck(
      AssetEntity image, List<AssetEntity> multiSelectionValue, int index,
      {bool enableCopy = false,
      bool forceAdd = false,
      bool forceRemove = false}) {
    if (multiSelectionValue.contains(image) &&
        ((selectedImage.value == image && !forceAdd) || forceRemove)) {
      setState(() {
        if (forceRemove) {
          selectedImage.value = null;
        }
        int indexOfImage =
            multiSelectionValue.indexWhere((element) => element == image);
        multiSelectionValue.removeAt(indexOfImage);
        if (multiSelectionValue.isNotEmpty &&
            indexOfImage < scaleOfCropsKeys.value.length) {
          indexOfSelectedImages.value.remove(index);

          scaleOfCropsKeys.value.removeAt(indexOfImage);
          areaOfCropsKeys.value.removeAt(indexOfImage);
          indexOfLatestImage = -1;
        }
      });

      return true;
    } else {
      if (multiSelectionValue.contains(image) && forceAdd) {
        return false;
      }
      if (multiSelectionValue.length < widget.maximumSelection) {
        setState(() {
          if (!multiSelectionValue.contains(image)) {
            multiSelectionValue.add(image);
            if (multiSelectionValue.length > 1) {
              scaleOfCropsKeys.value.add(cropKey.value.currentState?.scale);
              areaOfCropsKeys.value.add(cropKey.value.currentState?.area);
              indexOfSelectedImages.value.add(index);
            }
          } else if (areaOfCropsKeys.value.length !=
              multiSelectionValue.length) {
            scaleOfCropsKeys.value.add(cropKey.value.currentState?.scale);
            areaOfCropsKeys.value.add(cropKey.value.currentState?.area);
          }
          if (widget.showImagePreview && multiSelectionValue.contains(image)) {
            int index =
                multiSelectionValue.indexWhere((element) => element == image);
            if (indexOfLatestImage != -1) {
              scaleOfCropsKeys.value[indexOfLatestImage] =
                  cropKey.value.currentState?.scale;
              areaOfCropsKeys.value[indexOfLatestImage] =
                  cropKey.value.currentState?.area;
            }
            indexOfLatestImage = index;
          }

          if (enableCopy) selectedImage.value = image;
        });
      }
      return false;
    }
  }

  Future<File?> cropImage(File imageFile, {int? indexOfCropImage}) async {
    await ImageCrop.requestPermissions();
    final double? scale;
    final Rect? area;
    if (indexOfCropImage == null) {
      scale = cropKey.value.currentState?.scale;
      area = cropKey.value.currentState?.area;
    } else {
      scale = scaleOfCropsKeys.value[indexOfCropImage];
      area = areaOfCropsKeys.value[indexOfCropImage];
    }

    if (area == null || scale == null) return null;

    final sample = await ImageCrop.sampleImage(
      file: imageFile,
      preferredSize: (2000 / scale).round(),
    );

    final File file = await ImageCrop.cropImage(
      file: sample,
      area: area,
    );
    sample.delete();
    return file;
  }

  void clearMultiImages() {
    setState(() {
      widget.multiSelectedImages.value = [];
      widget.clearMultiImages();
      indexOfSelectedImages.value.clear();
      scaleOfCropsKeys.value.clear();
      areaOfCropsKeys.value.clear();
    });
  }

  Widget instagramGridView(List<FutureBuilder<Uint8List?>> mediaListValue,
      int currentPageValue, int lastPageValue) {
    return ValueListenableBuilder(
      valueListenable: expandHeight,
      builder: (context, double expandedHeightValue, child) {
        return ValueListenableBuilder(
          valueListenable: moveAwayHeight,
          builder: (context, double moveAwayHeightValue, child) =>
              ValueListenableBuilder(
            valueListenable: expandImageView,
            builder: (context, bool expandImageValue, child) {
              double a = expandedHeightValue - 360;
              double expandHeightV = a < 0 ? a : 0;
              double moveAwayHeightV =
                  moveAwayHeightValue < 360 ? moveAwayHeightValue * -1 : -360;
              double topPosition =
                  expandImageValue ? expandHeightV : moveAwayHeightV;
              enableVerticalTapping.value = !(topPosition == 0);
              double padding = 2;
              if (scrollPixels < 416) {
                double pixels = 416 - scrollPixels;
                padding = pixels >= 58 ? pixels + 2 : 58;
              } else if (expandImageValue) {
                padding = 58;
              } else if (noPaddingForGridView) {
                padding = 58;
              } else {
                padding = topPosition + 418;
              }
              int duration = noDuration.value ? 0 : 250;

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: padding),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        expandImageView.value = false;
                        moveAwayHeight.value = scrollController.position.pixels;
                        scrollPixels = scrollController.position.pixels;
                        setState(() {
                          isScrolling = true;
                          noPaddingForGridView = false;
                          noDuration.value = false;
                          if (notification is ScrollEndNotification) {
                            expandHeight.value =
                                expandedHeightValue > 240 ? 360 : 0;
                            isScrolling = false;
                          }
                        });

                        _handleScrollEvent(notification,
                            currentPageValue: currentPageValue,
                            lastPageValue: lastPageValue);
                        return true;
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: widget.gridDelegate.crossAxisSpacing),
                        child: GridView.builder(
                          gridDelegate: widget.gridDelegate,
                          controller: scrollController,
                          itemBuilder: (context, index) {
                            return buildImage(mediaListValue, index);
                          },
                          itemCount: mediaListValue.length,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    top: topPosition,
                    duration: Duration(milliseconds: duration),
                    child: Column(
                      children: [
                        normalAppBar(),
                        CropImageView(
                          cropKey: cropKey,
                          indexOfSelectedImages: indexOfSelectedImages,
                          selectedImage: selectedImage,
                          appTheme: widget.appTheme,
                          multiSelectionMode: widget.multiSelectionMode,
                          enableVerticalTapping: enableVerticalTapping,
                          expandHeight: expandHeight,
                          expandImage: expandImage,
                          expandImageView: expandImageView,
                          noDuration: noDuration,
                          clearMultiImages: clearMultiImages,
                          topPosition: topPosition,
                          whiteColor: widget.whiteColor,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
