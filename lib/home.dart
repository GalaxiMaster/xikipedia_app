import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brotli/brotli.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  bool loading = true;
  late List data;
  List userLikes = [];
  final wikiCache = CacheManager(
    Config(
      'wikiImages',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );


  @override
  void initState() {
    super.initState();
    fetchData();
  }
  void fetchData() async{
    final temp = (await loadData())['pages'] as List;
    temp.shuffle();
    data = temp.sublist(490, 500);
    setState(() {
      loading = false;
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
            itemCount: data.length,
            itemBuilder: (context, index) {
              bool liked = userLikes.contains(data[index][1]);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data[index][0],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20
                    ),
                  ),
                  Text(data[index][2]),
                  if (data[index][3] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadiusGeometry.circular(15),
                      child: CachedNetworkImage(
                        imageUrl: 'https://commons.wikimedia.org/w/index.php?title=Special:Redirect/file/${(data[index][3]as String).replaceAll('/ /g', '_')}&width=512',
                        cacheManager: wikiCache,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: (){
                        setState(() {
                          if (liked){
                            userLikes.remove(data[index][1]);
                          } else {
                            userLikes.add(data[index][1]);
                          }
                        });
                      },
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_outline,
                      )
                    ),
                  ),
                  Divider(thickness: 2,)
                ],
              );
            }
            ),
        )
      ),
    );
  }
}

Future<Map> loadData() async {
  final bytes = await rootBundle.load('assets/smoldata.json.br');
  final decompressed = brotli.decode(bytes.buffer.asUint8List());
  return jsonDecode(utf8.decode(decompressed));
}