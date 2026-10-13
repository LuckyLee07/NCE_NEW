#import "NCEWordLookup.h"

@implementation NCEWordLookup {
    NSDictionary<NSString *, NSArray<NSDictionary *> *> *_index;
}
+ (NSString *)normalized:(NSString *)text {
    NSString *value=[[text stringByReplacingOccurrencesOfString:@"’" withString:@"'"] lowercaseString];
    for(NSString *hyphen in @[@"‐",@"‑"])value=[value stringByReplacingOccurrencesOfString:hyphen withString:@"-"];
    return value;
}
+ (NSArray<NSValue *> *)wordRangesInText:(NSString *)text {
    static NSRegularExpression *expression;static dispatch_once_t once;
    dispatch_once(&once,^{expression=[NSRegularExpression regularExpressionWithPattern:@"[A-Za-z]+(?:['’‐‑-][A-Za-z]+)*" options:0 error:nil];});
    NSMutableArray *ranges=[NSMutableArray new];
    for(NSTextCheckingResult *match in [expression matchesInString:text options:0 range:NSMakeRange(0,text.length)])[ranges addObject:[NSValue valueWithRange:match.range]];
    return ranges;
}
- (instancetype)initWithWords:(NSArray<NSDictionary *> *)words {
    if((self=[super init])){
        NSMutableDictionary *index=[NSMutableDictionary new];
        for(NSDictionary *word in words){
            for(NSString *name in @[word[@"english"] ?: @"",word[@"lookup_name"] ?: @""]){
                NSString *key=[NCEWordLookup normalized:name];if(!key.length)continue;
                if(!index[key])index[key]=[NSMutableArray new];
                if(![index[key] containsObject:word])[index[key] addObject:word];
            }
        }_index=index.copy;
    }return self;
}
- (NSArray<NSString *> *)candidates:(NSString *)surface {
    NSString *word=[NCEWordLookup normalized:surface];
    NSMutableOrderedSet *keys=[NSMutableOrderedSet orderedSetWithObject:word];
    NSDictionary *irregular=@{@"went":@"go",@"gone":@"go",@"came":@"come",@"seen":@"see",@"saw":@"see",@"took":@"take",@"taken":@"take",@"gave":@"give",@"given":@"give",@"wrote":@"write",@"written":@"write",@"ran":@"run",@"bought":@"buy",@"brought":@"bring",@"thought":@"think",@"caught":@"catch",@"taught":@"teach",@"made":@"make",@"found":@"find",@"left":@"leave",@"felt":@"feel",@"said":@"say",@"told":@"tell",@"knew":@"know",@"known":@"know",@"ate":@"eat",@"eaten":@"eat",@"drank":@"drink",@"drunk":@"drink",@"spoke":@"speak",@"spoken":@"speak",@"was":@"be",@"were":@"be",@"been":@"be",@"is":@"be",@"are":@"be",@"am":@"be",@"did":@"do",@"done":@"do",@"had":@"have",@"has":@"have",@"children":@"child",@"men":@"man",@"women":@"woman",@"feet":@"foot",@"teeth":@"tooth",@"mice":@"mouse"};
    if(irregular[word])[keys addObject:irregular[word]];
    // Conservative spelling variants, accepted only when present in the local dictionary.
    if(word.length>3 && [word hasSuffix:@"'s"])[keys addObject:[word substringToIndex:word.length-2]];
    if(word.length>4 && ([word hasSuffix:@"ies"] || [word hasSuffix:@"ied"]))[keys addObject:[[word substringToIndex:word.length-3] stringByAppendingString:@"y"]];
    if(word.length>3 && [word hasSuffix:@"s"] && ![word hasSuffix:@"ss"])[keys addObject:[word substringToIndex:word.length-1]];
    if(word.length>4 && [word hasSuffix:@"es"])[keys addObject:[word substringToIndex:word.length-2]];
    for(NSString *suffix in @[@"ing",@"ed"]){
        if(word.length>suffix.length+2 && [word hasSuffix:suffix]){
            NSString *stem=[word substringToIndex:word.length-suffix.length];
            if([suffix isEqual:@"ed"]){[keys addObject:[stem stringByAppendingString:@"e"]];[keys addObject:stem];}
            else {[keys addObject:stem];[keys addObject:[stem stringByAppendingString:@"e"]];}
            if(stem.length>2 && [stem characterAtIndex:stem.length-1]==[stem characterAtIndex:stem.length-2])[keys addObject:[stem substringToIndex:stem.length-1]];
        }
    }
    return keys.array;
}
- (NSDictionary *)matchWord:(NSString *)word bookID:(NSInteger)book lessonID:(NSInteger)lesson {
    NSArray *keys=[self candidates:word];
    // Exact curriculum spelling wins; prefer its current lesson, then current volume.
    for(NSString *key in keys){
        NSArray *matches=_index[key];
        for(NSDictionary *match in matches)if([match[@"book_id"] integerValue]==book && [match[@"lesson_id"] integerValue]==lesson)return match;
        for(NSDictionary *match in matches)if([match[@"book_id"] integerValue]==book)return match;
        if(matches.count)return matches.firstObject;
    }
    return nil;
}
@end
