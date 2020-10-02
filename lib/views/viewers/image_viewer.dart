import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewer extends StatefulWidget {
  final value;

  ImageViewer({Key key, @required this.value}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ImageViewerState(value);
}

class _ImageViewerState extends State<ImageViewer> {
  var value;
  List _urlList = [];
  int _curIndex = 0;
  PageController _pc;

  _ImageViewerState(value) {
    this.value = value;
    _urlList = value["UrlList"];
    print(_urlList);
    _curIndex = value["CurIndex"];
    _pc = new PageController(
      initialPage: _curIndex,
      viewportFraction: 1,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String pageTitle =
        (_curIndex + 1).toString() + "/" + _urlList.length.toString();

    return new Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
      ),
      body: Container(
          child: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(_urlList[index]),
            initialScale: PhotoViewComputedScale.contained,
          );
        },
        itemCount: _urlList.length,
        loadingBuilder: (context, event) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                (_curIndex + 1).toString(),
                textScaleFactor: 3,
                style: TextStyle(color: Colors.grey.withAlpha(127)),
              ),
              SizedBox(
                height: 35,
              ),
              CircularProgressIndicator(
                value: event == null
                    ? 0
                    : event.cumulativeBytesLoaded / event.expectedTotalBytes,
              ),
            ],
          ),
        ),
        pageController: _pc,
        onPageChanged: (index) {
          setState(() {
            _curIndex = index;
          });
        },
      )),
    );
  }
}
