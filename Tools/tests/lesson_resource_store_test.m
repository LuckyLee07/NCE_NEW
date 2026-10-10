#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "../../NCE_ALL/Utility/NCELessonResourceStore.h"

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        fprintf(stderr, "%s\n", message.UTF8String);
        exit(1);
    }
}

static NSString *SHA256(NSData *data)
{
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger index = 0; index < sizeof(bytes); index++) [result appendFormat:@"%02x", bytes[index]];
    return result;
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        Require(argc == 3, @"Usage: reader-test PACK_DIRECTORY FIXTURE_DIRECTORY");
        NSString *directory = @(argv[1]);
        NSString *fixtures = @(argv[2]);
        NSError *error = nil;
        NSData *manifestData = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:@"manifest.json"]];
        NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&error];
        Require(manifest != nil, error.description);
        NCELessonResourceStore *store = [[NCELessonResourceStore alloc] initWithResourceDirectory:directory];
        NSUInteger count = 0;
        NSUInteger decoded = 0;
        NSMutableDictionary *firstSentences = [NSMutableDictionary dictionary];
        NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
        for (NSDictionary *pack in manifest[@"packs"]) {
            NSInteger bookID = [pack[@"book_id"] integerValue];
            NSArray *files = pack[@"files"];
            NSArray *audioFiles = [files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:
                ^BOOL(NSDictionary *record, NSDictionary *bindings) { return [record[@"path"] hasPrefix:@"mp3/"]; }]];
            firstSentences[@(bookID)] = [[audioFiles.firstObject[@"path"] lastPathComponent] stringByDeletingPathExtension];
            for (NSDictionary *record in files) {
                @autoreleasepool {
                    NSString *path = record[@"path"];
                    NSString *sentence = [path.lastPathComponent stringByDeletingPathExtension];
                    NSData *data;
                    error = nil;
                    if ([path hasPrefix:@"mp3/"]) {
                        data = [store audioDataForSentence:sentence bookID:bookID error:&error];
                    } else {
                        NSString *text = [store textForSentence:sentence bookID:bookID error:&error];
                        data = [text dataUsingEncoding:NSUTF8StringEncoding];
                        Require([text containsString:@"\uFF0D"], [NSString stringWithFormat:@"Invalid text: %@", path]);
                    }
                    Require(data != nil && error == nil, [NSString stringWithFormat:@"Read failed %@: %@", path, error]);
                    Require(data.length == [record[@"bytes"] unsignedIntegerValue] && [SHA256(data) isEqual:record[@"sha256"]],
                            [NSString stringWithFormat:@"Bytes changed: %@", path]);
                    count++;
                }
            }
            for (NSDictionary *record in @[audioFiles.firstObject, audioFiles.lastObject]) {
                NSString *sentence = [[record[@"path"] lastPathComponent] stringByDeletingPathExtension];
                NSData *data = [store audioDataForSentence:sentence bookID:bookID error:&error];
                AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:data error:&error];
                Require(player != nil && player.duration > 0, [NSString stringWithFormat:@"Audio decode failed: %@", error]);
                decoded++;
            }
        }
        dispatch_apply(64, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
            @autoreleasepool {
                NSInteger book = (NSInteger)(index % 4) + 1;
                NSError *threadError = nil;
                Require([store audioDataForSentence:firstSentences[@(book)] bookID:book error:&threadError] != nil,
                        threadError.description);
            }
        });
        for (NSString *caseName in @[@"missing", @"corrupt", @"duplicate", @"oversized", @"invalidtext", @"badcrc", @"missingentry"]) {
            NCELessonResourceStore *invalid = [[NCELessonResourceStore alloc] initWithResourceDirectory:
                                              [fixtures stringByAppendingPathComponent:caseName]];
            NSError *failure = nil;
            id result = [caseName isEqual:@"invalidtext"]
                ? [invalid textForSentence:@"N1_L1_sentence" bookID:1 error:&failure]
                : [invalid audioDataForSentence:@"N1_L1_sentence" bookID:1 error:&failure];
            Require(result == nil && [failure.domain isEqual:NCELessonResourceErrorDomain],
                    [NSString stringWithFormat:@"Expected safe failure: %@", caseName]);
        }
        error = nil;
        Require([store audioDataForSentence:@"N1_L1_sentence" bookID:0 error:&error] == nil && error != nil,
                @"Invalid book ID must fail");
        error = nil;
        Require([store audioDataForSentence:@"N1_../bad" bookID:1 error:&error] == nil && error != nil,
                @"Invalid entry path must fail");
        printf("Read and hashed %lu entries; decoded %lu audio samples; concurrency and 9 error cases passed (%.2fs).\n",
               (unsigned long)count, (unsigned long)decoded, NSDate.timeIntervalSinceReferenceDate - start);
    }
    return 0;
}
