import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'fuzzy.dart';
import 'levenshtein.dart';
import 'submit.dart';
import 'results.dart';
import 'postdata.dart';
import 'paramscreen.dart';

List<List<dynamic>> _airportList;
Map<String, String> _nameToCode = new Map<String, String>();
List<String> _currentAirportCodes = [];
int _textFieldCount = 1;
// List of text to be put into TextFields
List<String> _selectedList = [];

void _init() async {
  _selectedList.length = _textFieldCount;
  final csvCodec = new CsvCodec();
  String temp = await rootBundle.loadString('data/airport-codes.csv');
  _airportList = const CsvToListConverter().convert(temp);
  for (int i = 0; i < _airportList.length; i++) {
    _nameToCode[_airportList[i][2]] = _airportList[i][10].toString();
  }
}

class HomeScreen extends StatefulWidget {
  HomeScreen({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _HomeScreenState createState() => new _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen> {
  @override
  bool get wantKeepAlive => true;
  bool firstRun = true;
  int _curInputIndex = 0;
  _SearchDelegate _delegate = new _SearchDelegate();

  @override
  Widget build(BuildContext context) {
    if (firstRun) {
      _init();
      firstRun = !firstRun;
    }
    // Top 'appBar' bar
    return new Scaffold(
        appBar: new AppBar(
          actions: <Widget>[
            new IconButton(
              icon: new Icon(Icons.lightbulb_outline),
            ),
            new IconButton(
              icon: new Icon(Icons.search),
            ),
            new IconButton(
              icon: new Icon(Icons.card_travel),
            ),
          ],
        ),
        // Main Body
        body: new Column(children: <Widget>[
          new Flexible(
            child: new ListView.builder(
              itemCount: _textFieldCount,
              itemBuilder: (_, int index) =>
                  new _InputItem(searchDelegate: _delegate, index: index),
            ),
          ),
        ]),
        floatingActionButton: new FloatingActionButton(
            child: new Icon(IconData(0xe409,
                fontFamily: 'MaterialIcons', matchTextDirection: true)),
            onPressed: () {
              _currentAirportCodes = [];
              for (int i = 0; i < _selectedList.length; i++) {
                _currentAirportCodes.add(_nameToCode[_selectedList[i]]);
                if (_currentAirportCodes[i] == null) {
                  _currentAirportCodes.removeAt(i);
                }
              }
              print(_currentAirportCodes);
              Navigator.push(
                context,
                new MaterialPageRoute(builder: ((context) {
                  ParameterScreen.currentAirportCodes = _currentAirportCodes;
                  return new ParameterScreen();
                })),
              );
            }));
  }
}

class _SearchDelegate extends SearchDelegate<Map<String, String>> {
  Fuzzy _fuzz = new Fuzzy();
  int currentAirportCount = 0;

  @override
  Widget buildLeading(BuildContext context) {
    return new IconButton(
        icon: new Icon(Icons.arrow_back),
        onPressed: () {
          close(context, null);
        });
  }

  @override
  Widget buildResults(BuildContext context) {
    String searched = query;
    print(searched);
    if (searched != null) {
      Search s = _search(searched);
      print(s.results.length);
      if (s.results.length > 0) {
        return new ListView.builder(
          itemCount: s.results.length,
          itemBuilder: (_, int index) => _ResultCard(
              name: s.results[index],
              code: s.codes[index],
              searchDelegate: this),
        );
      } else {
        return new Container();
      }
    }
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return new Text("We can put some suggestions here :)");
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return <Widget>[
      new IconButton(
          icon: new Icon(Icons.cancel),
          onPressed: () {
            query = '';
            showSuggestions(context);
          }),
    ];
  }

  Search _search(String value) {
    List<String> results = [];
    List<String> codes = [];
    if (value.length > 2) {
      for (int i = 0; i < _airportList.length; i++) {
        //For now just search name
        String curName = _airportList[i][2];
        String curCode = _airportList[i][10].toString();
        List<String> splitWords = curName.split(' ');
        splitWords.removeWhere((item) => item.toLowerCase() == 'airport');
        List<int> indexes = [];
        for(int i = 0;i < splitWords.length;i++){
          indexes.add(_fuzz.bitapSearch(splitWords[i], value, 2));
        }
        // Search for airport code
        if(value.length == 3){
          indexes.add(_fuzz.bitapSearch(curCode, value, 2));
        }
        for(int i = 0;i < indexes.length;i++){
          if(indexes[i] == 0){
            results.add(curName);
            codes.add(curCode);
            break;
          }
        }
      }
      return new Search(results, codes);
    }
  }
}

class Search {
  Search(this.results, this.codes);
  List<String> results;
  List<String> codes;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({this.name, this.code, this.searchDelegate});

  final String name, code;
  final SearchDelegate<Map<String, String>> searchDelegate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return new GestureDetector(
      onTap: () {
        Map<String, String> retVal = new Map();
        retVal['name'] = name;
        retVal['code'] = code;
        searchDelegate.close(context, retVal);
      },
      child: new Card(
        child: new Padding(
          padding: const EdgeInsets.all(8.0),
          child: new Column(
            children: <Widget>[
              new Text('${name} (${code})',
                  style: theme.textTheme.headline.copyWith(fontSize: 20.0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputItem extends StatelessWidget {
  const _InputItem({this.index, this.searchDelegate});
  final SearchDelegate<Map<String, String>> searchDelegate;

  final int index;

  String _getText() {
    String retVal = 'What is ';
    if (!(_selectedList.length > index) ||
        (_selectedList[index] == '' || _selectedList[index] == null)) {
      if (index == 0) {
        retVal += 'your home city?';
      } else if(index == 1) {
        retVal += 'the city you most want to visit?';
      } else {
        retVal += 'another city you want to visit?';
      }
    } else {
      retVal = _selectedList[index];
    }
    return retVal;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return new GestureDetector(
      onTap: () async {
        final Map<String, String> selected =
            await showSearch<Map<String, String>>(
          context: context,
          delegate: searchDelegate,
        );
        if (selected != null) {
          print(selected['name']);
          print(selected['code']);
          //Only add new field if last item, more robust logic later
          if (index + 1 == _textFieldCount) {
            _textFieldCount++;
            _selectedList.length = _textFieldCount;
            _selectedList[index] = selected['name'];
            print(_selectedList);
          }
        }
      },
      child: new Padding(
        padding: const EdgeInsets.fromLTRB(25.0, 5.0, 25.0, 0.0),
        child: new Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(
                const Radius.circular(7.0)
            ),
          ),
          child: new Padding(
            padding: const EdgeInsets.all(5.0),
            child: new Column(
              children: <Widget>[
                new Text(_getText(), style: theme.textTheme.headline.copyWith(fontSize: 18.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
