#import "NCEWordResourceStore.h"
#import "NCELocalization.h"

@interface NCEWordResourceStore ()
@property (nonatomic, copy) NSString *rootDirectory;
@property (nonatomic, copy) NSDictionary *wordIndex;
@property (nonatomic, copy) NSDictionary *editorialOverrides;
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

- (NSString *)displayNameForWord:(NSString *)word
{
    if (!word.length) return word;
    id record = self.editorialOverrides[word];
    id value = [record isKindOfClass:NSDictionary.class] ? record[@"display"] : nil;
    return [value isKindOfClass:NSString.class] && [value length] ? value : word;
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
