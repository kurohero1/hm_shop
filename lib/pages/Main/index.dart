import 'package:flutter/material.dart';
import 'package:hm_shop/components/step_counter.dart';
import 'package:hm_shop/components/weekly_distance_chart.dart';
import 'package:hm_shop/components/walk_map_widget.dart';
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
  String _currentOrigin = '関屋駅';
  String _currentWaypoint = ''; // 当前经由地
  String _currentDestination = '新潟県警察本部';

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
      // 只有当值发生变化时才更新状态
      if (origin != _currentOrigin || waypoint != _currentWaypoint || dest != _currentDestination) {
        setState(() {
          _currentOrigin = origin;
          _currentWaypoint = waypoint;
          _currentDestination = dest;
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
            const SizedBox(height: 8),
            const Text(
              '↑ システムコメント（傘を持って行ったほうがいいかもなど）',
              style: TextStyle(color: Colors.red),
            ),
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
              _filterChip('買い物さんぽ', icon: Icons.shopping_bag),
              const SizedBox(width: 8),
              _filterChip('絞り込み', icon: Icons.filter_list),
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
    return SizedBox(
      height: 250,
      child: WalkMapWidget(
        origin: _currentOrigin,
        destination: _currentDestination,
        waypoint: _currentWaypoint,
        filters: Set.from(_selectedFilters), // 传递副本，确保 didUpdateWidget 能检测到变化
      ),
    );
  }

  Widget _stepAndGraphArea() {
  return Row(
    children: const [
      Expanded(child: StepCounter()),
      SizedBox(width: 8),
      Expanded(child: WeeklyDistanceChart()),
    ],
  );
}

  Widget _weatherArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: _border(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('天気予報'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 100,
                  decoration: _border(),
                  alignment: Alignment.center,
                  child: const Text('降水量'),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: const [
                  Text('場所'),
                  SizedBox(height: 8),
                  Text('X℃'),
                  SizedBox(height: 4),
                  Text('高℃ / 低℃'),
                  SizedBox(height: 4),
                  Text('天気'),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          const Text('今日のさんぽは〇〇'),
        ],
      ),
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
