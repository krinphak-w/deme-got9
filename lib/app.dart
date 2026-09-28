import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'data/models.dart';
import 'features/admin/verify_page.dart';
import 'features/auth/auth_page.dart';
import 'features/corporate/corporate_page.dart';
import 'features/farmer/home_page.dart';
import 'features/farmer/log_page.dart';
import 'features/farmer/plot_add_menu.dart';
import 'features/farmer/plot_draw.dart';
import 'features/farmer/plot_manual.dart';
import 'features/farmer/plot_walk.dart';
import 'features/profile/profile_page.dart';
import 'features/shop/shop_page.dart';
import 'features/trace/showcase_page.dart';
import 'features/trace/trace_page.dart';
import 'features/workshop/workshop_page.dart';
import 'l10n/strings.dart';

class Got9App extends StatefulWidget {
  const Got9App({super.key});

  @override
  State<Got9App> createState() => _Got9AppState();
}

class _Got9AppState extends State<Got9App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Created ONCE: rebuilding on state changes must NOT reset navigation.
    final AppState state = context.read<AppState>();
    _router = GoRouter(
      initialLocation: '/auth',
      refreshListenable: state,
      routes: [
        GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
        GoRoute(path: '/farmer/home', builder: (_, __) => const FarmerHomePage()),
        GoRoute(path: '/farmer/log', builder: (_, __) => const FarmerLogPage()),
        GoRoute(path: '/farmer/plot/add', builder: (_, __) => const PlotAddMenuPage()),
        GoRoute(path: '/farmer/plot/draw', builder: (_, __) => const PlotDrawPage()),
        GoRoute(path: '/farmer/plot/walk', builder: (_, __) => const PlotWalkPage()),
        GoRoute(path: '/farmer/plot/manual', builder: (_, __) => const PlotManualPage()),
        GoRoute(path: '/shop', builder: (_, __) => const ShopPage()),
        GoRoute(path: '/workshop', builder: (_, __) => const WorkshopPage()),
        GoRoute(
            path: '/trace/showcase',
            builder: (_, __) => const TraceShowcasePage()),
        GoRoute(
          path: '/trace/:plotId',
          builder: (_, s) => TracePage(plotId: s.pathParameters['plotId']!),
        ),
        GoRoute(path: '/corporate', builder: (_, __) => const CorporatePage()),
        GoRoute(path: '/admin/verify', builder: (_, __) => const VerifyPage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
      redirect: (ctx, rs) {
        final AppState st = ctx.read<AppState>();
        final bool public = rs.matchedLocation == '/auth' ||
            rs.matchedLocation == '/trace/showcase' ||
            rs.matchedLocation.startsWith('/trace/') ||
            rs.matchedLocation == '/shop' ||
            rs.matchedLocation == '/workshop';
        if (!public && st.currentUser == null) return '/auth';
        // Logged-in user landing on /auth -> send to their home.
        if (rs.matchedLocation == '/auth' && st.currentUser != null) {
          return switch (st.currentUser!.role) {
            UserRole.farmer => '/farmer/home',
            UserRole.corporate => '/corporate',
            UserRole.buyer => '/shop',
          };
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    return MaterialApp.router(
      title: 'GOT9 Phase 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B5E20), // Greennika deep green
        fontFamily: 'Prompt',
      ),
      locale: state.lang == AppLang.th
          ? const Locale('th')
          : const Locale('en'),
      supportedLocales: const [Locale('th'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(state.fontScale),
        ),
        child: child!,
      ),
      routerConfig: _router,
    );
  }
}

/// Top bar controls shared by pages: TH/EN + A-/A/A+ font buttons.
class Got9Bar extends StatelessWidget implements PreferredSizeWidget {
  const Got9Bar(
      {super.key, required this.title, this.actions = const [], this.showProfile = true});

  final String title;
  final List<Widget> actions;
  final bool showProfile;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    return AppBar(
      title: Text(title),
      actions: [
        IconButton(
          tooltip: 'A-',
          onPressed: () => state.bumpFont(-0.1),
          icon: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          tooltip: 'ขนาดปกติ / Reset',
          onPressed: () => state.resetFont(),
          icon: const Text('A', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          tooltip: 'A+',
          onPressed: () => state.bumpFont(0.1),
          icon: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => state.setLang(
              state.lang == AppLang.th ? AppLang.en : AppLang.th),
          child: Text(state.lang == AppLang.th ? 'EN' : 'TH',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (showProfile && state.currentUser != null)
          IconButton(
            tooltip: 'โปรไฟล์ / Profile',
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.go('/profile'),
          ),
        ...actions,
      ],
    );
  }
}

/// Bottom nav for logged-in users.
class Got9Nav extends StatelessWidget {
  const Got9Nav({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final UserRole role =
        state.currentUser?.role ?? UserRole.buyer;
    void go(String loc) => context.go(loc);
    final List<BottomNavigationBarItem> items = [
      BottomNavigationBarItem(
          icon: const Icon(Icons.map), label: state.tr('myPlots')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.shopping_basket),
          label: state.tr('shop')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.event), label: state.tr('workshop')),
    ];
    final List<String> locs = ['/farmer/home', '/shop', '/workshop'];
    if (role == UserRole.corporate) {
      items.add(BottomNavigationBarItem(
          icon: const Icon(Icons.business),
          label: state.tr('corporateTitle')));
      locs.add('/corporate');
    }
    return BottomNavigationBar(
      currentIndex: index.clamp(0, items.length - 1),
      onTap: (i) => go(locs[i]),
      type: BottomNavigationBarType.fixed,
      items: items,
    );
  }
}
