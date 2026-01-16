import 'package:flutter/material.dart';
import 'package:hm_shop/components/step_counter.dart';
import 'package:hm_shop/components/weekly_distance_chart.dart';
import 'package:hm_shop/components/walk_map_widget_stub.dart'
    if (dart.library.html) 'package:hm_shop/components/walk_map_widget.dart';
import 'package:hm_shop/components/weather.dart';
import 'package:provider/provider.dart';
import 'package:hm_shop/services/auth_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final Color mainGreen = const Color(0xFF2FA84F);

  // 记录选中的标签集合
  final Set<String> _selectedFilters = {};

  // 地点输入控制器
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _waypointController = TextEditingController(); // 经由地
  final TextEditingController _destController = TextEditingController();

  // 焦点控制器
  final FocusNode _originFocus = FocusNode();
  final FocusNode _waypointFocus = FocusNode(); // 经由地焦点
  final FocusNode _destFocus = FocusNode();

  // 当前地图使用的起点和终点（默认值）
  String _currentOrigin = '';
  String _currentWaypoint = ''; // 当前经由地
  String _currentDestination = '';

  double? _originLat;
  double? _originLon;
  double? _destinationLat;
  double? _destinationLon;
  String _systemComment = '';

  @override
  void initState() {
    super.initState();
    // 初始化输入框内容
    _originController.text = _currentOrigin;
    _waypointController.text = _currentWaypoint;
    _destController.text = _currentDestination;

    // 监听焦点变化，失去焦点时自动更新路线
    _originFocus.addListener(_onFocusChange);
    _waypointFocus.addListener(_onFocusChange);
    _destFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _originController.dispose();
    _waypointController.dispose();
    _destController.dispose();
    _originFocus.dispose();
    _waypointFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // 当任一输入框失去焦点时，尝试更新路线
    if (!_originFocus.hasFocus && !_waypointFocus.hasFocus && !_destFocus.hasFocus) {
      _updateRoute();
    }
  }

  void _updateRoute() {
    final origin = _originController.text.trim();
    final waypoint = _waypointController.text.trim();
    final dest = _destController.text.trim();

    if (origin.isNotEmpty && dest.isNotEmpty) {
      if (origin != _currentOrigin ||
          waypoint != _currentWaypoint ||
          dest != _currentDestination) {
        setState(() {
          _currentOrigin = origin;
          _currentWaypoint = waypoint;
          _currentDestination = dest;
          _originLat = null;
          _originLon = null;
          _destinationLat = null;
          _destinationLon = null;
        });
      }
    } else {
      if (_currentOrigin.isNotEmpty ||
          _currentWaypoint.isNotEmpty ||
          _currentDestination.isNotEmpty) {
        setState(() {
          _currentOrigin = '';
          _currentWaypoint = '';
          _currentDestination = '';
          _originLat = null;
          _originLon = null;
          _destinationLat = null;
          _destinationLon = null;
          _systemComment = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainGreen,
        title: const Text('さんぽアプリ'),
        actions: [
          IconButton(
            onPressed: () {
              context.read<AuthService>().signOut();
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _routeInputArea(),
            const SizedBox(height: 12),
            _mapArea(),
            const SizedBox(height: 12),
            _stepAndGraphArea(),
            const SizedBox(height: 12),
            _weatherArea(),
          ],
        ),
      ),
    );
  }

  Widget _routeInputArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：起点 -> 中间 -> 终点
        Row(
          children: [
            Expanded(child: _locationInput('始発', Icons.trip_origin, _originController, _originFocus)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: _locationInput('中間', Icons.add_location_alt, _waypointController, _waypointFocus)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: _locationInput('終点', Icons.flag, _destController, _destFocus)),
          ],
        ),
        const SizedBox(height: 12),
        // 第二行：筛选标签
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _filterChip('絞り込み', icon: Icons.filter_list),
              const SizedBox(width: 8),
              _filterChip('買い物さんぽ', icon: Icons.shopping_bag),
              const SizedBox(width: 8),
              _filterChip('グルメ\nさんぽ', isMultiLine: true),
              const SizedBox(width: 8),
              _filterChip('ゆる\nさんぽ', isMultiLine: true),
              const SizedBox(width: 8),
              _filterChip('甘味\nさんぽ', isMultiLine: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locationInput(String hint, IconData icon, TextEditingController? controller, FocusNode? focusNode) {
    return Container(
      height: 48,
      decoration: _border().copyWith(color: Colors.white),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.search, // 键盘回车变成搜索图标
        onSubmitted: (_) {
          // 按回车时收起键盘，这会触发焦点失去，进而触发 _updateRoute
          FocusScope.of(context).unfocus();
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: mainGreen),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _filterChip(String label, {IconData? icon, bool isMultiLine = false}) {
    final isSelected = _selectedFilters.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFilters.remove(label);
          } else {
            _selectedFilters.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: _border().copyWith(
          color: isSelected ? mainGreen : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : mainGreen,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapArea() {
    if (_currentOrigin.isEmpty || _currentDestination.isEmpty) {
      return Container(
        height: 250,
        width: double.infinity,
        decoration: _border().copyWith(color: Colors.white),
        child: const Center(
          child: Text(
            '上の始発と終点を入力すると\nルート地図が表示されます',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: WalkMapWidget(
        origin: _currentOrigin,
        destination: _currentDestination,
        waypoint: _currentWaypoint,
        filters: Set.from(_selectedFilters),
        onRouteEndpointsChanged: (originPoint, destinationPoint) {
          setState(() {
            _originLat = originPoint.latitude;
            _originLon = originPoint.longitude;
            _destinationLat = destinationPoint.latitude;
            _destinationLon = destinationPoint.longitude;
          });
        },
      ),
    );
  }

  Widget _stepAndGraphArea() {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return Column(
        children: const [
          StepCounter(),
          SizedBox(height: 8),
          WeeklyDistanceChart(),
        ],
      );
    }
    return Row(
      children: const [
        Expanded(child: StepCounter()),
        SizedBox(width: 8),
        Expanded(child: WeeklyDistanceChart()),
      ],
    );
  }

  Widget _weatherArea() {
    return WeatherPanel(
      originName: _currentOrigin,
      waypointName: _currentWaypoint,
      destinationName: _currentDestination,
      originLat: _originLat,
      originLon: _originLon,
      destinationLat: _destinationLat,
      destinationLon: _destinationLon,
      onSystemCommentChanged: (text) {
        setState(() {
          _systemComment = text;
        });
      },
    );
  }

  Widget _box(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: _border(),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  BoxDecoration _border() {
    return BoxDecoration(
      border: Border.all(color: mainGreen),
      borderRadius: BorderRadius.circular(4),
    );
  }
}
