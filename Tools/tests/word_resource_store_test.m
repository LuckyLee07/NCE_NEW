#import <Foundation/Foundation.h>
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
        Require(argc == 3, @"Usage: word-store-test RESOURCES AUDIT_REPORT");
        NSString *root = @(argv[1]);
        NSData *data = [NSData dataWithContentsOfFile:@(argv[2])];
        NSDictionary *report = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        Require(report != nil, @"Missing report");
        NCEWordResourceStore *store = [[NCEWordResourceStore alloc] initWithRootDirectory:root];
        NSUInteger audioCount = 0, imageCount = 0;
        for (NSDictionary *word in report[@"words"]) {
            for (NSString *kind in @[@"audio", @"image"]) {
                NSString *actual = [kind isEqual:@"audio"] ? [store audioPathForWord:word[@"word"]] : [store imagePathForWord:word[@"word"]];
                id path = word[kind][@"path"];
                NSString *status = word[kind][@"status"];
                if ([status isEqual:@"exact"] || [status isEqual:@"case_alias"] || [status isEqual:@"mapped"]) {
                    Require([actual isEqual:[root stringByAppendingPathComponent:path]],
                            [NSString stringWithFormat:@"Wrong %@ lookup: %@", kind, word[@"word"]]);
                    if ([kind isEqual:@"audio"]) audioCount++; else imageCount++;
                } else {
                    Require(actual == nil, [NSString stringWithFormat:@"Unexpected %@ lookup: %@", kind, word[@"word"]]);
                }
            }
        }
        Require([store audioPathForWord:@"../escape"] == nil, @"Traversal must fail");
        Require([store imagePathForWord:@"a/b"] == nil, @"Nested paths must fail");
        Require([[store displayNameForWord:@"Mew Jersey"] isEqual:@"New Jersey"], @"Corrected display name missing");
        Require([store answer:@"New Jersey" matchesWord:@"Mew Jersey"], @"Corrected spelling must be accepted");
        Require([store answer:@"Mew Jersey" matchesWord:@"Mew Jersey"], @"Legacy answer must remain compatible");
        Require([store answer:@" Saint Petersburg " matchesWord:@"St.Petersbrug"], @"Expanded place-name answer must be accepted");
        Require(![store answer:@"New York" matchesWord:@"Mew Jersey"], @"Wrong answers must still fail");
        Require([[store translationForWord:@"anchor" fallback:@"corrupt"] isEqual:@"v.抛锚；n.锚"], @"Corrupt translation override missing");
        Require([[store translationForWord:@"untouched" fallback:@"original"] isEqual:@"original"], @"Unrelated translations must remain unchanged");
        Require(![store answer:@"" matchesWord:@"handbag"], @"Empty answers must fail");
        Require([store displayNameForWord:nil] == nil, @"Missing display keys must be safe");
        Require([[store translationForWord:nil fallback:@"fallback"] isEqual:@"fallback"], @"Missing translation keys must use fallback");
        Require(![[store imagePathForWord:@"may"] isEqual:[store imagePathForWord:@"May"]], @"Modal and month must not share an image");
        Require(![[store imagePathForWord:@"South"] isEqual:[store imagePathForWord:@"south"]], @"State and direction must not share an image");
        printf("Matched %lu audio word keys and %lu image word keys, including explicit case aliases.\n",
               (unsigned long)audioCount, (unsigned long)imageCount);
    }
    return 0;
}
