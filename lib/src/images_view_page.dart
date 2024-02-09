import 'dart:io';

import 'package:image_picker_plus/image_picker_plus.dart';
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
  final ValueNotifier<List<File>> multiSelectedImages;
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

  ValueNotifier<List<File?>> allImages = ValueNotifier([]);

  ValueNotifier<Map<String, List<(int, FutureBuilder<Uint8List?>)>>>
      mediaListByDate = ValueNotifier({});

  final ValueNotifier<List<double?>> scaleOfCropsKeys = ValueNotifier([]);
  final ValueNotifier<List<Rect?>> areaOfCropsKeys = ValueNotifier([]);

  ValueNotifier<File?> selectedImage = ValueNotifier(null);
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
      _showLoadingSnackBar();
    }  
    lastPage.value = currentPageValue;

    PermissionState result = await PhotoManager.requestPermissionExtend();
    if (result.isAuth) {
      setState(() => isGrantGalleryPermission = true);
      RequestType type = widget.showInternalVideos && widget.showInternalImages
          ? RequestType.common
          : (widget.showInternalImages ? RequestType.image : RequestType.video);

      if (_cachedAlbums.isEmpty) {
        _cachedAlbums =
          await PhotoManager.getAssetPathList(onlyAll: true, type: type);
        if (_cachedAlbums.isEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => setState(() => noImages = true));
          return;
        } else if (noImages) {
          noImages = false;
        }
      }
      List<AssetEntity> media =
          await _cachedAlbums[0].getAssetListPaged(page: currentPageValue, size: currentPageValue <= 1 ? 20 : 60);
      List<FutureBuilder<Uint8List?>> temp = [];
      List<File?> imageTemp = [];

      for (int i = 0; i < media.length; i++) {
        FutureBuilder<Uint8List?> gridViewImage =
            await getImageGallery(media, i);
        File? image = await highQualityImage(media, i);
        DateTime exifDate = media[i].createDateTime;
        mediaListByDate.value.update(
          exifDate.toYyyyMMdd,
          (value) => [...value, (dataIndex.value, gridViewImage)],
          ifAbsent: () => [(dataIndex.value, gridViewImage)],
        );
        temp.add(gridViewImage);
        imageTemp.add(image);
        dataIndex.value++;
      }
      _mediaList.value.addAll(temp);
      allImages.value.addAll(imageTemp);
      currentPage.value++;
      isImagesReady.value = true;
      isFetchLoading.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else {
      setState(() => isGrantGalleryPermission = false);
    }
  }

  _showLoadingSnackBar() {
    const snackBar = SnackBar(
      duration: Duration(seconds: 15),
      content: Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16,),
              Text('loading...'),
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
        : buildGridView()
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
                            "${snapshot.data} doesn’t have permission to access your photos. Please allow ${snapshot.data} to access your photos.",
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
                            'Selecting “Allow” does not give ${snapshot.data} permission to upload photos without your knowledge or consent',
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
                                PhotoManager.openSetting();
                              },
                              child: const Text(
                                'CHANGE SETTINGS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
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
                    builder: (context, int lastPageValue, child) =>
                        ValueListenableBuilder(
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
                              )
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

  Widget normalAppBar({bool isShowDone = true}) {
    double width = MediaQuery.of(context).size.width;
    return Container(
      color: widget.whiteColor,
      height: 56,
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          existButton(),
          const Spacer(),
          if (isShowDone) doneButton(),
        ],
      ),
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

  Widget doneButton() {
    return ValueListenableBuilder(
      valueListenable: indexOfSelectedImages,
      builder: (context, List<int> indexOfSelectedImagesValue, child) =>
          IconButton(
        icon: Icon(Icons.arrow_forward_rounded,
            color: widget.appTheme.accentColor, size: 30),
        onPressed: () async {
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
              File currentImage = widget.multiSelectedImages.value[i];
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
            File? image = selectedImage.value;
            if (image == null) return;
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
        builder: (context, List<File?> allImagesValue, child) {
          final allImagesInDate =
              mediaList.map((e) => (allImages.value[e.$1], e.$1)).toList();
          onTapDateHeader({
            required List<(File?, int)> allImagesInDate,
            required List<File> selectedImagesValue,
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
                    builder: (context, List<File> selectedImagesValue, child) {
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
                              child: Text(DateTime.parse(date).toMMMdy),
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

  ValueListenableBuilder<File?> buildImage(
      List<FutureBuilder<Uint8List?>> mediaListValue, int index) {
    return ValueListenableBuilder(
      valueListenable: selectedImage,
      builder: (context, File? selectedImageValue, child) {
        return ValueListenableBuilder(
          valueListenable: allImages,
          builder: (context, List<File?> allImagesValue, child) {
            return ValueListenableBuilder(
              valueListenable: widget.multiSelectedImages,
              builder: (context, List<File> selectedImagesValue, child) {
                FutureBuilder<Uint8List?> mediaList = _mediaList.value[index];
                File? image = allImagesValue[index];
                if (image != null) {
                  bool imageSelected = selectedImagesValue.contains(image);
                  List<File> multiImages = selectedImagesValue;
                  return Stack(
                    children: [
                      gestureDetector(image, index, mediaList),
                      if (selectedImageValue == image)
                        gestureDetector(image, index, blurContainer()),
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
                  return Container();
                }
              },
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

  Widget gestureDetector(File image, int index, Widget childWidget) {
    return ValueListenableBuilder(
      valueListenable: widget.multiSelectionMode,
      builder: (context, bool multipleValue, child) => ValueListenableBuilder(
        valueListenable: widget.multiSelectedImages,
        builder: (context, List<File> selectedImagesValue, child) =>
            GestureDetector(
                onTap: () => onTapImage(image, selectedImagesValue, index),
                onLongPressUp: () {
                  if (multipleValue) {
                    selectionImageCheck(image, selectedImagesValue, index,
                        enableCopy: true);
                    expandImageView.value = false;
                    moveAwayHeight.value = 0;

                    enableVerticalTapping.value = false;
                    setState(() => noPaddingForGridView = true);
                  } else {
                    onTapImage(image, selectedImagesValue, index);
                  }
                },
                child: childWidget),
      ),
    );
  }

  onTapImage(File image, List<File> selectedImagesValue, int index) {
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
      File image, List<File> multiSelectionValue, int index,
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
