#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

// Reproducible image slicing/resizing, never generative drawing or lossy encoding.
static void Require(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "%s\n", message.UTF8String); exit(1); }
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        Require(argc == 3, @"Usage: export-academy-atlas JOB.json OUTPUT_DIRECTORY");
        NSData *json = [NSData dataWithContentsOfFile:@(argv[1])];
        NSDictionary *job = json ? [NSJSONSerialization JSONObjectWithData:json options:0 error:nil] : nil;
        Require([job[@"cells"] isKindOfClass:NSArray.class], @"Invalid atlas job");
        NSURL *url = [NSURL fileURLWithPath:job[@"original_generated"]];
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
        CGImageRef image = source ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
        Require(image != NULL, @"Cannot decode generated atlas");
        size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        Require(width == height && width % 2 == 0 && width >= 640, @"Atlas must be even and square, >= 640 px");
        NSMutableArray *encoded = [NSMutableArray array];
        NSMutableSet *names = [NSMutableSet set];
        NSString *bookPrefix = nil;
        for (NSInteger book = 1; book <= 4; book++) {
            NSString *prefix = [NSString stringWithFormat:@"academy-b%ld-", (long)book];
            if ([job[@"id"] isKindOfClass:NSString.class] && [job[@"id"] hasPrefix:prefix]) {
                bookPrefix = prefix;
                break;
            }
        }
        Require(bookPrefix != nil, @"Atlas job ID must identify Book 1–4");
        for (NSDictionary *cell in job[@"cells"]) {
            // Reviewed replacement atlases own these filenames on replay.
            if (cell[@"superseded_by"]) continue;
            NSInteger index = [cell[@"index"] integerValue];
            NSString *filename = cell[@"filename"];
            Require(index >= 0 && index < 4 && [filename hasPrefix:bookPrefix] &&
                    [filename.pathExtension isEqual:@"png"] && [filename.lastPathComponent isEqual:filename] &&
                    ![names containsObject:filename], @"Invalid or duplicate cell");
            [names addObject:filename];
            CGImageRef tile = CGImageCreateWithImageInRect(image, CGRectMake((index % 2) * width / 2, (index / 2) * height / 2, width / 2, height / 2));
            CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef context = CGBitmapContextCreate(NULL, 320, 320, 8, 0, color, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
            Require(tile && context, @"Cannot allocate tile");
            CGContextSetRGBFillColor(context, 1, 1, 1, 1); CGContextFillRect(context, CGRectMake(0,0,320,320));
            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            CGContextDrawImage(context, CGRectMake(0,0,320,320), tile);
            CGImageRef resized = CGBitmapContextCreateImage(context);
            NSMutableData *data = [NSMutableData data];
            CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.png"), 1, NULL);
            CGImageDestinationAddImage(destination, resized, NULL);
            Require(CGImageDestinationFinalize(destination), @"PNG encoding failed");
            Require(data.length <= 200000, [NSString stringWithFormat:@"%@ exceeds 200 KB (%lu bytes); regenerate with simpler shading",cell[@"word"],(unsigned long)data.length]);
            [encoded addObject:@{@"filename":filename,@"data":data,@"word":cell[@"word"]}];
            CFRelease(destination); CGImageRelease(resized); CGContextRelease(context);
            CGColorSpaceRelease(color); CGImageRelease(tile);
        }
        NSString *directory = @(argv[2]);
        Require([NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil], @"Cannot create output directory");
        for (NSDictionary *entry in encoded) {
            NSString *path = [directory stringByAppendingPathComponent:entry[@"filename"]];
            NSData *existing = [NSData dataWithContentsOfFile:path];
            Require(!existing || [existing isEqual:entry[@"data"]], [NSString stringWithFormat:@"Refusing to overwrite differing tile: %@",path]);
        }
        for (NSDictionary *entry in encoded) {
            NSString *path = [directory stringByAppendingPathComponent:entry[@"filename"]];
            if (![NSFileManager.defaultManager fileExistsAtPath:path])
                Require([entry[@"data"] writeToFile:path options:NSDataWritingWithoutOverwriting error:nil], @"Cannot write PNG");
            printf("%s: %lu bytes\n", [entry[@"word"] UTF8String], (unsigned long)[entry[@"data"] length]);
        }
        CGImageRelease(image); CFRelease(source);
    }
    return 0;
}
