# AppForge AI Context & Agent Instruction Guide

> **Target Audience:** LLM Code Assistants, Cursor, Copilot, Antigravity, Claude Code, Windsurf, and Autonomous Coding Agents building Flutter applications using the `appforge` package.
> **Package:** `appforge`
> **Zero External Dependencies:** Relies purely on the Dart Standard Library and Flutter SDK.

---

## 1. Package Overview & Mental Model

`appforge` is an all-in-one Flutter micro-framework designed to replace heavy third-party dependency chains (`get`, `provider`, `intl`, `dio`, `flutter_screenutil`) with a clean, high-performance, zero-dependency toolkit.

### Core Architecture Pillars:
1. **Context-Free Infrastructure**: Navigation, snackbars, dialogs, and loaders can be dispatched from anywhere (including async controllers) without passing `BuildContext`.
2. **Fine-Grained Reactive State**: Atomic `Rx<T>` signals and surgical `Watch` rebuilder widgets. Rebuilds only the leaf widget observing the variable.
3. **Route-Bound Service Locator**: In-memory dependency injection (`App.put`, `App.lazyPut`, `App.find`) with automatic controller auto-disposal when routes are popped.
4. **World-Class Arabic & BiDi Localization**: Full Unicode UAX #9 bidirectional text isolation, phone number `+` preservation, 6-case Arabic plurals, Arabic grammatical gender detection, Tashkeel/Harakat stripping, and second-person pronoun inflection (`كَ` vs `كِ`).
5. **Universal Common Dictionary**: 25+ essential UI keys (`save`, `cancel`, `delete`, `loading`, `retry`, `settings`, etc.) work out of the box with zero custom translations required.
6. **Mobile Lifecycle Integration**: Listen to OS foreground/background transitions to save drafts and prevent process death data loss.
7. **Responsive Screen Sizing**: Adaptive `.w`, `.h`, `.sp`, `.r`, `.gapX`, and `.gapY` extensions.

---

## 2. Canonical Imports & Bootstrap

Always import `appforge` from the root barrel:
```dart
import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';
```

### Application Entrypoint (`MasterApp`):
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MasterApp(
      initialRoute: const HomeScreen(),
      translations: MyTranslations(), // Extends AppTranslations
      fallbackLocale: const Locale('en', 'US'),
      initialLocale: const Locale('ar'), // Starts directly in Arabic if desired
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      userGender: AppGender.male, // Global default grammatical gender
    ),
  );
}
```

---

## 3. Reactive State Management

### A. Reactive Primitives (`Rx<T>`)
Create reactive state with `.obs` or `Rx<T>()`:
```dart
final count = 0.obs;
final title = 'AppForge'.obs;
final user = Rx<UserProfile?>(null);
final items = <String>[].obs;
```

Mutating state automatically triggers listeners if the value changes by equality:
```dart
count.value++;
user.value = UserProfile(id: 1, name: 'Sara');
items.update((list) => list.add('New Item')); // in-place mutation + notify
items.refresh(); // Force notify listeners after any external mutation
```

**Equality rules (important):**
- `Rx` instances use **identity equality**. Compare wrapped values explicitly: `a.value == b.value` (never `a == b` or `count == 5`).
- `value =` notifies only when the new value differs by `==`. For in-place collection mutation use `update(...)` or `refresh()`.
- `rx.listen(...)` accepts `void Function(T)` or `void Function()`; any other shape throws `ArgumentError` at registration.
- A listener that throws is reported via `FlutterError.reportError`; other listeners still run.

### B. Surgical Rebuilding (`Watch`)
Wrap only the widgets that depend on reactive values. **Do not wrap entire screen scaffolds in `Watch`**.
```dart
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Dashboard')),
    body: Center(
      child: Watch((context) => Text(
        'Counter: ${count.value}',
        style: const TextStyle(fontSize: 24),
      )),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => count.value++,
      child: const Icon(Icons.add),
    ),
  );
}
```

`Watch` subscribes only to the `Rx` values read during its latest build, unsubscribes from values no longer read, and releases every subscription on dispose (zero leaked listeners). Mutating an `Rx` while the framework is mid-build is safe: the rebuild is deferred to the next frame.

### C. Listening & Side-Effects (`Watch.listen`, `rx.listen`, `rx.listenPrev`)
Run side-effects without rebuilding the child and without extra widget base classes:
```dart
// 1. In the Widget tree (triggers snackbars, dialogs, navigation without rebuilding child):
Watch.listen<int>(
  target: controller.count,
  listener: (context, value) {
    if (value == 10) App.snackbar('مبروك!', 'وصلت إلى 10 نقاط');
  },
  child: const CounterDisplay(),
);

// 2. In the Controller (auto-cancelling subscription):
class CounterController extends AppController {
  final count = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // Listening to new value:
    autoCancel(count.listen((newVal) {
      if (newVal >= 100) App.snackbar('إنجاز', 'تجاوزت الـ 100!');
    }));

    // Listening to previous & next values:
    autoCancel(count.listenPrev((prev, next) {
      print('Changed from $prev to $next');
    }));
  }
}
```

### D. Discrete UI State Machine (`UiState<T>`)
Avoid "boolean soup" (`isLoading`, `isError`, `data`). Use the mathematical `UiState` enum:
```dart
final state = UiState<List<Item>>.idle().obs;

// Transitions:
state.value = const UiState.loading();
try {
  final result = await fetchItems();
  state.value = UiState.data(result);
} catch (e) {
  state.value = UiState.error(e.toString());
}
```

Render declaratively in UI using `Watch.state` or `state.value.when()`:
```dart
Watch.state(
  controller.itemsState,
  onIdle: () => const Text('Tap search to begin'),
  onLoading: () => const CircularProgressIndicator(),
  onData: (items) => ListView.builder(
    itemCount: items.length,
    itemBuilder: (_, i) => ListTile(title: Text(items[i].title)),
  ),
  onError: (msg) => Text('Error: $msg', style: const TextStyle(color: Colors.red)),
);
```

### D. Controllers (`AppController`)
Extend `AppController` for stateful business logic. Bind subscriptions to its lifecycle:
```dart
class ProfileController extends AppController {
  final profile = Rx<UserProfile?>(null);

  @override
  void onInit() {
    super.onInit();
    // Called when registered in AppLocator
  }

  @override
  void onReady() {
    super.onReady();
    // Called after widget tree mounts
    loadProfile();
  }

  Future<void> loadProfile() async {
    // async work
  }

  @override
  void onClose() {
    // Auto-called when route is popped or App.delete is called
    super.onClose();
  }
}
```

Bind a controller cleanly to a widget route using `AppBind` (supports route-scoped instance stacking for nested screens of identical controller types):
```dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBind<ProfileController>(
      init: () => ProfileController(), // Or create: () => ProfileController()
      autoDispose: true, // Auto-disposed when this route pops
      builder: (context, controller) => Scaffold(
        body: Watch((context) => Text(controller.profile.value?.name ?? 'Loading...')),
      ),
    );
  }
}
```

---

## 4. Service Locator & Dependency Injection

`AppLocator` provides global in-memory singleton and lazy injection:

```dart
// 1. Immediate Eager Registration (stack: true pushes to instance stack for route isolation)
App.put<AuthService>(AuthService());

// 2. Just-In-Time (JIT) Lazy Registration
App.lazyPut<DatabaseService>(() => DatabaseService());

// 3. Deferred Asynchronous Registration
await App.putAsync<ApiClient>(() async {
  final client = ApiClient();
  await client.init();
  return client;
});

// 4. Locating an instance anywhere
final auth = App.find<AuthService>();

// 5. Named / Tagged instances
App.put<ApiClient>(ApiClient(baseUrl: 'v1'), tag: 'v1');
final v1Client = App.find<ApiClient>(tag: 'v1');

// 6. Manual Deletion (or delete specific instance from stack)
App.delete<AuthService>();
```

---

## 5. Context-Free Navigation & Overlays

Navigate or trigger alerts from any controller or service without `BuildContext`:

```dart
// 1. Pass keys and observer to MaterialApp (or use MasterApp which wires them automatically):
MaterialApp(
  navigatorKey: App.navigatorKey,
  navigatorObservers: [App.navigatorObserver],
  scaffoldMessengerKey: App.scaffoldMessengerKey,
  ...
);

// 2. Push a new route (with optional arguments & directionality-aware transition):
App.to(
  const SettingsScreen(),
  arguments: {'theme': 'dark'},
  transition: AppTransition.slide, // Direction-aware: slides from Left in RTL, Right in LTR
);

// Access arguments anywhere in the target screen or controller without context:
final args = App.arguments as Map<String, dynamic>?;

// 3. Replace current route
App.off(const DashboardScreen(), arguments: user);

// 4. Clear navigation stack (e.g. on logout)
App.offAll(const LoginScreen());

// 5. Pop route with optional result
App.back(true);

// 6. Show context-free snackbar (floating, modern Material 3 styling)
App.snackbar(
  'تم بنجاح',
  'تم تحديث البيانات في السحابة',
  type: AppSnackbarType.success, // success, error, warning, info
);

// 7. Show context-free modal dialog
App.dialog(
  AlertDialog(
    title: const Text('حذف الحساب؟'),
    actions: [
      TextButton(onPressed: () => App.back(), child: const Text('إلغاء')),
      ElevatedButton(onPressed: performDelete, child: const Text('حذف')),
    ],
  ),
);

// 8. Show context-free modal bottom sheet
App.bottomSheet(
  const LanguageSelectorSheet(),
  isDismissible: true,
);

// 9. Global async loading spinner with background touch protection
App.showLoading(message: 'جارٍ المزامنة...');
await performHeavySync();
App.hideLoading();
```

---

## 6. BiDi & Arabic Localization Engine

### A. Translation Dictionary Setup
```dart
class MyTranslations extends AppTranslations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      'welcome': 'Welcome, @name!',
      'unread_emails': 'You have @count new emails',
      'user_greeting_male': 'Welcome back, Mr. @name!',
      'user_greeting_female': 'Welcome back, Ms. @name!',
      'cases_zero': 'No active cases',
      'cases_one': '1 active case',
      'cases_two': '2 active cases',
      'cases_few': '@count active cases',
      'cases_many': '@count active cases',
      'cases_other': '@count active cases',
    },
    'ar': {
      'welcome': 'أهلاً بك يا @name!',
      'unread_emails': 'لديك @count رسائل جديدة',
      'user_greeting_male': 'أهلاً بكَ يا سيد @name!',
      'user_greeting_female': 'أهلاً بكِ يا سيدة @name!',
      'cases_zero': 'لا توجد قضايا نشطة',
      'cases_one': 'قضية واحدة نشطة',
      'cases_two': 'قضيتان نشطتان',
      'cases_few': '@count قضايا نشطة',
      'cases_many': '@count قضية نشطة',
      'cases_other': '@count قضية نشطة',
    },
  };
}
```

### B. Translation Extensions
```dart
// Basic translation (memoized in-memory for O(1) zero-allocation performance)
'welcome'.tr;

// Parameter interpolation
'welcome'.trParams({'name': 'Sara'});

// Full 6-case Arabic pluralization
'cases'.trPlural(quantity, params: {'count': '$quantity'});

// Grammatical gender translation (picks _male / _female key suffix or inline map)
'user_greeting'.trGender(AppGender.female, {'name': 'Sara'});

// Literal UI tokens (tags, handles, phone numbers, URLs) pass directly through .tr:
// Automatically applies Unicode BiDi isolation without polluting missing keys or audit reports!
'+974 5500 1234'.tr;
'#AppForge'.tr;
'https://flutter.dev'.tr;

// Runtime locale switching (instant, in-memory, zero app restart)
App.setLocale(const Locale('ar'));
App.setLocale(const Locale('en', 'US'));
```

> [!TIP]
> **Instant Hot Reload (0ms, Zero App Restart)**:
> In legacy frameworks like GetX, translations are frozen into static singletons upon app boot—requiring developers to hot-restart the entire app and lose navigation/screen state whenever a translation string is edited.
> AppForge translations evaluate dynamically via in-memory getters with an internal snapshot cache. Whenever you edit text in `AppTranslations` and save (`Cmd+S`), Flutter's Hot Reload updates the UI **immediately in 0ms without restarting the app**. No JSON I/O, no asset parsing, no code-generation (`build_runner`) delay, and strictly 0 dependencies.

### C. Phone Number RTL Protection (Unicode UAX #9)
Prevents the `+` sign from jumping to the right side in Arabic/RTL:
```dart
final rawPhone = '+974 5500 1234';
Text(rawPhone.asPhone); // Enforces LRI isolates (or use rawPhone.tr)
```

### D. Arabic Tashkeel, Diacritics & Fuzzy Search
```dart
// Strip all 9 Harakat/Tashkeel marks
'شُكْرًا لَكَ'.stripTashkeel; // -> 'شكرا لك'

// Strip Kashida (Tatweel)
'آبــــفــــورج'.stripTatweel; // -> 'آبفورج'

// Normalize Alef variants, Taa Marboota, and Alif Maqsoora
'أحمد'.normalizeArabic; // -> 'احمد'

// Diacritic-insensitive fuzzy search
'مَلَفّ'.fuzzyContainsArabic('ملف'); // -> true
```

### E. Authentic Dynamic Gender Inflection (`inflectArabicGender`)
Inflects second-person pronouns, attached Kaf-Fatha/Kasra (`كَ` vs `كِ`), relational vocatives (`صديقي` <-> `صديقتي`), predicates (`عضو مميز` <-> `عضوة مميزة`), and verbs (`اضغط` <-> `اضغطي`, `تستطيع` <-> `تستطيعين`):
```dart
const text = 'شكراً لكَ يا صديقي، هل هذا ملفكَ؟ وأنتَ عضو مميز.';

final femaleText = text.inflectArabicGender(AppGender.female);
// Result: 'شكراً لكِ يا صديقتي، هل هذا ملفكِ؟ وأنتِ عضوة مميزة.'

final maleText = femaleText.inflectArabicGender(AppGender.male);
// Result: 'شكراً لكَ يا صديقي، هل هذا ملفكَ؟ وأنتَ عضو مميز.'
```

### F. Noun Grammatical Gender Detection
Linguistic classification of Arabic nouns across 11 morphological categories:
```dart
'ملف'.arabicGender;    // AppGender.male
'رسالة'.arabicGender;  // AppGender.female
'حمزة'.arabicGender;   // AppGender.male (proper masculine ending in ة)
'أطباء'.arabicGender;  // AppGender.male (broken plural of طبيب)
'شمس'.arabicGender;    // AppGender.female (semantic feminine)
'بنت'.arabicGender;    // AppGender.female (innate feminine)
```

### G. Universal Common UI Dictionary (`AppCommonTranslations`)
25+ standard keys resolve automatically without entering them in your translation files:
```dart
'save'.tr;     // En: 'Save'      | Ar: 'حفظ'
'cancel'.tr;   // En: 'Cancel'    | Ar: 'إلغاء'
'delete'.tr;   // En: 'Delete'    | Ar: 'حذف'
'loading'.tr;  // En: 'Loading...' | Ar: 'جارٍ التحميل...'
'retry'.tr;    // En: 'Retry'     | Ar: 'إعادة المحاولة'
'settings'.tr; // En: 'Settings'  | Ar: 'الإعدادات'
'back'.tr;     // En: 'Back'      | Ar: 'رجوع'
'close'.tr;    // En: 'Close'     | Ar: 'إغلاق'
'confirm'.tr;  // En: 'Confirm'   | Ar: 'تأكيد'
'done'.tr;     // En: 'Done'      | Ar: 'تم'
```

### H. Pro-Grade Arabic Orthography & Typography Engine (`AppArabicOrthography`)
Microsoft Word / Gboard grade proofreading and typography normalization:
```dart
// 1. All-in-one formatting pipeline (Punctuation + Waw attachment + Typo autocorrection + optional Gender inflection)
'مرحبا , يرجى فتح اعدادات الخدمه و ارسال الرساله ?'.formatArabic();
// Output: 'مرحباً، يرجى فتح إعدادات الخدمة وإرسال الرسالة؟'

// With gender inflection in the same pipeline:
'مرحبا , شكراً لكَ يا صديقي و تاكد من فحص ملفكَ ?'.formatArabic(gender: AppGender.female);
// Output: 'مرحباً، شكراً لكِ يا صديقتي وتأكدي من فحص ملفكِ؟'

// 2. Arabic Punctuation Normalization (، ؛ ؟ ٪ and typographic spacing)
'مرحبا , كيف حالك ?'.fixArabicPunctuation();
// Output: 'مرحبا، كيف حالك؟'

// 3. Waw Al-'Atf Attachment (No floating Waw with space before word)
'محمد و أحمد'.fixArabicWaw();
// Output: 'محمد وأحمد'

// 4. Autocorrection of high-frequency Hamza, Taa' Marboota, and Alif Maqsoora typos
'يرجى مراجعة اعدادات الخدمه'.autocorrectArabic();
// Output: 'يرجى مراجعة إعدادات الخدمة'

// 5. QWERTY to Arabic Layout Mistyping Converter
'lvpfh'.toArabicKeyboard(); // 'مرحبا'
'HighW'.toArabicKeyboard(); // 'أهلاً'
AppArabicOrthography.isProbablyMistypedQwerty('lvpfh'); // true
```

### I. Real-Time Arabic Text Input Formatter (`ArabicTextInputFormatter`)
Drop directly into any Flutter `TextField` or `TextFormField` for real-time word-processing corrections as the user types:
```dart
TextField(
  inputFormatters: [
    ArabicTextInputFormatter(
      fixWawSpacing: true,         // Automatically attaches ' و ' -> ' و'
      fixPunctuation: true,        // Converts ',' -> '،', '?' -> '؟', fixes spaces
      autoCorrectCommonWords: true,// Corrects 'اعدادات' -> 'إعدادات', 'خدمه' -> 'خدمة'
    ),
  ],
)
```

### J. Extensible Custom Dictionaries (Feeding Names, Domain Terms & Gender Pairs)
Developers can feed their own dictionaries globally at startup or inline per-call:
```dart
// 1. Global feeding of custom words, proper names, and domain terminology:
App.registerArabicWords({
  'ضياء': 'ضِياء',
  'حميدان': 'حُميدان',
  'ستارتب': 'ستارت آب',
});

// 2. Global feeding of custom gender inflection pairs (roles, vocatives, titles):
App.registerArabicGenderPairs([
  ['كابتن', 'كابتنة'],
  ['طبيبنا', 'طبيبتنا'],
  ['مهندس أول', 'مهندسة أولى'],
]);

// 3. Global feeding of custom noun grammatical genders:
App.registerArabicNounGenders({
  'كوفي': AppGender.male,
  'براند': AppGender.male,
});

// 4. Inline, per-call custom dictionary & gender pairs:
text.formatArabic(
  gender: AppGender.female,
  customDictionary: {'فيصل': 'فَيْصَل'},
  customGenderPairs: [
    ['كوتش', 'كوتشة'],
  ],
);
```

### K. Directional Navigation Icons & Auto-Mirroring (`autoMirror` & `AppIcons`)
In RTL layouts (Arabic), standard directional icons (arrows, chevrons, pagination) must visually point in the reading direction (forward is Left `<-`, back is Right `->`). AppForge provides zero-dependency automatic mirroring:

```dart
// 1. Extension on any Icon or Widget:
const Icon(Icons.arrow_forward).autoMirror()
const Icon(Icons.chevron_right).autoMirror(context)

// 2. Pre-configured directional icons facade:
AppIcons.arrowForward()   // -> in LTR, <- in RTL
AppIcons.arrowBack()      // <- in LTR, -> in RTL
AppIcons.chevronForward() // > in LTR, < in RTL
AppIcons.chevronBack()    // < in LTR, > in RTL
```


---

## 7. Dynamic Theming, Responsive Scaling & Form Validation

### A. Dynamic Theme Management (`AppThemeManager`)
```dart
// Switch theme modes
App.setThemeMode(ThemeMode.dark);
App.toggleTheme(); // Automatically checks OS brightness in system mode
App.themeMode;     // ThemeMode.system / light / dark
App.isDark;        // bool
App.isLight;       // bool
App.themeModeNotifier; // ValueNotifier<ThemeMode>

// Context shortcuts:
context.isDark;
context.isLight;
context.theme;
context.colorScheme;
context.textTheme;
context.primaryColor;
context.scaffoldBackgroundColor;
context.cardColor;

// Custom Theme Extensions & Palette Tokens:
final brandTokens = context.tokens<BrandColors>();
```

### B. Responsive Screen Sizing & Metrics (`AppResponsive`)
```dart
// Baseline design reference (default: 390x844):
AppResponsive.init(designSize: const Size(390, 844));

// Sizing Extensions on num:
120.w;        // Width proportional to design size
60.h;         // Height proportional to design size
16.sp;        // Font size proportional to screen geometry (no double-scaling with system accessibility)
12.r;         // Radius using min(scaleW, scaleH) to prevent distortion

// Context-bound Scalers (establishes inherited MediaQuery dependency for automatic rotation/split-screen rebuilds):
context.w(120);
context.h(60);
context.sp(16);
context.r(12);

// Metrics Listenable:
App.responsiveMetricsNotifier; // ValueNotifier<Size>

// Spacing Widgets:
16.gapY;       // SizedBox(height: 16)
12.gapX;       // SizedBox(width: 12)
16.gapYScaled; // SizedBox(height: 16.h)
12.gapXScaled; // SizedBox(width: 12.w)

// Screen Metrics & Breakpoints on BuildContext:
context.screenWidth;
context.screenHeight;
context.screenSize;
context.isMobile;         // < 600 dp
context.isTablet;         // >= 600 dp && < 1024 dp
context.isDesktop;        // >= 1024 dp
context.isLandscape;
context.isPortrait;
context.statusBarHeight;
context.bottomBarHeight;
context.isKeyboardVisible;
context.keyboardHeight;
```

### C. Form Validation & Context Shorthands
```dart
'user@example.com'.isValidEmail;  // true
'+974 5500 1234'.isValidPhone;    // true
'secret'.hasMinLength(8);         // false
'12345'.isNumeric;                // true
'flutter'.capitalizeFirst;        // 'Flutter'

// Focus & Pop Shorthands:
context.unfocus();                // Dismisses soft keyboard
context.requestFocus([node]);
context.pop([result]);
```

---

## 8. Mobile Lifecycle & Process Death Protection

Track OS backgrounding and hydration in controllers:
```dart
class FormController extends AppController {
  final draftText = ''.obs;

  @override
  void onPaused() {
    // Triggered when user minimizes app / receives phone call
    saveDraftToStorage(draftText.value);
  }

  @override
  void onResumed() {
    // Triggered when user returns to foreground
    syncLatestState();
  }
}
```

---

## 9. Zero-Dependency Network Reachability Monitor (`AppConnectivity`)

Detect live internet reachability without `connectivity_plus` or external dependencies:

```dart
// 1. Reactive reachability state:
Watch((context) => Text(App.isOnline.value ? 'Online' : 'Offline'));

// 2. Direct manual socket ping (races candidate hosts concurrently to 1.1.1.1:53 / 8.8.8.8:53):
final bool isConnected = await App.checkConnectivity();

// 3. Background periodic polling (lifecycle-aware):
// Automatically pauses during background states (paused, hidden, detached) to eliminate
// radio and battery drain, and immediately performs an active check upon return (resumed).
AppConnectivity.instance.startMonitoring(interval: const Duration(seconds: 15));

// 4. In-flight check deduplication:
// Concurrent calls to checkConnectivity() share a single active lookup future,
// preventing socket churn and state thrashing.
```

---

## 10. Crash-Immune Atomic Storage (`AppStorage`)

High-performance persistent key-value store built on POSIX atomic file replacement, asynchronous write serialization, and automatic background lifecycle durability:

```dart
// 1. Initialize once in main() before runApp:
await App.initStorage();

// 2. Instant 0ms synchronous RAM reads & async atomic writes:
App.storageWrite('auth_token', 'jwt.secret.here');
App.storageWrite('tags', ['flutter', 'mobile']);
final token = App.storageRead<String>('auth_token');
final count = App.storageRead<int>('launch_count', defaultValue: 0);

// Typed collection reads with automatic runtime casting:
final tags = App.storageRead<List<String>>('tags') ?? const [];

// 3. Remove, Has & Clear:
final exists = App.storageHas('auth_token');
App.storageRemove('auth_token');
App.storageClear();

// 4. Reactive key change listeners:
final cancelKey = App.storage.listenKey('auth_token', (newVal) {
  print('Token changed: $newVal');
});
cancelKey(); // Cancel subscription

// 5. Zero-boilerplate automatic persistence in MasterApp:
MasterApp(
  persistLocale: true,  // Automatically saves & restores locale preferences
  persistTheme: true,   // Automatically saves & restores ThemeMode
  ...
);
```

**Key Durability Guarantees:**
- **Supported types (JSON only):** `bool`, `num` (`int`, `double` finite), `String`, `List`, and `Map<String, dynamic>`. Non-JSON objects throw `ArgumentError` immediately at `write()` to protect data integrity. Convert them first (e.g. `DateTime.toIso8601String()`).
- **Copy-on-read isolation:** Collections returned from `read<T>` are independent deep copies. Mutating a returned `List` or `Map` in place cannot corrupt internal memory or silently desync from disk.
- **Off-main-thread single-flight queue:** Writes are batched across a 50ms window and flushed asynchronously without blocking the UI thread.
- **Background auto-flush:** Hooked to `AppLifecycleManager`; changes are flushed synchronously when the app enters `paused`, `hidden`, or `detached` before the OS can terminate the process.
- **Pre-init write safe:** Writes made before `App.initStorage()` completes are safely held and merged on top of disk data.
- **iOS Sandbox compliant:** Stored in `Library/Application Support` (hidden from Files app, never purged by OS), automatically migrating legacy files.

---

## 11. Theme Harmonizer & Contrast Engine (`AppThemeHarmonizer`)

Automatic WCAG AA contrast ratio compliance and theme derivation:

```dart
// 1. Automatic single-theme derivation in MasterApp:
MasterApp(
  harmonizeTheme: true, // Automatically derives a contrast-safe darkTheme from theme!
  theme: lightTheme,    // No need to manually define darkTheme
);

// 2. Contrast check & adjustment:
final safeColor = AppThemeHarmonizer.ensureContrast(
  foreground: textColor,
  background: surfaceColor,
  minRatio: 4.5, // WCAG AA standard
);

// 3. Color and context extensions:
final contrastRatio = foregroundColor.contrastRatioWith(backgroundColor);
context.contrastRatio(foreground, background);
```

---

## 12. Environment Configuration Loader (`AppEnv`)

RFC-compliant zero-dependency `.env` file parser with variable interpolation and secret masking:

```dart
// 1. Load from rootBundle or file in main():
await App.loadEnv(fileName: '.env', isOptional: true);

// 2. Or load from in-memory map (e.g. for testing or embedded configs):
App.loadEnvFromMap({
  'APP_ENV': 'production',
  'API_BASE_URL': 'https://api.example.com/v1',
  'TIMEOUT': '30',
  'DEBUG_MODE': 'false',
  'SECRET_KEY': 'shhh_private',
});

// 3. Strongly-typed getters:
final String baseUrl = App.env('API_BASE_URL', defaultValue: 'http://localhost');
final int timeout = App.envInt('TIMEOUT', defaultValue: 10);
final double rate = App.envDouble('EXCHANGE_RATE', defaultValue: 1.0);
final bool isDebug = App.envBool('DEBUG_MODE', defaultValue: false);
final bool exists = App.hasEnv('API_BASE_URL');

// 4. Safe debugging (secrets automatically masked):
print(AppEnv.debugSummary()); // Masks KEY, SECRET, PASSWORD, TOKEN, AUTH
final maskedMap = App.envMaskedMap; // {'SECRET_KEY': 'sh****te'}

// 5. In-string variable interpolation supported:
// HOST=127.0.0.1
// PORT=8080
// API_URL=http://${HOST}:${PORT}/v1

// 6. POSIX & Bash Compliant Parser Rules:
// - Single-quoted strings ('...') are treated as strict literals: no variable interpolation or escape sequence expansion.
// - Windows CRLF (\r\n) line endings are automatically normalized.
// - Undefined variables ($UNKNOWN or currency symbols like $100) are preserved literally.
// - NOTE: Asset-bundled .env files are stored as plaintext inside APK/IPA binaries.
//   For sensitive production credentials, prefer `--dart-define-from-file=.env`.
```

---

## 13. Zero-Dependency Skeleton Shimmer Engine (`AppShimmer`)

GPU-accelerated skeleton placeholders with automatic Light/Dark mode tone adaptation, presets, BiDi reading-direction sweep, and 60-120Hz animation path caching:

```dart
// 1. 100% Automatic Layout Shimmer (Zero Configuration, Zero Flags!):
// Wrap ANY real UI widget tree directly. The shimmer automatically inspects
// layout geometry once, caches skeleton bone paths relative to layout, and
// animates at 60-120Hz with zero per-frame render tree walks or glyph layout passes:
myRealProfileCard.shimmer(
  enabled: isLoading,
  direction: ShimmerDirection.auto, // BiDi: sweeps RTL in Arabic, LTR in English!
);

// 2. Pre-built mobile skeleton presets:
AppShimmer.box(width: 120, height: 16, borderRadius: 8);
AppShimmer.circle(radius: 24);
AppShimmer.text(width: 200, lines: 3, spacing: 6);
AppShimmer.listTile(hasLeading: true, hasTrailing: true, subtitleLines: 1);
AppShimmer.card(width: double.infinity, imageHeight: 140);

// 3. Ergonomic widget extension:
myWidget.shimmer(
  enabled: isLoading,
  direction: ShimmerDirection.auto, // Sweeps RTL in Arabic, LTR in English!
);

// 4. Custom colors, loop, and direction:
AppShimmer(
  baseColor: Colors.grey.shade300,
  highlightColor: Colors.grey.shade100,
  direction: ShimmerDirection.rtl,
  duration: const Duration(milliseconds: 1200),
  loop: 3,
  child: mySkeletonCard,
);
```

---

## 14. Zero-Dependency In-Memory Cache Engine (`AppCache`)

High-performance, hardware-accelerated in-memory cache engine with configurable eviction algorithms, TTL expiration, single-flight request coalescing, and isolated buckets:

```dart
// 1. Basic typed storage & retrieval:
AppCache.set('user_123', userData, ttl: const Duration(minutes: 10));
final user = AppCache.get<User>('user_123');
final bool hasUser = AppCache.has('user_123');

// 2. Atomic Cache-Aside with Single-Flight Request Coalescing:
// If 5 concurrent async callers trigger getOrFetch for the same key,
// only 1 fetch execution runs; all 5 callers await and receive the same result!
final profile = await AppCache.getOrFetch<UserProfile>(
  'profile_42',
  () => api.fetchUserProfile(42),
  ttl: const Duration(minutes: 5),
);

// 3. Isolated Named Buckets with Custom Eviction:
final searchBucket = AppCache.bucket(
  'search_results',
  maxEntries: 50,
  evictionPolicy: CacheEvictionPolicy.lru, // .lru, .lfu, .fifo
  defaultTtl: const Duration(minutes: 15),
);

// 4. Invalidation & Maintenance:
AppCache.invalidate('user_123');
AppCache.invalidateWhere((key, value) => key.startsWith('temp_'));
final int expiredCount = AppCache.pruneExpired();
AppCache.clear();

// 5. Performance Metrics & Hit Rates:
final stats = AppCache.stats;
print('Hit rate: ${stats.hitRate * 100}%');
print('Hits: ${stats.hits}, Misses: ${stats.misses}, Evictions: ${stats.evictions}');

// 6. Root App facade accessors:
App.cache.set('key', value);
final bucket = App.cacheBucket('images', maxEntries: 200);
```

**Key Durability & Performance Guarantees:**
- **High-Resolution Monotonic Clock:** TTL calculations use `Stopwatch` monotonic microseconds instead of system wall-clock time (`DateTime.now()`), rendering cache validity 100% immune to device system clock tampering, timezone shifts, and NTP synchronizations.
- **Generation-Guarded Clears:** Calling `AppCache.clear()` increments an internal generation counter. Any in-flight asynchronous fetch started before the clear is automatically discarded upon completion and will never resurrect stale data into an emptied cache.
- **Clean Request Coalescing Metrics:** Concurrent callers awaiting a shared in-flight fetch increment `hits` (saved network roundtrips) without inflating or mutating miss counters.

---

## 15. Strict Rules & Anti-Patterns for AI Agents

1. **NEVER add 3rd-party dependencies for supported features**:
   - Do NOT install `get`, `provider`, `intl`, `flutter_screenutil`, `shared_preferences`, `flutter_dotenv`, `shimmer`, or caching packages. AppForge handles all of these natively.
2. **DO NOT pass `BuildContext` to `App.*` methods**:
   - `App.to()`, `App.snackbar()`, `App.dialog()`, and `App.setLocale()` are context-free.
3. **DO NOT wrap large tree roots in `Watch`**:
   - Only wrap atomic leaf widgets that consume `.value`.
4. **DO NOT mutate `.obs` without notifying if using raw collections**:
   - When modifying an internal list/map (`items.add(...)`), call `items.refresh()` or use `items.value = [...]`.
5. **Automatic Phone Number & Hashtag/Handle Isolation**:
   - Calling `.tr` or `.trParams` on phone numbers (`+974 5500 1234`), hashtags (`#AppForge`), or user handles (`@user`) automatically applies Unicode UAX #9 directional isolation in RTL layouts with zero manual flags or extra method calls. For untranslated raw literals outside `.tr`, `.asPhone` and `.asTag` are available.
6. **DO NOT write custom regex for Arabic diacritics**:
   - Always use `.stripTashkeel`, `.stripTatweel`, `.normalizeArabic`, or `.fuzzyContainsArabic`.
