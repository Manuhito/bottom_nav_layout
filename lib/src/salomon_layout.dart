import 'package:bottom_nav_layout/src/tab_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

/// TODO: What is BottomNavLayout
/// TODO: Why does BottomNavLayout exist, what is it's purpose
/// TODO: What does BottomNavLayout do
///
/// [BottomNavLayout] layout consists of a [Scaffold].
/// which has one of the [pages] as [Scaffold.body] and a [BottomNavigationBar] as [Scaffold.bottomNavigationBar].
/// [BottomNavigationBar] controls which one of the [pages] is currently visible.
///
/// While navigating around with [BottomNavigationBar], [pages] do not get destroyed/rebuilt, only get hidden/visible.
/// This way, the pages saves all their state.
class SalomonBottomNavLayout extends StatefulWidget {
  SalomonBottomNavLayout({
    Key? key,

    // Nav layout properties
    this.pages,
    this.pageBuilders,
    this.tabStack,
    this.keys,
    this.savePageState = true,

    // Delegated properties
    required this.items,
    this.onTap,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedColorOpacity,
    this.itemShape = const StadiumBorder(),
    this.margin = const EdgeInsets.all(8),
    this.itemPadding = const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutQuint,
  })  : assert(pages != null && pageBuilders == null || pageBuilders != null && pages == null, "Either pass pages or pageBuilders"),
        assert((pages?.length ?? pageBuilders!.length) >= 2, "At least 2 pages are required"),
        assert(keys == null || (pages?.length ?? pageBuilders!.length) == keys.length, "Either do not pass keys or pass as many as pages"),
        assert((pages?.length ?? pageBuilders!.length) == items.length, "Pass as many bottomNavBarItems as pages"),
        assert(tabStack == null || (pages?.length ?? pageBuilders!.length) > tabStack.peek() && tabStack.peek() >= 0, "initialTabIndex cannot exceed the max page index or be negative"),
        super(key: key);

  /// The main content of the layout.
  /// Directly passed to the [_BottomNavLayoutState.pages]
  final List<Widget>? pages;

  /// Simple functions that return the respective items on [pages].
  /// When [pageBuilders] is passed, they are used to lazily initialize the pages, when the user first navigates to the respective tab.
  /// Either pass [pages] or [pageBuilders], do not pass both.
  final List<Widget Function()>? pageBuilders;

  /// Initial tab stack that user passed in.
  final PageStack? tabStack;

  /// The navigation keys of the [pages] in the layout.
  ///
  /// These keys are optional. If not used, bottom navigation backstack still functions normally.
  ///
  /// To manage all back button presses from this widget, keys of type [GlobalKey<NavigatorState>] should be used in the [pages] for navigation.
  /// These keys should be created outside the pages and the same key instances should be passed into both pages themselves and to this widget at the same time.
  ///
  /// If present, these keys are used to navigate back.
  /// The back press events will be passed to the current page's key to be consumed first.
  /// The onTap events on the current BottomNavBarItem will cause the key to pop until the root route is reached on that page.
  ///
  /// Number and order of [keys] should be the same as the order of [pages] they are passed into.
  final List<GlobalKey<NavigatorState>?>? keys;

  /// Whether the page states are saved or not.
  final bool savePageState;

  /// Property delegated to [SalomonBottomBar]
  final List<SalomonBottomBarItem> items;

  /// Property delegated to [SalomonBottomBar]
  final Function(int)? onTap;

  /// Property delegated to [SalomonBottomBar]
  final Color? selectedItemColor;

  /// Property delegated to [SalomonBottomBar]
  final Color? unselectedItemColor;

  /// Property delegated to [SalomonBottomBar]
  final double? selectedColorOpacity;

  /// Property delegated to [SalomonBottomBar]
  final ShapeBorder itemShape;

  /// Property delegated to [SalomonBottomBar]
  final EdgeInsets margin;

  /// Property delegated to [SalomonBottomBar]
  final EdgeInsets itemPadding;

  /// Property delegated to [SalomonBottomBar]
  final Duration duration;

  /// Property delegated to [SalomonBottomBar]
  final Curve curve;

  @override
  State<StatefulWidget> createState() => _SalomonBottomNavLayoutState();
}

class _SalomonBottomNavLayoutState extends State<SalomonBottomNavLayout> {
  /// [BottomNavLayout]'s tab backstack. The main focus of this package.
  ///
  /// It saves tabs on the backstack by their indexes. The [tabStack.peek] always contains the current tab's index.
  ///
  /// Users can pass a [PageStack] instance or not. If they do not, the default one will be a [ReorderToFrontPageStack].
  /// There are different versions of stack pattern readily implemented. Users can also implement their own.
  late final PageStack tabStack;

  /// The main content of the layout.
  /// Respective widget in this list is shown above the [BottomNavigationBar].
  ///
  /// If pages are directly passed is, all pages will be present in this list at all times.
  /// If pageBuilders are passed in, the corresponding entry in the list will contain null until that page is navigated for the first time.
  final List<Widget?> pages = List.empty(growable: true);

  /// Initialize [tabStack] and [pages]
  @override
  void initState() {
    // Set the tabStack. If not passed in, initialize with default.
    tabStack = widget.tabStack ?? ReorderToFrontPageStack(initialPage: 0);

    // If pages are passed in, just set them.
    if (widget.pages != null) {
      // Add all pages
      widget.pages!.forEach((page) => pages.add(page));
    }
    // If not, they will be lazily initialized on runtime.
    else {
      // Add a null for each page
      widget.pageBuilders!.forEach((_) => pages.add(null));
    }

    super.initState();
  }

  /// If the selected tab is the current tab, pops the page until it reaches it's root route.
  /// If the selected tab is not the current tab, navigates to that tab.
  void onTabSelected(int index) {
    // If the current item is selected
    if (index == tabStack.peek()) {
      // Pop until the base route
      widget.keys?[index]?.currentState?.popUntil((route) => route.isFirst);
    }
    // If something else than current item is selected
    else {
      // Navigate to tab
      tabStack.push(index);

      // Set state to change the page
      setState(() {});
    }
  }

  /// Sends the pop event to the current page first. If it doesn't consume it, then tries to pop the tabStack.
  /// If there are more than one items in the tabStack, pops back to the previous page on the stack.
  /// If there is a single tab in the stack, bubbles up the pop event. Exits the app if no other back button handler is configured in the app.
  Future<bool> onWillPop() async {
    // Send pop event to the inner page
    final consumedByPage = await widget.keys?[tabStack.peek()]?.currentState?.maybePop() ?? false;

    // If the back event is consumed by the inner page
    if (consumedByPage) {
      // Consume pop event
      return false;
    }

    // Pop the top element from bottom navigation stack
    tabStack.pop();

    // If the stack is not empty
    if (tabStack.isNotEmpty) {
      // Set state to change the page
      setState(() {});

      // Consume pop event
      return false;
    }

    // Bubble up the pop event.
    return true;
  }

  /// If the current page is null, then it needs to be built from the [widget.pageBuilders] before being shown.
  @override
  Widget build(BuildContext context) {
    // If the current page hasn't been initialized.
    if (pages[tabStack.peek()] == null) {
      // Create the page from the builder and put it into page list.
      pages[tabStack.peek()] = widget.pageBuilders![tabStack.peek()]();
    }

    // Return the view
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        // Depending on if the user wants to save the page states
        body: !widget.savePageState
            // Do not save page states
            ? pages[tabStack.peek()]
            // Save page states using a stack/offstage structure.
            // Stack view contains one Offstage widget per page.
            // Offstages are hidden except for the currently selected tab.
            : Stack(
                children: pages.asMap().entries.map((indexPageMap) {
                  return Offstage(
                    offstage: indexPageMap.key != tabStack.peek(),
                    // If the page is not initialized, "not show" an invisible widget instead.
                    child: indexPageMap.value ?? SizedBox.shrink(),
                  );
                }).toList(),
              ),
        bottomNavigationBar: SalomonBottomBar(
          currentIndex: tabStack.peek(),

          // onTap calls both the layout's own onTap action and the user's passed in onTap action.
          onTap: (index) {
            // Layout functionality
            onTabSelected(index);

            // Passed in onTap call
            widget.onTap?.call(index);
          },

          // Delegated properties
          key: widget.key,
          items: widget.items,
          selectedItemColor: widget.selectedItemColor,
          unselectedItemColor: widget.unselectedItemColor,
          selectedColorOpacity: widget.selectedColorOpacity,
          itemShape: widget.itemShape,
          margin: widget.margin,
          itemPadding: widget.itemPadding,
          duration: widget.duration,
          curve: widget.curve,
        ),
      ),
    );
  }
}