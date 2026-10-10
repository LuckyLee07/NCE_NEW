#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 3) return 2;
        NSURL *url = [NSURL fileURLWithPath:@(argv[1])];
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
        CGImageRef image = source ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
        if (!image) return 3;
        size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        if (width != height || width < 256 || width > 8192 || width % 2) return 4;
        for (NSUInteger index = 0; index < 4; index++) {
            NSString *path = [NSString stringWithFormat:@"%@-%lu.png", @(argv[2]), (unsigned long)index];
            if ([NSFileManager.defaultManager fileExistsAtPath:path]) return 5;
        }
        for (NSUInteger index = 0; index < 4; index++) {
            CGImageRef tile = CGImageCreateWithImageInRect(image, CGRectMake((index % 2) * width / 2, (index / 2) * height / 2, width / 2, height / 2));
            CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
            CGContextRef context = CGBitmapContextCreate(NULL, 128, 128, 8, 128 * 4, color,
                kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            if (!context || !tile) return 6;
            CGContextSetRGBFillColor(context, 1, 1, 1, 1);
            CGContextFillRect(context, CGRectMake(0, 0, 128, 128));
            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            CGContextDrawImage(context, CGRectMake(0, 0, 128, 128), tile);
            CGImageRef scaled = CGBitmapContextCreateImage(context);
            NSMutableData *data = [NSMutableData data];
            CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.png"), 1, NULL);
            if (!destination || !scaled) return 6;
            CGImageDestinationAddImage(destination, scaled, NULL);
            if (!CGImageDestinationFinalize(destination)) return 6;
            NSString *path = [NSString stringWithFormat:@"%@-%lu.png", @(argv[2]), (unsigned long)index];
            if (![data writeToFile:path options:NSDataWritingWithoutOverwriting error:nil]) return 7;
            CFRelease(destination); CGImageRelease(scaled); CGContextRelease(context);
            CGColorSpaceRelease(color); CGImageRelease(tile);
        }
        CGImageRelease(image); CFRelease(source);
        printf("Split %lux%lu atlas into four 128x128 cells, ordered top-left, top-right, bottom-left, bottom-right.\n", (unsigned long)width, (unsigned long)height);
    }
    return 0;
}
