// project_management_page.dart

// ignore_for_file: unused_field, unused_element, unused_local_variable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/assignment_section.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/processing_section.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/chat_section.dart';
import 'package:pb_hrsystem/core/widgets/linear_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_people_page.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ProjectManagementPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const ProjectManagementPage({
    super.key,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  ProjectManagementPageState createState() => ProjectManagementPageState();
}

class ProjectManagementPageState extends State<ProjectManagementPage>
    with TickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  String _currentUserId = '';
  bool _isRefreshing = false;
  bool _isBackgroundLoading = false;
  Timer? _timer;
  late String projectId;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[_ProjectManagementPageState] Received projectId: ${widget.projectId}');
    projectId = widget.projectId;
    _loadUserData().then((_) {
      _refreshData();
    });
    _tabController = TabController(length: 3, vsync: this);
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _refreshData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id') ?? '';
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _isBackgroundLoading = true;
    });
    await _loadUserData();
    setState(() {
      _isRefreshing = false;
      _isBackgroundLoading = false;
    });
  }

  void _navigateToAddMembersPage() {
    debugPrint('Navigating to Add Members page with projectId: $projectId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPeoplePage(projectId: projectId),
      ),
    ).then((result) {
      // Handle the result returned from AddPeoplePage
      if (result is Map<String, dynamic> && result['refresh'] == true) {
        debugPrint(
            'Refresh flag received from AddPeoplePage. Refreshing project members...');
        // Refresh the page data
        _refreshData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90.0),
        child: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          elevation: 0,
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(isDarkMode
                      ? 'assets/darkbg.png'
                      : 'assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(top: 25.0),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context, {'refresh': true});
              },
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 34.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Text(
                  'Project Management',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            // Linear Loading Indicator under header
            LinearLoadingIndicator(
              isLoading: _isBackgroundLoading,
              color: isDarkMode ? Colors.amber : Colors.green,
            ),

            TabBar(
              isScrollable: true,
              controller: _tabController,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.amber,
              labelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Processing / Details'),
                Tab(text: 'Assignment / Task'),
                Tab(text: 'Comment / Chat'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ProcessingSection(
                    projectId: projectId,
                    baseUrl: widget.baseUrl,
                  ),
                  AssignmentSection(
                    projectId: projectId,
                    baseUrl: widget.baseUrl,
                  ),
                  ChatSection(
                    projectId: projectId,
                    baseUrl: widget.baseUrl,
                    currentUserId: _currentUserId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
