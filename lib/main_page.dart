import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bottom_navy_bar/bottom_navy_bar.dart';

import 'main.dart';


class MainPage extends StatefulWidget{
  @override

  _MainPageState createState() =>  _MainPageState();

}


class _MainPageState extends State<MainPage>{
  int _selectedIndex = 1;
  final _widgetOptions = [

    Text('Index 2: Profile'),
    Text('Index3: Settings')
  ];


  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return  WillPopScope(
      //When the user click on the phone back button the app exits
      onWillPop: (){
        SystemNavigator.pop();
      },
      child: Scaffold(

        body: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),

          bottomNavigationBar: BottomNavyBar(
            selectedIndex: _selectedIndex,
            showElevation: true, // use this to remove appBar's elevation
            onItemSelected: (index) => setState(() {
              _selectedIndex = index;
              /*_pageController.animateToPage(index,
                  duration: Duration(milliseconds: 300), curve: Curves.ease);*/
            }),
            items: [
              BottomNavyBarItem(
                icon: Icon(Icons.apps),
                title: Text('Home'),
                activeColor: Colors.red,
              ),
              BottomNavyBarItem(
                  icon: Icon(Icons.people),
                  title: Text('Users'),
                  activeColor: Colors.purpleAccent
              ),
              BottomNavyBarItem(
                  icon: Icon(Icons.message),
                  title: Text('Messages'),
                  activeColor: Colors.pink
              ),
              BottomNavyBarItem(
                  icon: Icon(Icons.settings),
                  title: Text('Settings'),
                  activeColor: Colors.blue
              ),
            ],
          )
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
