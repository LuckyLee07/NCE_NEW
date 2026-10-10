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
        Require(argc == 2, @"Usage: east-asian-localization-test APP_RESOURCES");
        NSString *root = @(argv[1]);
        NCELocalization *localization = [[NCELocalization alloc] initWithResourceDirectory:root];
        NCEWordResourceStore *store = [[NCEWordResourceStore alloc] initWithRootDirectory:[root stringByAppendingPathComponent:@"data/words"]];
        id original = [NSUserDefaults.standardUserDefaults objectForKey:@"NCELanguagePreference"];
        NSDictionary *index = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"data/words/resource-index.json"]] options:0 error:nil];
        [NCELocalization setLanguagePreference:@"zh-Hans"];
        NSMutableDictionary *audio = [NSMutableDictionary dictionary];
        for (NSString *word in index[@"words"]) audio[word] = [store audioPathForWord:word];
        for (NSString *code in @[@"ja", @"ko"]) {
            [NCELocalization setLanguagePreference:code];
            Require([NCELocalization.languagePreference isEqual:code], @"Language preference was rejected");
            Require([[localization languageCode] isEqual:code], @"Explicit choice must override system");
            Require([[localization stringForKey:@"设置"] isEqual:[code isEqual:@"ja"] ? @"設定" : @"설정"], @"Localized settings missing");
            NSDictionary *overlay = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:[NSString stringWithFormat:@"data/localizations/%@.json", code]]] options:0 error:nil];
            for (NSString *word in overlay[@"word_meanings"]) {
                NSDictionary *meanings = overlay[@"word_meanings"][word];
                for (NSString *source in meanings) {
                    NSString *value = [localization localizedWordTranslation:word fallback:source];
                    Require([value isEqual:meanings[source]], [@"Unresolved word sense: " stringByAppendingString:word]);
                    Require([[localization localizedWordTranslation:word fallback:value] isEqual:value], @"Already localized meaning changed");
                }
                Require([[store audioPathForWord:word] isEqual:audio[word]], @"English audio changed with language");
                NSString *image = [store imagePathForWord:word];
                Require(image.length > 0, @"Image missing");
                NSString *relative = overlay[@"images"][word];
                if (relative) Require([image hasSuffix:relative], @"Localized picture not selected");
            }
            for (NSString *sentence in overlay[@"sentences"]) {
                Require([[localization localizedLessonText:sentence fallback:@"source"] isEqual:overlay[@"sentences"][sentence]], @"Sentence identity lookup failed");
            }
            Require([[store translationForWord:@"software" fallback:@"n.软件"] isEqual:overlay[@"words"][@"software"]], @"Store did not use localized meaning");
            Require([[localization localizedChineseText:@"unregistered English"] isEqual:@"unregistered English"], @"Unknown text fallback changed");
            Require([localization localizedChineseText:nil] == nil, @"nil input failed");
            printf("Passed %s: %lu word keys, %lu sentence lookups, image selection and English audio identity.\n", code.UTF8String,
                   (unsigned long)[overlay[@"words"] count], (unsigned long)[overlay[@"sentences"] count]);
        }
        if (original) [NSUserDefaults.standardUserDefaults setObject:original forKey:@"NCELanguagePreference"];
        else [NSUserDefaults.standardUserDefaults removeObjectForKey:@"NCELanguagePreference"];
    }
    return 0;
}
