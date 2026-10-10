#import <AppKit/AppKit.h>

static void DrawText(NSString *text, NSRect rect, CGFloat size, NSColor *color)
{
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    style.lineBreakMode = NSLineBreakByCharWrapping;
    NSDictionary *attributes;
    NSRect bounds;
    do {
        attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:size],
                       NSForegroundColorAttributeName: color,
                       NSParagraphStyleAttributeName: style};
        bounds = [text boundingRectWithSize:NSMakeSize(rect.size.width, CGFLOAT_MAX)
                                   options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes];
        if (bounds.size.height <= rect.size.height) break;
        size -= 0.5;
    } while (size >= 9);
    if (bounds.size.height > rect.size.height) {
        [NSException raise:@"CaptionOverflow" format:@"Caption does not fit: %@", text];
    }
    rect.origin.y += (rect.size.height - ceil(bounds.size.height)) / 2;
    rect.size.height = ceil(bounds.size.height);
    [text drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes];
}

static void Stroke(NSArray<NSValue *> *points, NSColor *color)
{
    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineWidth = 4;
    path.lineCapStyle = NSLineCapStyleRound;
    [path moveToPoint:points[0].pointValue];
    for (NSUInteger index = 1; index < points.count; index++) [path lineToPoint:points[index].pointValue];
    [color setStroke];
    [path stroke];
}

static NSValue *P(CGFloat x, CGFloat y) { return [NSValue valueWithPoint:NSMakePoint(x, y)]; }

static void DrawDiagram(NSString *name, NSString *word)
{
    NSColor *ink = [NSColor colorWithSRGBRed:0.13 green:0.42 blue:0.38 alpha:1];
    NSColor *accent = [NSColor colorWithSRGBRed:0.86 green:0.27 blue:0.25 alpha:1];
    [ink setFill];
    if ([name isEqual:@"calendar"] || [name isEqual:@"clock"]) {
        if ([name isEqual:@"calendar"]) {
            NSRect box = NSMakeRect(27, 49, 74, 65);
            NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:box xRadius:4 yRadius:4];
            outline.lineWidth = 3; [ink setStroke]; [outline stroke];
            NSRectFill(NSMakeRect(27, 96, 74, 18));
            NSArray *months = @[@"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December"];
            NSUInteger index = [months indexOfObject:word];
            if (index == NSNotFound) {
                for (NSInteger day = 0; day < 12; day++) NSRectFill(NSMakeRect(35 + (day % 4) * 15, 59 + (day / 4) * 11, 6, 6));
            } else {
                DrawText([NSString stringWithFormat:@"%lu", (unsigned long)index + 1], NSMakeRect(33, 56, 62, 34), 25, ink);
            }
        } else {
            NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(31, 48, 66, 66)];
            circle.lineWidth = 3; [ink setStroke]; [circle stroke];
            Stroke(@[P(64, 104), P(64, 80), P(84, 80)], ink);
            [accent setFill]; [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(60, 76, 8, 8)] fill];
        }
    } else if ([@[@"up", @"down", @"right", @"in", @"out"] containsObject:name]) {
        if ([name isEqual:@"up"]) {
            Stroke(@[P(64, 52), P(64, 111), P(43, 91)], ink);
            Stroke(@[P(64, 111), P(85, 91)], ink);
        } else if ([name isEqual:@"down"]) {
            Stroke(@[P(64, 112), P(64, 53), P(43, 73)], ink);
            Stroke(@[P(64, 53), P(85, 73)], ink);
        } else {
            Stroke(@[P(27, 80), P(98, 80), P(78, 100)], ink);
            Stroke(@[P(98, 80), P(78, 60)], ink);
            if ([name isEqual:@"in"]) Stroke(@[P(65, 110), P(107, 110), P(107, 50), P(65, 50)], accent);
            if ([name isEqual:@"out"]) Stroke(@[P(63, 110), P(21, 110), P(21, 50), P(63, 50)], accent);
        }
    } else if ([name isEqual:@"middle"] || [name isEqual:@"small"] || [name isEqual:@"big"]) {
        for (NSInteger index = 0; index < 5; index++) {
            BOOL highlight = [name isEqual:@"middle"] ? index == 2 : ([name isEqual:@"small"] ? index == 0 : index < 4);
            [(highlight ? accent : [NSColor colorWithWhite:0.82 alpha:1]) setFill];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(16 + index * 20, 76, 16, 16)] fill];
        }
    } else if ([name isEqual:@"repeat"]) {
        Stroke(@[P(28, 95), P(95, 95), P(80, 110)], ink);
        Stroke(@[P(95, 65), P(28, 65), P(43, 50)], accent);
    } else if ([name isEqual:@"check"]) {
        Stroke(@[P(35, 80), P(55, 58), P(96, 105)], ink);
    } else if ([name isEqual:@"cross"]) {
        Stroke(@[P(38, 55), P(90, 107)], accent);
        Stroke(@[P(38, 107), P(90, 55)], accent);
    } else if ([name isEqual:@"zigzag"]) {
        Stroke(@[P(22, 105), P(100, 105), P(22, 56), P(100, 56)], ink);
    } else if ([name isEqual:@"dot"]) {
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(54, 72, 20, 20)] fill];
    } else if ([name isEqual:@"line"]) {
        BOOL vertical = [word isEqual:@"longitudinal"];
        Stroke(vertical ? @[P(64, 51), P(64, 112)] : @[P(23, 81), P(105, 81)], ink);
    } else if ([name isEqual:@"stack"]) {
        for (NSInteger index = 0; index < 3; index++) NSRectFill(NSMakeRect(27, 51 + index * 23, 74, 16));
    } else if ([name isEqual:@"postcard"]) {
        Stroke(@[P(22, 111), P(106, 111), P(106, 55), P(22, 55), P(22, 111)], ink);
        Stroke(@[P(65, 107), P(65, 59)], ink);
        Stroke(@[P(29, 68), P(39, 90), P(51, 74), P(59, 83)], ink);
        [accent setFill]; NSRectFill(NSMakeRect(88, 94, 11, 10));
        Stroke(@[P(73, 84), P(99, 84)], ink);
        Stroke(@[P(73, 72), P(99, 72)], ink);
    } else if ([name isEqual:@"layers"]) {
        for (NSInteger index = 0; index < 4; index++) {
            [[NSColor colorWithCalibratedWhite:0.30 + 0.14 * index alpha:1] setFill];
            NSRectFill(NSMakeRect(23, 52 + index * 15, 82, 14));
        }
    } else if ([name isEqual:@"triangle"]) {
        Stroke(@[P(30, 52), P(64, 112), P(98, 52), P(30, 52)], ink);
    } else if ([name isEqual:@"wave"]) {
        NSMutableArray *points = [NSMutableArray array];
        for (NSInteger x = 20; x <= 108; x++) [points addObject:P(x, 81 + 19 * sin((x - 20) * M_PI / 22))];
        Stroke(points, ink);
    } else {
        NSDictionary *symbols = @{@"equal": @"=", @"two": @"2", @"asterisk": @"*", @"percent": @"%", @"question": @"?", @"stop": @"||"};
        NSString *symbol = symbols[name];
        if (!symbol) [NSException raise:@"UnknownDiagram" format:@"%@", name];
        DrawText(symbol, NSMakeRect(20, 46, 88, 74), 52, ink);
    }
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 3) return 2;
        NSArray *jobs = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:nil];
        if (![jobs isKindOfClass:NSArray.class]) return 2;
        NSString *iconsRoot = @(argv[2]);
        for (NSDictionary *job in jobs) {
            @autoreleasepool {
                if ([NSFileManager.defaultManager fileExistsAtPath:job[@"output"]]) return 3;
                NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:128 pixelsHigh:128
                         bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
                NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
                if (!context) return 6;
                [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext setCurrentContext:context];
                [NSColor.whiteColor setFill]; NSRectFill(NSMakeRect(0, 0, 128, 128));
                NSColor *textColor = [NSColor colorWithWhite:0.16 alpha:1];
                NSString *kind = job[@"kind"];
                if ([kind isEqual:@"meaning_card"]) {
                    DrawText(job[@"card_title"] ?: @"\u91ca\u4e49\u5361", NSMakeRect(10, 103, 108, 15), 10, [NSColor colorWithWhite:0.48 alpha:1]);
                    DrawText(job[@"caption"], NSMakeRect(12, 10, 104, 85), 15, textColor);
                } else {
                    if ([kind isEqual:@"diagram"]) DrawDiagram(job[@"diagram"], job[@"word"]);
                    else if ([kind isEqual:@"ai_illustration"]) {
                        NSImage *image = [[NSImage alloc] initWithContentsOfFile:job[@"source_image"]];
                        if (!image) return 4;
                        [image drawInRect:NSMakeRect(22, 44, 84, 84) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
                    }
                    else {
                        NSArray *icons = job[@"icons"];
                        if (icons.count < 1 || icons.count > 2) return 4;
                        for (NSUInteger index = 0; index < icons.count; index++) {
                            NSString *path = [iconsRoot stringByAppendingPathComponent:[icons[index] stringByAppendingPathExtension:@"png"]];
                            NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
                            if (!image) return 4;
                            NSRect rect = icons.count == 1 ? NSMakeRect(28, 44, 72, 72) : NSMakeRect(10 + index * 57, 58, 51, 51);
                            [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
                        }
                    }
                    DrawText(job[@"caption"], NSMakeRect(8, 3, 112, 39), 13, textColor);
                }
                [NSGraphicsContext restoreGraphicsState];
                NSData *data = [bitmap representationUsingType:NSBitmapImageFileTypeJPEG properties:@{NSImageCompressionFactor: @0.55}];
                if (!data || data.length > 8192 || ![data writeToFile:job[@"output"] options:NSDataWritingWithoutOverwriting error:nil]) return 5;
            }
        }
        printf("Rendered %lu small word graphics.\n", (unsigned long)jobs.count);
    }
    return 0;
}
