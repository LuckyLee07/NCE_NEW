#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const NCELanguagePreferenceDidChangeNotification;

@interface NCELocalization : NSObject
+ (instancetype)sharedLocalization;
+ (NSString *)languagePreference;
+ (void)setLanguagePreference:(NSString *)preference;
+ (NSString *)languageCodeForPreference:(NSString *)preference preferredLanguages:(NSArray<NSString *> *)languages;
- (instancetype)initWithResourceDirectory:(NSString *)directory;
- (NSString *)languageCode;
- (NSString *)stringForKey:(NSString *)key;
- (nullable NSString *)localizedChineseText:(nullable NSString *)text;
- (nullable NSString *)traditionalChineseText:(nullable NSString *)text;
- (nullable NSString *)localizedText:(nullable NSString *)text languageCode:(NSString *)languageCode;
- (nullable NSString *)localizedWordTranslation:(NSString *)word fallback:(nullable NSString *)text;
- (nullable NSString *)localizedLessonText:(NSString *)sentence fallback:(nullable NSString *)text;
- (nullable NSString *)localizedImagePathForWord:(NSString *)word;
- (nullable NSString *)traditionalImagePathForWord:(NSString *)word;
@end

FOUNDATION_EXPORT NSString *NCELocalizedString(NSString *key);
FOUNDATION_EXPORT NSString *_Nullable NCEChineseText(NSString *_Nullable text);

NS_ASSUME_NONNULL_END
