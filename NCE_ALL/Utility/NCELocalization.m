#import "NCELocalization.h"

NSString *const NCELanguagePreferenceDidChangeNotification = @"NCELanguagePreferenceDidChange";
static NSString *const NCELanguagePreferenceKey = @"NCELanguagePreference";

@interface NCELocalization ()
@property (nonatomic, copy) NSDictionary *stringTables;
@property (nonatomic, copy) NSDictionary *contentTables;
@end

@implementation NCELocalization

+ (instancetype)sharedLocalization
{
    static NCELocalization *localization;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localization = [[self alloc] initWithResourceDirectory:NSBundle.mainBundle.resourcePath];
    });
    return localization;
}

+ (NSString *)languagePreference
{
    NSString *value = [NSUserDefaults.standardUserDefaults stringForKey:NCELanguagePreferenceKey];
    return [@[@"zh-Hans", @"zh-Hant", @"ja", @"ko"] containsObject:value] ? value : @"system";
}

+ (void)setLanguagePreference:(NSString *)preference
{
    if (![@[@"system", @"zh-Hans", @"zh-Hant", @"ja", @"ko"] containsObject:preference] ||
        [preference isEqual:[self languagePreference]]) return;
    [NSUserDefaults.standardUserDefaults setObject:preference forKey:NCELanguagePreferenceKey];
    [NSNotificationCenter.defaultCenter postNotificationName:NCELanguagePreferenceDidChangeNotification object:nil];
}

+ (NSString *)languageCodeForPreference:(NSString *)preference preferredLanguages:(NSArray<NSString *> *)languages
{
    if ([@[@"zh-Hans", @"zh-Hant", @"ja", @"ko"] containsObject:preference]) return preference;
    for (NSString *language in languages) {
        NSArray *parts = [[language.lowercaseString stringByReplacingOccurrencesOfString:@"_" withString:@"-"] componentsSeparatedByString:@"-"];
        if ([@[@"ja", @"ko"] containsObject:parts.firstObject]) return parts.firstObject;
        if (![parts.firstObject isEqual:@"zh"]) continue;
        if ([parts containsObject:@"hant"]) return @"zh-Hant";
        if ([parts containsObject:@"hans"]) return @"zh-Hans";
        if ([parts containsObject:@"tw"] || [parts containsObject:@"hk"] || [parts containsObject:@"mo"]) return @"zh-Hant";
        return @"zh-Hans";
    }
    // Use the first supported language; unsupported-only preferences retain the existing fallback.
    return @"zh-Hans";
}

- (instancetype)initWithResourceDirectory:(NSString *)directory
{
    self = [super init];
    if (self) {
        NSMutableDictionary *strings = [NSMutableDictionary dictionary];
        NSMutableDictionary *contents = [NSMutableDictionary dictionary];
        for (NSString *code in @[@"zh-Hans", @"zh-Hant", @"ja", @"ko"]) {
            NSString *path = [NSString stringWithFormat:@"%@.lproj/Localizable.strings", code];
            strings[code] = [NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:path]] ?: @{};
            NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"data/localizations/%@.json", code]]];
            id content = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if ([content isKindOfClass:NSDictionary.class] && [content[@"format_version"] isEqual:@1]) {
                contents[code] = content;
            }
        }
        _stringTables = strings.copy;
        _contentTables = contents.copy;
    }
    return self;
}

- (NSString *)languageCode
{
    return [self.class languageCodeForPreference:self.class.languagePreference preferredLanguages:NSLocale.preferredLanguages];
}

- (NSString *)stringForKey:(NSString *)key
{
    NSDictionary *table = self.stringTables[self.languageCode];
    id value = table[key];
    return [value isKindOfClass:NSString.class] && [value length] ? value : key;
}

- (NSString *)traditionalChineseText:(NSString *)text
{
    return [self localizedText:text languageCode:@"zh-Hant"];
}

- (NSString *)localizedText:(NSString *)text languageCode:(NSString *)languageCode
{
    if (!text.length || [languageCode isEqual:@"zh-Hans"]) return text;
    NSDictionary *content = self.contentTables[languageCode];
    id texts = content[@"texts"];
    id value = [texts isKindOfClass:NSDictionary.class] ? texts[text] : nil;
    value = value ?: self.stringTables[languageCode][text];
    return [value isKindOfClass:NSString.class] && [value length] ? value : text;
}

- (NSString *)localizedChineseText:(NSString *)text
{
    return [self localizedText:text languageCode:self.languageCode];
}

- (NSString *)valueForKey:(NSString *)key section:(NSString *)section
{
    if (!key.length) return nil;
    id table = self.contentTables[self.languageCode][section];
    id value = [table isKindOfClass:NSDictionary.class] ? table[key] : nil;
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

- (NSString *)localizedWordTranslation:(NSString *)word fallback:(NSString *)text
{
    id meanings = self.contentTables[self.languageCode][@"word_meanings"];
    id variants = [meanings isKindOfClass:NSDictionary.class] ? meanings[word] : nil;
    id value = [variants isKindOfClass:NSDictionary.class] && text ? variants[text] : nil;
    if ([value isKindOfClass:NSString.class] && [value length]) return value;
    if ([variants isKindOfClass:NSDictionary.class] && text && [[variants allValues] containsObject:text]) return text;
    return text.length ? [self localizedChineseText:text] : [self valueForKey:word section:@"words"];
}

- (NSString *)localizedLessonText:(NSString *)sentence fallback:(NSString *)text
{
    return [self valueForKey:sentence section:@"sentences"] ?: [self localizedChineseText:text];
}

- (NSString *)localizedImagePathForWord:(NSString *)word
{
    return [self valueForKey:word section:@"images"];
}

- (NSString *)traditionalImagePathForWord:(NSString *)word
{
    return [self.languageCode isEqual:@"zh-Hant"] ? [self localizedImagePathForWord:word] : nil;
}

@end

NSString *NCELocalizedString(NSString *key)
{
    return [NCELocalization.sharedLocalization stringForKey:key];
}

NSString *NCEChineseText(NSString *text)
{
    return [NCELocalization.sharedLocalization localizedChineseText:text];
}
