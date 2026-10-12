#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import "../../NCE_ALL/Utility/NCEWordResourceStore.h"

static void Require(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr,"%s\n",message.UTF8String); exit(1); }
}
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        Require(argc==2 || argc==3,@"Usage: academy-word-test RESOURCES [BOOK_ID]");
        NSInteger bookId=argc==3 ? atoi(argv[2]) : 1;
        Require(bookId>=1 && bookId<=4,@"Expected Book 1–4");
        NSString *root=@(argv[1]);
        NSString *filename=bookId==1 ? @"academy-image-map.json" : [NSString stringWithFormat:@"academy-book%ld-image-map.json",(long)bookId];
        NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:filename]];
        NSDictionary *map=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        Require([map[@"book_id"] integerValue]==bookId,@"Missing requested book scoped map");
        NCEWordResourceStore *store=[[NCEWordResourceStore alloc] initWithRootDirectory:root];
        NSMutableSet *keys=[NSMutableSet setWithArray:[map[@"images"] allKeys]];
        [keys addObjectsFromArray:[map[@"hints"] allKeys]];
        Require(keys.count>0,@"Book must contain word visuals");
        for(NSString *word in keys) {
            NSString *path=[store imagePathForWord:word bookId:bookId];
            NSString *hint=[store visualHintForWord:word bookId:bookId];
            NSString *caption=[store visualCaptionForWord:word bookId:bookId];
            NSString *presentation=[store visualPresentationForWord:word bookId:bookId];
            Require((!caption && !map[@"captions"][word]) || [caption isEqual:map[@"captions"][word]],@"Caption mapping mismatch");
            Require((!presentation && !map[@"presentations"][word]) || [presentation isEqual:map[@"presentations"][word]],@"Presentation mapping mismatch");
            if(map[@"images"][word]) {
                Require([path isEqual:[root stringByAppendingPathComponent:map[@"images"][word]]], [@"Wrong image: " stringByAppendingString:word]);
                Require(hint==nil,@"Image and hint overlap");
                NSData *imageData=[NSData dataWithContentsOfFile:path];
                Require(imageData.length>0 && imageData.length<=200000,@"PNG outside byte limit");
                CGImageSourceRef src=CGImageSourceCreateWithData((__bridge CFDataRef)imageData,NULL);
                CGImageRef image=src ? CGImageSourceCreateImageAtIndex(src,0,NULL) : NULL;
                Require(image && CGImageGetWidth(image)==320 && CGImageGetHeight(image)==320,@"Invalid PNG dimensions/decode");
                CGImageRelease(image);CFRelease(src);
            } else {
                Require(path==nil && [hint isEqual:map[@"hints"][word]],[@"Wrong native hint: " stringByAppendingString:word]);
            }
            for(NSInteger otherBook=1;otherBook<=4;otherBook++) {
                if(otherBook==bookId)continue;
                NSString *name=otherBook==1 ? @"academy-image-map.json" : [NSString stringWithFormat:@"academy-book%ld-image-map.json",(long)otherBook];
                NSData *otherData=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:name]];
                NSDictionary *otherMap=otherData ? [NSJSONSerialization JSONObjectWithData:otherData options:0 error:nil] : nil;
                NSString *expected=otherMap[@"images"][word] ? [root stringByAppendingPathComponent:otherMap[@"images"][word]] : otherMap[@"hints"][word] ? nil : [store imagePathForWord:word];
                NSString *other=[store imagePathForWord:word bookId:otherBook];
                Require((!expected && !other) || [expected isEqual:other],@"Image mapping crossed book boundaries");
                for(NSString *field in @[@"hints",@"captions",@"presentations"]) {
                    NSString *actual=[field isEqual:@"hints"] ? [store visualHintForWord:word bookId:otherBook] : [field isEqual:@"captions"] ? [store visualCaptionForWord:word bookId:otherBook] : [store visualPresentationForWord:word bookId:otherBook];
                    Require((!actual && !otherMap[field][word]) || [actual isEqual:otherMap[field][word]],@"Visual metadata crossed book boundaries");
                }
            }
        }
        Require(![[store imagePathForWord:@"bank" bookId:1] isEqual:[store imagePathForWord:@"bank" bookId:2]],@"River bank and financial bank must remain separate");
        Require(![[store imagePathForWord:@"pool" bookId:1] isEqual:[store imagePathForWord:@"pool" bookId:2]],@"Betting pool and water pool must remain separate");
        for(NSString *key in @[@"../escape",@"a/b",@"a\\b",@"a\nb",@""]) {
            for(NSInteger book=1;book<=4;book++) {
                Require([store imagePathForWord:key bookId:book]==nil,@"Unsafe image key accepted");
                Require([store visualHintForWord:key bookId:book]==nil,@"Unsafe hint key accepted");
            }
        }
        Require([[store visualHintForWord:@"is" bookId:1] containsString:@"___"],@"Grammar hint must hide the target");
        Require([[store visualPresentationForWord:@"May" bookId:1] isEqual:@"diagram"],@"May should use a calendar diagram");
        Require([[store visualCaptionForWord:@"may" bookId:1] containsString:@"come in"],@"may should use permission context");
        Require([[store visualPresentationForWord:@"may" bookId:1] isEqual:@"scene"],@"may should use a permission scene");
        Require(![[store imagePathForWord:@"May" bookId:1] isEqual:[store imagePathForWord:@"may" bookId:1]],@"Case-distinct words must not share art");
        if(bookId<=2) Require([map[@"hints"] count]==(bookId==1 ? 24:22),@"Only audited grammar/discourse hints should remain");
        if(bookId==2) for(NSString *word in @[@"bank",@"pool",@"key",@"hand",@"spring",@"train"]) {
            Require(![[store imagePathForWord:word bookId:1] isEqual:[store imagePathForWord:word bookId:2]],[@"Different senses reused art: " stringByAppendingString:word]);
        }
        printf("Validated %lu Book %ld word visuals, PNG decoding/budgets, native hints, and isolation across all books.\n",(unsigned long)keys.count,(long)bookId);
    }
    return 0;
}
