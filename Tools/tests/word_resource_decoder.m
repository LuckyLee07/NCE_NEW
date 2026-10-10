#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 3) return 2;
        NSString *root = @(argv[1]);
        NSMutableDictionary *results = [NSMutableDictionary dictionary];
        NSUInteger failures = 0;
        for (NSString *kind in @[@"wav", @"jpg"]) {
            NSString *directory = [root stringByAppendingPathComponent:kind];
            NSMutableArray *checks = [NSMutableArray array];
            NSArray *filenames = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]
                                 sortedArrayUsingSelector:@selector(compare:)];
            for (NSString *filename in filenames) {
                if (![filename.pathExtension isEqual:kind]) continue;
                @autoreleasepool {
                    NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:filename]];
                    NSMutableDictionary *check = [@{@"file": filename} mutableCopy];
                    BOOL valid = NO;
                    if ([kind isEqual:@"wav"]) {
                        NSError *error = nil;
                        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
                        valid = player && isfinite(player.duration) && player.duration > 0;
                        check[@"duration_seconds"] = @(player.duration);
                        if (error) check[@"error"] = error.localizedDescription;
                    } else {
                        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
                        CGImageRef image = source ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
                        valid = image && CGImageGetWidth(image) > 0 && CGImageGetHeight(image) > 0;
                        if (image) {
                            check[@"width"] = @(CGImageGetWidth(image));
                            check[@"height"] = @(CGImageGetHeight(image));
                            if ([filename rangeOfString:@"--[0-9a-f]{12}\\.jpg$" options:NSRegularExpressionSearch].location != NSNotFound) {
                                size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
                                if (width > 512 || height > 512) valid = NO;
                                else {
                                    UInt8 *pixels = calloc(width * height, 4);
                                    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
                                    CGContextRef context = pixels ? CGBitmapContextCreate(pixels, width, height, 8, width * 4, space,
                                        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big) : NULL;
                                    NSUInteger ink = 0, white = 0;
                                    int darkest = 255, lightest = 0;
                                    if (context) {
                                        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
                                        for (size_t index = 0; index < width * height; index++) {
                                            int brightness = (pixels[index * 4] + pixels[index * 4 + 1] + pixels[index * 4 + 2]) / 3;
                                            darkest = MIN(darkest, brightness); lightest = MAX(lightest, brightness);
                                            if (brightness < 235) ink++;
                                            if (brightness > 245) white++;
                                        }
                                        CGContextRelease(context);
                                    }
                                    BOOL nonblank = context && lightest - darkest > 12 && ink > 10 && white > 10;
                                    check[@"nonblank"] = @(nonblank);
                                    check[@"ink_pixels"] = @(ink);
                                    valid = valid && nonblank;
                                    CGColorSpaceRelease(space);
                                    free(pixels);
                                }
                            }
                            CGImageRelease(image);
                        }
                        if (source) CFRelease(source);
                    }
                    check[@"valid"] = @(valid);
                    if (!valid) failures++;
                    [checks addObject:check];
                }
            }
            results[kind] = checks;
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (![data writeToFile:@(argv[2]) options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "%s\n", error.description.UTF8String);
            return 2;
        }
        printf("Decoded %lu audio files and %lu images; invalid=%lu.\n",
               (unsigned long)[results[@"wav"] count], (unsigned long)[results[@"jpg"] count], (unsigned long)failures);
        return failures ? 1 : 0;
    }
}
