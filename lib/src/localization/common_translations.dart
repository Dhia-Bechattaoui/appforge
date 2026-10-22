/// Built-in standard UI translations for commonly used application words.
///
/// Ensures that essential actions and statuses (e.g. Save, Cancel, Delete, Back, Loading)
/// are available immediately out of the box in English and Arabic without manual boilerplate.
library;

/// Built-in fallback dictionary of universal mobile UI terms.
class AppCommonTranslations {
  AppCommonTranslations._();

  /// Standard translations mapped by 2-letter language code.
  static const Map<String, Map<String, String>> keys = {
    'en': {
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'confirm': 'Confirm',
      'back': 'Back',
      'next': 'Next',
      'previous': 'Previous',
      'done': 'Done',
      'close': 'Close',
      'search': 'Search',
      'loading': 'Loading...',
      'retry': 'Retry',
      'settings': 'Settings',
      'edit': 'Edit',
      'share': 'Share',
      'copy': 'Copy',
      'refresh': 'Refresh',
      'submit': 'Submit',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'info': 'Information',
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',
    },
    'ar': {
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'confirm': 'تأكيد',
      'back': 'رجوع',
      'next': 'التالي',
      'previous': 'السابق',
      'done': 'تم',
      'close': 'إغلاق',
      'search': 'بحث',
      'loading': 'جارٍ التحميل...',
      'retry': 'إعادة المحاولة',
      'settings': 'الإعدادات',
      'edit': 'تعديل',
      'share': 'مشاركة',
      'copy': 'نسخ',
      'refresh': 'تحديث',
      'submit': 'إرسال',
      'error': 'خطأ',
      'success': 'نجاح',
      'warning': 'تنبيه',
      'info': 'معلومات',
      'yes': 'نعم',
      'no': 'لا',
      'ok': 'حسناً',
    },
  };

  /// Resolves [key] from common translations for [languageCode].
  ///
  /// Supports both standard terms (`'close'`, `'ok'`, `'cancel'`)
  /// and prefixed aliases (`'common_close'`, `'common_ok'`, `'common_cancel'`).
  static String? resolve(String key, String languageCode) {
    final dict = keys[languageCode];
    if (dict == null) return null;

    final direct = dict[key];
    if (direct != null) return direct;

    if (key.startsWith('common_') && key.length > 7) {
      final stripped = key.substring(7);
      return dict[stripped];
    }
    return null;
  }

  /// Returns whether [key] is recognized as a universal built-in translation key
  /// (with or without `'common_'` prefix).
  static bool isCommonKey(String key) {
    final stripped =
        (key.startsWith('common_') && key.length > 7) ? key.substring(7) : key;
    return keys.values.any((dict) => dict.containsKey(stripped));
  }
}
