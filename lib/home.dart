import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brotli/brotli.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pool/pool.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  bool loading = true;
  late List allData;
  late List data;
  List userLikes = [];
  int scrollPosition = 0;
  int loadedItems = 50;
  final wikiCache = CacheManager(
    Config(
      'wikiImages',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      fileService: RestrictedHttpFileService(),
    ),
  );
  ScrollController mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchData();
    mainScrollController.addListener(() {
      if (mainScrollController.position.pixels >= mainScrollController.position.maxScrollExtent - 200) {
        _loadMoreItems();
      }
    });
  }
  void fetchData() async{
    allData = (await loadData())['pages'] as List;
    allData.shuffle();
    data = allData.sublist(scrollPosition, scrollPosition += loadedItems);
    scrollPosition += loadedItems;
    setState(() {
      loading = false;
    });
  }

  void _loadMoreItems() {
    setState(() {
      data.addAll(allData.sublist(scrollPosition, scrollPosition += loadedItems));
      scrollPosition += loadedItems;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return CircularProgressIndicator();
    }
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView.builder(
            controller: mainScrollController,
            cacheExtent: 1,
            itemCount: data.length,
            itemBuilder: (context, index) {
              bool liked = userLikes.contains(data[index][1]);
              return WikiPost(postData: data[index], liked: liked, cacheManager: wikiCache, onLike: (){
                setState(() {
                  if (liked){
                    userLikes.remove(data[index][1]);
                  } else {
                    userLikes.add(data[index][1]);
                  }
                });
              });
            }
            ),
        )
      ),
    );
  }
}

class WikiPost extends StatefulWidget {
  final List postData;
  final bool liked;
  final VoidCallback onLike;
  final BaseCacheManager cacheManager;

  const WikiPost({
    super.key, 
    required this.postData, 
    required this.liked, 
    required this.onLike,
    required this.cacheManager,
  });

  @override
  State<WikiPost> createState() => _WikiPostState();
}

class _WikiPostState extends State<WikiPost> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String? imageUrl;
  @override
  void initState() {
    super.initState();
    if (widget.postData[3] != null){
      imageUrl = fileToUrl((widget.postData[3]).replaceAll(' ', '_'));
    }
  }

  @override
  void dispose() {
    if (widget.cacheManager is CacheManager && imageUrl != null) {
      final manager = widget.cacheManager as CacheManager;
      if (manager.config.fileService is RestrictedHttpFileService) {
        (manager.config.fileService as RestrictedHttpFileService).cancel(imageUrl!);
      }
    }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.postData[0],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(widget.postData[2]),
        if (widget.postData[3] != null && mounted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                imageUrl: fileToUrl((widget.postData[3] as String).replaceAll(' ', '_')),
                httpHeaders: const {
                  'User-Agent': 'XikipediaMobile/1.0 (https://github.com/GalaxiMaster/xikipedia_app; dmj08bot@gmail.com) BasedOnFlutter',
                },
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                cacheManager: widget.cacheManager,
                fadeInDuration: const Duration(milliseconds: 200),
                errorWidget: (context, url, error) {
                  debugPrint('Image failed to load: $url, $error');
                  return const Icon(Icons.close, color: Colors.grey);
                },
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: widget.onLike,
            icon: Icon(widget.liked ? Icons.favorite : Icons.favorite_outline),
          ),
        ),
        const Divider(thickness: 2),
      ],
    );
  }
}

class RestrictedHttpFileService extends HttpFileService {
  final Pool _pool = Pool(10);
  final Map<String, Completer<void>> _activeRequests = {};

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    final cancelSignal = Completer<void>();
    _activeRequests[url] = cancelSignal;

    return _pool.withResource(() async {
      if (cancelSignal.isCompleted) {
        throw Exception("Request cancelled before start");
      }
      
      try {
        final response = await super.get(url, headers: headers);
        return response;
      } finally {
        _activeRequests.remove(url);
      }
    });
  }

  void cancel(String url) {
    _activeRequests[url]?.complete();
  }
}

String fileToUrl(String filename) {
  final fname = filename.replaceAll(' ', '_');
  return 'https://commons.wikimedia.org/w/thumb.php?f=${Uri.encodeComponent(fname)}&w=512';
}

Future<Map> loadData() async {
  final bytes = await rootBundle.load('assets/smoldata.json.br');
  final decompressed = brotli.decode(bytes.buffer.asUint8List());
  return jsonDecode(utf8.decode(decompressed));
}