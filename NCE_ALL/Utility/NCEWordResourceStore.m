#import "NCEWordResourceStore.h"
#import "NCELocalization.h"

@interface NCEWordResourceStore ()
@property (nonatomic, copy) NSString *rootDirectory;
@property (nonatomic, copy) NSDictionary *wordIndex;
@property (nonatomic, copy) NSDictionary *editorialOverrides;
@property (nonatomic, copy) NSDictionary *phonetics;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSDictionary *> *academyBooks;
- (NSString *)existingPathForRelativePath:(NSString *)relativePath extension:(NSString *)extension;
@end

@implementation NCEWordResourceStore

+ (instancetype)sharedStore
{
    static NCEWordResourceStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *directory = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"data/words"];
        store = [[self alloc] initWithRootDirectory:directory];
    });
    return store;
}

- (instancetype)initWithRootDirectory:(NSString *)directory
{
    self = [super init];
    if (self) {
        _rootDirectory = directory.copy;
        NSData *phoneticData = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:@"phonetics-pilot.json"]];
        id phonetics = phoneticData ? [NSJSONSerialization JSONObjectWithData:phoneticData options:0 error:nil] : nil;
        if ([phonetics isKindOfClass:NSDictionary.class] && [phonetics[@"format_version"] isEqual:@1] &&
            [phonetics[@"records"] isKindOfClass:NSDictionary.class]) _phonetics = [phonetics[@"records"] copy];
        // Reviewed volume files extend the pilot and replace only their own contexts.
        NSMutableDictionary *mergedPhonetics = [_phonetics mutableCopy] ?: [NSMutableDictionary dictionary];
        for (NSInteger book = 1; book <= 4; book++) {
            NSString *filename = [NSString stringWithFormat:@"phonetics-book%ld.json", (long)book];
            NSData *volumeData = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:filename]];
            id volume = volumeData ? [NSJSONSerialization JSONObjectWithData:volumeData options:0 error:nil] : nil;
            if (![volume isKindOfClass:NSDictionary.class] || ![volume[@"format_version"] isEqual:@1] ||
                ![volume[@"book_id"] isEqual:@(book)] || ![volume[@"records"] isKindOfClass:NSDictionary.class]) continue;
            NSString *prefix = [NSString stringWithFormat:@"%ld|", (long)book];
            for (id key in volume[@"records"]) {
                if ([key isKindOfClass:NSString.class] && [key hasPrefix:prefix])
                    mergedPhonetics[key] = volume[@"records"][key];
            }
        }
        _phonetics = mergedPhonetics.copy;
        NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:@"resource-index.json"]];
        id index = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([index isKindOfClass:NSDictionary.class] && [index[@"format_version"] isKindOfClass:NSNumber.class] &&
            [index[@"format_version"] integerValue] == 1 &&
            [index[@"words"] isKindOfClass:NSDictionary.class]) {
            _wordIndex = [index[@"words"] copy];
        }
        NSData *editorialData = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:@"editorial-overrides.json"]];
        id editorial = editorialData ? [NSJSONSerialization JSONObjectWithData:editorialData options:0 error:nil] : nil;
        if ([editorial isKindOfClass:NSDictionary.class] && [editorial[@"format_version"] isKindOfClass:NSNumber.class] &&
            [editorial[@"format_version"] integerValue] == 1 &&
            [editorial[@"overrides"] isKindOfClass:NSDictionary.class]) {
            _editorialOverrides = [editorial[@"overrides"] copy];
        }
        NSMutableDictionary *books = [NSMutableDictionary dictionary];
        for (NSInteger book = 1; book <= 4; book++) {
            NSString *filename = book == 1 ? @"academy-image-map.json" : [NSString stringWithFormat:@"academy-book%ld-image-map.json", (long)book];
            NSData *academyData = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:filename]];
            id academy = academyData ? [NSJSONSerialization JSONObjectWithData:academyData options:0 error:nil] : nil;
            if (![academy isKindOfClass:NSDictionary.class] || ![academy[@"format_version"] isKindOfClass:NSNumber.class] ||
                [academy[@"format_version"] integerValue] != 1 || ![academy[@"images"] isKindOfClass:NSDictionary.class] ||
                ![academy[@"hints"] isKindOfClass:NSDictionary.class] || ![academy[@"book_id"] isKindOfClass:NSNumber.class] ||
                [academy[@"book_id"] integerValue] != book) continue;
            books[@(book)] = @{@"images":academy[@"images"], @"hints":academy[@"hints"],
                @"captions":[academy[@"captions"] isKindOfClass:NSDictionary.class] ? academy[@"captions"] : @{},
                @"presentations":[academy[@"presentations"] isKindOfClass:NSDictionary.class] ? academy[@"presentations"] : @{}};
        }
        _academyBooks = books.copy;
    }
    return self;
}

- (NSString *)pathForWord:(NSString *)word field:(NSString *)field extension:(NSString *)extension
{
    if (!word.length || [word containsString:@"/"] || [word containsString:@"\\"] ||
        [word rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return nil;
    id record = self.wordIndex[word];
    NSString *relativePath;
    if ([record isKindOfClass:NSDictionary.class]) {
        id value = record[field];
        if (![value isKindOfClass:NSString.class]) return nil;
        relativePath = value;
    } else {
        // Compatibility for an older bundle without an index; never guess another word's case.
        relativePath = [NSString stringWithFormat:@"%@/%@.%@", extension, word, extension];
    }
    if ([field isEqual:@"image"]) {
        NSString *localized = [NCELocalization.sharedLocalization localizedImagePathForWord:word];
        NSString *localizedPath = [self existingPathForRelativePath:localized extension:extension];
        if (localizedPath) return localizedPath;
    }
    return [self existingPathForRelativePath:relativePath extension:extension];
}

- (NSString *)existingPathForRelativePath:(NSString *)relativePath extension:(NSString *)extension
{
    if (!relativePath.length) return nil;
    NSArray *components = [relativePath componentsSeparatedByString:@"/"];
    if (components.count != 2 || ![components[0] isEqual:extension] ||
        ![relativePath.pathExtension isEqual:extension] || [relativePath containsString:@"\\"] ||
        [components[1] isEqual:@".."] || [components[1] isEqual:@"."]) return nil;
    NSString *path = [self.rootDirectory stringByAppendingPathComponent:relativePath];
    BOOL directory = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&directory] && !directory ? path : nil;
}

- (NSString *)audioPathForWord:(NSString *)word
{
    return [self pathForWord:word field:@"audio" extension:@"wav"];
}

- (NSString *)imagePathForWord:(NSString *)word
{
    return [self pathForWord:word field:@"image" extension:@"jpg"];
}

- (NSString *)imagePathForWord:(NSString *)word bookId:(NSInteger)bookId
{
    if (!word.length || [word containsString:@"/"] || [word containsString:@"\\"] ||
        [word rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return nil;
    // Each book owns its sense mapping: bank/pool/key/spring must not cross by spelling.
    // Reviewed art and native hints take precedence over legacy bitmaps within their book.
    NSDictionary *academy = self.academyBooks[@(bookId)];
    if (academy) {
        if ([self visualHintForWord:word bookId:bookId]) return nil;
        id relative = academy[@"images"][word];
        if ([relative isKindOfClass:NSString.class]) {
            NSString *path = [self existingPathForRelativePath:relative extension:@"png"];
            if (path) return path;
        }
    }
    return [self imagePathForWord:word];
}

- (NSString *)visualHintForWord:(NSString *)word bookId:(NSInteger)bookId
{
    NSDictionary *academy = self.academyBooks[@(bookId)];
    if (!academy) return nil;
    if (!word.length || [word containsString:@"/"] || [word containsString:@"\\"] ||
        [word rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return nil;
    id hint = academy[@"hints"][word];
    return [hint isKindOfClass:NSString.class] && [hint length] ? hint : nil;
}

- (NSString *)visualCaptionForWord:(NSString *)word bookId:(NSInteger)bookId
{
    NSDictionary *academy = self.academyBooks[@(bookId)];
    if (!academy || ![self imagePathForWord:word bookId:bookId]) return nil;
    id value = academy[@"captions"][word];
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

- (NSString *)visualPresentationForWord:(NSString *)word bookId:(NSInteger)bookId
{
    NSDictionary *academy = self.academyBooks[@(bookId)];
    if (!academy || ![self imagePathForWord:word bookId:bookId]) return nil;
    id value = academy[@"presentations"][word];
    return [value isEqual:@"diagram"] || [value isEqual:@"scene"] ? value : nil;
}

- (NSString *)displayNameForWord:(NSString *)word
{
    if (!word.length) return word;
    id record = self.editorialOverrides[word];
    id value = [record isKindOfClass:NSDictionary.class] ? record[@"display"] : nil;
    return [value isKindOfClass:NSString.class] && [value length] ? value : word;
}

- (NSString *)phoneticForWord:(NSString *)word bookId:(NSInteger)bookId lessonId:(NSInteger)lessonId
{
    if (!word.length || bookId < 1 || bookId > 4 || lessonId < 0) return nil;
    // A homograph in another lesson can have a different sense and pronunciation.
    id record = self.phonetics[[NSString stringWithFormat:@"%ld|%ld|%@", (long)bookId, (long)lessonId, word]];
    if (![record isKindOfClass:NSDictionary.class] ||
        (![record[@"status"] isEqual:@"source_checked"] && ![record[@"status"] isEqual:@"editorial_checked"]) ||
        ![record[@"accent"] isEqual:@"en-GB"]) return nil;
    id ipa = record[@"ipa"];
    if (![ipa isKindOfClass:NSString.class] || [ipa length] < 3 ||
        ![ipa hasPrefix:@"/"] || ![ipa hasSuffix:@"/"] ||
        [ipa rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return nil;
    return ipa;
}

- (NSString *)sourceTranslationForWord:(NSString *)word fallback:(NSString *)translation
{
    if (!word.length) return translation;
    id record = self.editorialOverrides[word];
    id value = [record isKindOfClass:NSDictionary.class] ? record[@"translation"] : nil;
    return [value isKindOfClass:NSString.class] && [value length] ? value : translation;
}

- (NSString *)translationForWord:(NSString *)word fallback:(NSString *)translation
{
    return [NCELocalization.sharedLocalization localizedWordTranslation:word
                    fallback:[self sourceTranslationForWord:word fallback:translation]];
}

- (BOOL)answer:(NSString *)answer matchesWord:(NSString *)word
{
    if (!word.length || !answer.length) return NO;
    NSString *trimmed = [answer stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *accepted = [NSMutableArray arrayWithObjects:word, [self displayNameForWord:word], nil];
    id record = self.editorialOverrides[word];
    id aliases = [record isKindOfClass:NSDictionary.class] ? record[@"answers"] : nil;
    if ([aliases isKindOfClass:NSArray.class]) [accepted addObjectsFromArray:aliases];
    return [accepted containsObject:trimmed];
}

@end
