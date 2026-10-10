#import <Foundation/Foundation.h>
#import "../../NCE_ALL/Utility/NCELocalization.h"
#import "../../NCE_ALL/Utility/NCEWordResourceStore.h"

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        fprintf(stderr, "%s\n", message.UTF8String);
        exit(1);
    }
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        Require(argc == 2, @"Usage: localization-test APP_RESOURCE_DIRECTORY");
        NSString *root = @(argv[1]);
        NSArray *cases = @[
            @[@"system", @[@"zh-Hant-TW"], @"zh-Hant"],
            @[@"system", @[@"zh-HK"], @"zh-Hant"],
            @[@"system", @[@"zh_MO"], @"zh-Hant"],
            @[@"system", @[@"zh-TW"], @"zh-Hant"],
            @[@"system", @[@"zh-Hans-HK"], @"zh-Hans"],
            @[@"system", @[@"zh-Hant-CN"], @"zh-Hant"],
            @[@"system", @[@"zh-SG"], @"zh-Hans"],
            @[@"system", @[@"zh-CN"], @"zh-Hans"],
            @[@"system", @[@"en-US", @"zh-Hant"], @"zh-Hant"],
            @[@"system", @[@"en-US"], @"zh-Hans"],
            @[@"system", @[], @"zh-Hans"],
            @[@"system", @[@"ja"], @"ja"],
            @[@"system", @[@"ja-JP", @"zh-Hant"], @"ja"],
            @[@"system", @[@"ko_KR", @"ja"], @"ko"],
            @[@"system", @[@"en-US", @"ko-KR"], @"ko"],
            @[@"system", @[@"zh-TW", @"ja"], @"zh-Hant"],
            @[@"system", @[@"fr-FR"], @"zh-Hans"],
            @[@"ja", @[@"ko-KR"], @"ja"],
            @[@"ko", @[@"zh-Hans"], @"ko"],
            @[@"zh-Hans", @[@"zh-Hant"], @"zh-Hans"],
            @[@"zh-Hant", @[@"zh-Hans"], @"zh-Hant"]
        ];
        for (NSArray *item in cases) {
            Require([[NCELocalization languageCodeForPreference:item[0] preferredLanguages:item[1]] isEqual:item[2]],
                    [NSString stringWithFormat:@"Wrong language resolution: %@", item]);
        }
        NCELocalization *localization = [[NCELocalization alloc] initWithResourceDirectory:root];
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id originalPreference = [defaults objectForKey:@"NCELanguagePreference"];
        [NCELocalization setLanguagePreference:@"zh-Hans"];
        Require([[localization stringForKey:@"设置"] isEqual:@"设置"], @"Simplified UI missing");
        Require([[localization localizedChineseText:@"n.软件"] isEqual:@"n.软件"], @"Simplified text changed");
        Require([localization traditionalImagePathForWord:@"dignity"] == nil, @"Hans must use original images");

        NSDictionary *index = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"data/words/resource-index.json"]] options:0 error:nil];
        NCEWordResourceStore *store = [[NCEWordResourceStore alloc] initWithRootDirectory:[root stringByAppendingPathComponent:@"data/words"]];
        NSMutableDictionary *audio = [NSMutableDictionary dictionary];
        NSMutableDictionary *images = [NSMutableDictionary dictionary];
        for (NSString *word in index[@"words"]) {
            Require([store audioPathForWord:word] != nil, [@"Missing original audio: " stringByAppendingString:word]);
            Require([store imagePathForWord:word] != nil, [@"Missing original image: " stringByAppendingString:word]);
            audio[word] = [store audioPathForWord:word];
            images[word] = [store imagePathForWord:word];
        }
        [NCELocalization setLanguagePreference:@"zh-Hant"];
        Require([[localization stringForKey:@"设置"] isEqual:@"設定"], @"Traditional UI missing");
        Require([[localization localizedChineseText:@"n.软件"] isEqual:@"n.軟體"], @"Traditional terminology override missing");
        Require([[localization localizedChineseText:@"unknown English"] isEqual:@"unknown English"], @"English fallback changed");
        Require([localization localizedChineseText:nil] == nil, @"nil text must be safe");
        Require([[localization stringForKey:@"unregistered-key"] isEqual:@"unregistered-key"], @"Unknown UI key must fall back");
        [NCELocalization setLanguagePreference:@"invalid"];
        Require([NCELocalization.languagePreference isEqual:@"zh-Hant"], @"Invalid preferences must be ignored");

        NSDictionary *content = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"data/localizations/zh-Hant.json"]] options:0 error:nil];
        NSDictionary *texts = content[@"texts"];
        for (NSString *source in texts) {
            Require([[localization localizedChineseText:source] isEqual:texts[source]], [@"Unresolved content: " stringByAppendingString:source]);
        }
        for (NSString *word in index[@"words"]) {
            Require([[store audioPathForWord:word] isEqual:audio[word]], @"Audio identity changed with language");
            NSString *relative = content[@"images"][word];
            NSString *expected = relative ? [[root stringByAppendingPathComponent:@"data/words"] stringByAppendingPathComponent:relative] : images[word];
            Require([[store imagePathForWord:word] isEqual:expected], [@"Unresolved localized image: " stringByAppendingString:word]);
        }
        Require([[store translationForWord:@"anchor" fallback:@"corrupt"] isEqual:@"v.拋錨；n.錨"], @"Editorial correction was not localized");
        Require([[store sourceTranslationForWord:@"anchor" fallback:@"corrupt"] isEqual:@"v.抛锚；n.锚"], @"Search needs the corrected Simplified meaning");
        Require([store answer:@"New Jersey" matchesWord:@"Mew Jersey"], @"Legacy English key compatibility regressed");
        Require([store imagePathForWord:@"../escape"] == nil, @"Unsafe image key must fail");

        NSString *fixture = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSFileManager *files = NSFileManager.defaultManager;
        Require([files createDirectoryAtPath:[fixture stringByAppendingPathComponent:@"jpg"] withIntermediateDirectories:YES attributes:nil error:nil], @"Cannot create fallback fixture");
        NSDictionary *fixtureIndex = @{@"format_version": @1, @"words": @{@"dignity": index[@"words"][@"dignity"]}};
        NSData *fixtureData = [NSJSONSerialization dataWithJSONObject:fixtureIndex options:0 error:nil];
        Require([fixtureData writeToFile:[fixture stringByAppendingPathComponent:@"resource-index.json"] atomically:YES], @"Cannot write fallback index");
        NSString *originalImage = [fixture stringByAppendingPathComponent:index[@"words"][@"dignity"][@"image"]];
        NSString *localizedImage = [fixture stringByAppendingPathComponent:content[@"images"][@"dignity"]];
        Require([files copyItemAtPath:images[@"dignity"] toPath:originalImage error:nil], @"Cannot copy original fixture image");
        NCEWordResourceStore *fallbackStore = [[NCEWordResourceStore alloc] initWithRootDirectory:fixture];
        Require([[fallbackStore imagePathForWord:@"dignity"] isEqual:originalImage], @"Missing Traditional image must fall back to original");
        Require([files createDirectoryAtPath:localizedImage withIntermediateDirectories:NO attributes:nil error:nil], @"Cannot create invalid image fixture");
        Require([[fallbackStore imagePathForWord:@"dignity"] isEqual:originalImage], @"Directory instead of Traditional image must fall back to original");
        Require([files removeItemAtPath:localizedImage error:nil], @"Cannot clear invalid image fixture");
        NSString *localizedSource = [[root stringByAppendingPathComponent:@"data/words"] stringByAppendingPathComponent:content[@"images"][@"dignity"]];
        Require([files copyItemAtPath:localizedSource toPath:localizedImage error:nil], @"Cannot copy Traditional fixture image");
        Require([[fallbackStore imagePathForWord:@"dignity"] isEqual:localizedImage], @"Available Traditional image must take priority");
        [NCELocalization setLanguagePreference:@"zh-Hans"];
        Require([[fallbackStore imagePathForWord:@"dignity"] isEqual:originalImage], @"Simplified mode must retain the original image");
        [NCELocalization setLanguagePreference:@"zh-Hant"];
        Require([files removeItemAtPath:originalImage error:nil], @"Cannot clear original fixture image");
        Require([[fallbackStore imagePathForWord:@"dignity"] isEqual:localizedImage], @"Traditional image must work without the original file");
        Require([files removeItemAtPath:localizedImage error:nil], @"Cannot clear Traditional fixture image");
        Require([fallbackStore imagePathForWord:@"dignity"] == nil, @"Both image files missing must be safe");
        Require([files removeItemAtPath:fixture error:nil], @"Cannot remove fallback fixture");

        NSString *empty = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [NSFileManager.defaultManager createDirectoryAtPath:[empty stringByAppendingPathComponent:@"data/localizations"] withIntermediateDirectories:YES attributes:nil error:nil];
        [@"[]" writeToFile:[empty stringByAppendingPathComponent:@"data/localizations/zh-Hant.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NCELocalization *missing = [[NCELocalization alloc] initWithResourceDirectory:empty];
        Require([[missing stringForKey:@"设置"] isEqual:@"设置"], @"Missing tables must fall back");
        Require([[missing localizedChineseText:@"n.软件"] isEqual:@"n.软件"], @"Malformed overlay must fall back");
        Require([missing traditionalImagePathForWord:@"dignity"] == nil, @"Malformed overlay must not fabricate images");
        [NSFileManager.defaultManager removeItemAtPath:empty error:nil];
        if (originalPreference) [defaults setObject:originalPreference forKey:@"NCELanguagePreference"];
        else [defaults removeObjectForKey:@"NCELanguagePreference"];
        printf("Passed %lu language cases, %lu content entries and %lu word lookups in both scripts.\n",
               (unsigned long)cases.count, (unsigned long)texts.count, (unsigned long)[index[@"words"] count]);
        printf("Passed 6 Traditional image priority and original-image fallback checks.\n");
    }
    return 0;
}
