#import <Foundation/Foundation.h>
#import <Vision/Vision.h>

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 3) return 2;
        NSArray *paths = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:nil];
        if (![paths isKindOfClass:NSArray.class]) return 2;
        NSMutableDictionary *results = [NSMutableDictionary dictionary];
        NSCharacterSet *han = [NSCharacterSet characterSetWithRange:NSMakeRange(0x3400, 0x6C00)];
        for (NSString *path in paths) {
            @autoreleasepool {
                VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] init];
                request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                request.usesCPUOnly = YES;
#pragma clang diagnostic pop
                request.recognitionLanguages = @[@"zh-Hans", @"zh-Hant", @"en-US"];
                request.usesLanguageCorrection = NO;
                NSError *error = nil;
                VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithURL:[NSURL fileURLWithPath:path] options:@{}];
                if (![handler performRequests:@[request] error:&error]) {
                    fprintf(stderr, "OCR failed for %s: %s\n", path.UTF8String, error.description.UTF8String);
                    return 3;
                }
                NSMutableArray *texts = [NSMutableArray array];
                BOOL containsChinese = NO;
                for (VNRecognizedTextObservation *observation in request.results) {
                    NSString *text = [observation topCandidates:1].firstObject.string;
                    if (text.length) [texts addObject:text];
                    if ([text rangeOfCharacterFromSet:han].location != NSNotFound) containsChinese = YES;
                }
                results[path] = @{@"contains_chinese": @(containsChinese), @"recognized_text": texts};
            }
        }
        NSData *output = [NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingSortedKeys error:nil];
        if (![output writeToFile:@(argv[2]) atomically:YES]) return 4;
        printf("OCR checked %lu original pictures.\n", (unsigned long)paths.count);
    }
    return 0;
}
