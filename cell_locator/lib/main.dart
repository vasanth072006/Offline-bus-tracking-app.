import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/location_provider.dart';
import 'screens/home_screen.dart';
import 'screens/train_mode_screen.dart';
import 'screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF050B14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const TowerTrackApp());
}

class TowerTrackApp extends StatelessWidget {
  const TowerTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider()..initialize(),
      child: MaterialApp(
        title: 'TowerTrack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2979FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF050B14),
        ),
        home: const RootNavigator(),
      ),
    );
  }
}

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: const [
              HomeScreen(),
              TrainModeScreen(),
              MapScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1528),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xFF2979FF).withOpacity(0.2),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.cell_tower_outlined,
                      color: Colors.white.withOpacity(0.4)),
                  selectedIcon: const Icon(Icons.cell_tower,
                      color: Color(0xFF2979FF)),
                  label: 'Tower',
                ),
                NavigationDestination(
                  icon: Stack(
                    children: [
                      Icon(Icons.train_outlined,
                          color: Colors.white.withOpacity(0.4)),
                      if (!provider.isOnline)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00E676),
                            ),
                          ),
                        ),
                    ],
                  ),
                  selectedIcon: const Icon(Icons.train,
                      color: Color(0xFF2979FF)),
                  label: 'Where Am I',
                ),
                NavigationDestination(
                  icon: Stack(
                    children: [
                      Icon(Icons.map_outlined,
                          color: Colors.white.withOpacity(0.4)),
                      if (!provider.isOnline)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  selectedIcon: const Icon(Icons.map,
                      color: Color(0xFF2979FF)),
                  label: 'Map',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
