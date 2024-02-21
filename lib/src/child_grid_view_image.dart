import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../image_picker_plus.dart';

class ChildGridViewImage extends StatefulWidget {
  const ChildGridViewImage({
    super.key,
    required this.image,
    required this.index,
    required this.childWidget,
    required this.onTap,
    required this.multiSelectedImages,
    required this.multiSelectionMode,
    required this.appTheme
  });

  final AssetEntity image;
  final int index;
  final Widget childWidget;
  final Function(AssetEntity, List<AssetEntity>, int) onTap;
  final ValueNotifier<List<AssetEntity>> multiSelectedImages;
  final ValueNotifier<bool> multiSelectionMode;
  final AppTheme appTheme;

  @override
  _ChildGridViewImageState createState() => _ChildGridViewImageState();
}

class _ChildGridViewImageState extends State<ChildGridViewImage>
    with SingleTickerProviderStateMixin {

  late AnimationController _longTapAnimationController;
  late Animation<double> _longTapScale;

  @override
  void initState() {
    _longTapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _longTapScale = _longTapAnimationController
        .drive(
          CurveTween(curve: Curves.bounceOut),
        )
        .drive(
          Tween(begin: 1, end: 0.8),
        );
    super.initState();
  }

  @override
  void dispose() {
    _longTapAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.multiSelectionMode,
      builder: (context, bool multipleValue, child) => ValueListenableBuilder(
        valueListenable: widget.multiSelectedImages,
        builder: (context, List<AssetEntity> selectedImagesValue, child) =>
            GestureDetector(
                onTap: () => widget.onTap(widget.image, selectedImagesValue, widget.index),
                onLongPress: () async {
                  await _forwardAnimation();
                  if (mounted) {
                    await Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        fullscreenDialog: true,
                        barrierDismissible: true,
                        barrierColor: Colors.black.withOpacity(0.5),
                        pageBuilder: (BuildContext context, _, __) {
                          return Scaffold(
                            backgroundColor: Colors.transparent,
                            floatingActionButtonLocation:
                              FloatingActionButtonLocation.startTop,
                            floatingActionButton: FloatingActionButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              shape: const CircleBorder(),
                              foregroundColor: Colors.white,
                              backgroundColor: widget.appTheme.accentColor,
                              child: const Icon(Icons.close),
                            ),
                            body: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Center(
                                child: Hero(
                                    tag: widget.image,
                                    child: FutureBuilder(
                                        future: widget.image.file,
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData && snapshot.data != null) {
                                            return Image.file(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            );
                                          } else {
                                            return const SizedBox();
                                          }
                                        })
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
                child: ScaleTransition(
                  scale: _longTapScale,
                  child: Hero(
                    tag: widget.image,
                    child: widget.childWidget,
                  ),
                )),
      ),
    );
  }

  Future<void> _forwardAnimation() async {
    await _longTapAnimationController.forward().whenComplete(() async {
      HapticFeedback.mediumImpact();
      _longTapAnimationController.reverse();
    });
  }
}
