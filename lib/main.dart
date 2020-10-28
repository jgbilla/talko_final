import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(MyApp());
}

List<CameraDescription> cameras;

List<String> labelTexts = new List();

List<String> language = new List();

List<String> selectedItems = new List();
// This widget is the home page of your application. It is stateful, meaning
// that it has a State object (defined below) that contains fields that affect
// how it looks.

// This class is the configuration for the state. It holds the values (in this
// case the title) provided by the parent (in this case the App widget) and
// used by the build method of the State. Fields in a Widget subclass are
// always marked "final".

List<String> sentences = new List();

List<String> translated = new List();

GoogleTranslator _translator = new GoogleTranslator();

Future<String> getImagePath() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String path = prefs.getString("path");
  return path;
}

Future<String> getLanguagePreference() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String language = prefs.getString("language");
  return language;
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

Future<bool> saveImagePath(String path) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('path', path);
}


Future<bool> saveLanguagePreference(String language) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('language', language);
}

class Camera extends StatefulWidget {
  @override
  _CameraState createState() => _CameraState();
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: Splashscreen(),
    );
  }
}

class MyList extends StatefulWidget {
  @override
  _MyListState createState() => _MyListState();
}

class ShowWords extends StatefulWidget {
  @override
  _ShowWordsState createState() => _ShowWordsState();
}

class Splashscreen extends StatefulWidget {
  @override
  _SplashscreenState createState() => _SplashscreenState();
}

class Word {
  String language, selectedItem, translated;

  Word(this.language, this.selectedItem, this.translated);
}

class _CameraState extends State<Camera> {
  File file;
  var language;
  String example;
  CameraController controller;
  String imagePath;
  var _currentItemSelected = 'Auto';
  List data;
  var _languageList = [
    'Auto',
    'Af',
    'Sq',
    'Am',
    'Ar',
    'Hy',
    'Az',
    'Eu',
    'Be',
    'Bn',
    'Bs',
    'Bg',
    'Fr'
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(),
      drawer: Drawer(
          child: ListView(children: <Widget>[
        UserAccountsDrawerHeader(
            accountName: Text('Jean Billa'),
            accountEmail: Text('billajean43@gmail.com'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text("J", style: TextStyle(fontSize: 40.0)),
            )),
        ListTile(
            title: Text('My List'),
            onTap: () {
              Navigator.push(context,
                  new MaterialPageRoute(builder: (context) => new MyList()));
            }),
        ListTile(title: Text('Settings')),
        ListTile(title: Text('Profile')),
        DropdownButton<String>(
          items: _languageList.map((String dropDownStringItem) {
            return DropdownMenuItem<String>(
              value: dropDownStringItem,
              child: Text(dropDownStringItem),
            );
          }).toList(),
          onChanged: (String newValueSelected) {
            _onDropDownItemSelected(newValueSelected);
            saveLanguage();
          },
          value: _currentItemSelected,
        ),
      ])),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
            ),
          ),
          _captureControlRowWidget(),
        ],
      ),
    );
  }

  Future<void> detectLabels() async {
    final FirebaseVisionImage visionImage =
        FirebaseVisionImage.fromFilePath(imagePath);
    final LabelDetector labelDetector = FirebaseVision.instance.labelDetector();
    final List<Label> labels = await labelDetector.detectInImage(visionImage);

    for (Label label in labels) {
      final String text = label.label;
      labelTexts.add(text);
    }

    await _addItem(labelTexts);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  void onTakePictureButtonPressed() {
    saveFilePath();
    final StorageReference firebaseStorageRef =
        FirebaseStorage.instance.ref().child('myimage.jpg');
    final StorageUploadTask task = firebaseStorageRef.putFile(file);

    detectLabels().then((_) {
      Navigator.push(context,
          new MaterialPageRoute(builder: (context) => new ShowWords()));
    });
  }

  void saveFilePath() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
          file = File(imagePath);
          saveImagePath(imagePath);
        });
      }
      if (filePath != null) showInSnackBar('Picture saved to $filePath');
    });
  }

  void saveLanguage() {
    String language = this._currentItemSelected;
    saveLanguagePreference(language).then((bool commited) {});
  }

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }

    return filePath;
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _addItem(List<String> labels) async {
    await Firestore.instance
        .collection('items')
        .add(<String, dynamic>{'labels': labels});
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      );
    }
  }

  /// Display the control bar with buttons to take pictures.
  Widget _captureControlRowWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: controller != null && controller.value.isInitialized
              ? onTakePictureButtonPressed
              : null,
        )
      ],
    );
  }

  void _onDropDownItemSelected(String newValueSelected) {
    setState(() {
      this._currentItemSelected = newValueSelected;
    });
  }

  Future<void> _SaveSelectedItems(List<String> language,
      List<String> translated, List<String> selectedItems) async {
    await Firestore.instance.collection('selecteditems').add(<String, dynamic>{
      'selectedItems': selectedItems,
      'translated': translated,
      'language': language
    });
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class _MyListState extends State<MyList> {
  List<Word> wordsList = [];

  final String url = "https://wordsapiv1.p.rapidapi.com/words/{fun}/examples";

  final Firestore firestore;

  _MyListState({this.firestore});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
          title: new Text("My List"),
        ),
        body: StreamBuilder(
            stream: Firestore.instance.collection('selecteditems').snapshots(),
            builder:
                (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData)
                return Text('Loading data... Please Wait..');
              return new ListView(
                children: snapshot.data.documents.map((document) {
                  return new ListTile(
                      title: new Text(document['selectedItem']),
                      subtitle: new Text(document['translated']),
                      trailing: new Text(document['language']),
                      leading: new IconButton(
                          icon: Icon(Icons.speaker),
                          onPressed: () {
                            _speak(
                                document['language'], document['translated']);
                          }));
                }).toList(),
              );
            }));
  }

  Future getPosts() async {
    var firestore = Firestore.instance;
    QuerySnapshot qn =
        await firestore.collection("selecteditems").getDocuments();
    return qn.documents;
  }

  void initState() {
    DatabaseReference wordRef =
        FirebaseDatabase.instance.reference().child("selecteditems");

    wordRef.once().then((DataSnapshot snap) {
      var KEYS = snap.value.keys;
      var DATA = snap.value;

      for (var individualKey in KEYS) {
        Word word = new Word(
            DATA[individualKey]['language'],
            DATA[individualKey]['selectedItem'],
            DATA[individualKey]['translated']);

        wordsList.add(word);
      }

      setState(() {
        print('Length : $wordsList.length');
      });
    });
    super.initState();
  }

  Widget WordUI(String language, String selectedItem, String translated) {
    return new Card(
      elevation: 10.0,
      margin: EdgeInsets.all(15.0),
      child: Column(children: <Widget>[
        new Text(
          selectedItem,
        ),
        new Text(
          translated,
        ),
        new Text(
          language,
        )
      ]),
    );
  }

  Future _speak(String language, String word) async {
    FlutterTts flutterTts = new FlutterTts();
    await flutterTts.setLanguage(language);
    await flutterTts.setVolume(1.0);

    var result = await flutterTts.speak(word);
    return result;
  }
}

class _ShowWordsState extends State<ShowWords> {
  String _language = "";
  String TranslatedText;
  String _data;
  String example;

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Save')),
        key: _scaffoldKey,
        body: ListView(
          padding: EdgeInsets.all(10.0),
          children: labelTexts
              .map((data) => ListTile(
                  title: Text(data),
                  onTap: () {
                    setState(() {
                      getExample("$data");
                      _data = data;
                      selectedItems.contains(data)
                          ? _scaffoldKey.currentState.showSnackBar(SnackBar(
                              content: Text("$data is already in your list"),
                              duration: Duration(seconds: 1)))
                          : selectedItems.add("$data");
                      _translator
                          .translate("$data", from: 'auto', to: _language)
                          .then((finalText) {
                        TranslatedText = finalText;
                        translated.add(TranslatedText);
                        _SaveSelectedItems(
                            "$data", TranslatedText, _language, example);
                      });
                    });
                  }))
              .toList(),
        ));
  }

  Future<String> getExample(data) async {
    final String url =
        ' https://wordsapiv1.p.rapidapi.com/words/{fun}/examples';
    final response = await http.get(url, headers: {
      "X-RapidAPI-Host": "wordsapiv1.p.rapidapi.com",
      "X-RapidAPI-Key": "090f484413msh60801635e7e129ap19d86ejsn019184d9572e",
      "Accept": "application/json"
    });

    if (response.statusCode == 200) {
      setState(() {
        var responseJSON = json.decode(response.body);
        data = responseJSON["examples"];
        example = data[1];
      });
      return example;
    } else {
      showInSnackBar('Failed');
    }
  }

  @override
  void initState() {
    getLanguagePreference().then(_newLangue);
    super.initState();
  }

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void _newLangue(String language) {
    setState(() {
      this._language = language;
    });
  }

  Future<void> _SaveSelectedItems(String $data, String $TranslatedText,
      String _langue, String example) async {
    await Firestore.instance.collection('selecteditems').add(<String, dynamic>{
      'selectedItem': $data,
      'translated': $TranslatedText,
      'language': _langue,
      'example': example
    });
  }
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
        backgroundColor: Colors.lightBlue[300],
        body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Image.asset('assets/speech_bubble.png',
                        width: 100.0, height: 400.0)
                  ])
            ]));
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(
        Duration(seconds: 3),
        () => Navigator.pushReplacement(context,
            new MaterialPageRoute(builder: (context) => new Camera())));
  }
}
