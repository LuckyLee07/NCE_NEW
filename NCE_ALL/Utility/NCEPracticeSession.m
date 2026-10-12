#import "NCEPracticeSession.h"

@implementation NCEPracticeSession {
    NSUserDefaults *_defaults;
    NSString *_key;
    NSMutableArray<NSDictionary *> *_records;
    NSString *_sessionID;
}
- (instancetype)initWithItems:(NSArray<NSDictionary *> *)items key:(NSString *)key defaults:(NSUserDefaults *)defaults {
    if((self=[super init])) {
        _defaults=defaults;_key=[@"NCEPracticeDraft." stringByAppendingString:key];
        NSDictionary *saved=[defaults dictionaryForKey:_key];
        _items=items.copy;_records=[NSMutableArray new];_input=@"";_options=@[];_selectedOption=-1;_sessionID=NSUUID.UUID.UUIDString;
        if([saved[@"version"] isEqual:@1] && [saved[@"items"] isKindOfClass:NSArray.class] && [saved[@"answers"] isKindOfClass:NSArray.class]) {
            NSArray *restored=saved[@"items"],*answers=saved[@"answers"];
            BOOL valid=restored.count>0 && answers.count<=restored.count && [saved[@"index"] unsignedIntegerValue]<=restored.count;
            for(id item in restored)valid=valid && [item isKindOfClass:NSDictionary.class] && [item[@"english"] isKindOfClass:NSString.class];
            NSUInteger index=[saved[@"index"] unsignedIntegerValue];valid=valid && answers.count>=index && answers.count<=index+1;
            for(NSUInteger i=0;i<answers.count && valid;i++){
                id answer=answers[i];valid=[answer isKindOfClass:NSDictionary.class] && [answer[@"word"] isEqual:restored[i]] && [answer[@"answer"] isKindOfClass:NSString.class] && [answer[@"correct"] isKindOfClass:NSNumber.class] && [answer[@"skipped"] isKindOfClass:NSNumber.class];
            }
            NSArray *options=[saved[@"options"] isKindOfClass:NSArray.class] ? saved[@"options"] : @[];
            BOOL validOptions=options.count<=4;
            for(id option in options)validOptions=validOptions && [option isKindOfClass:NSDictionary.class] && [option[@"english"] isKindOfClass:NSString.class];
            if(valid){_items=restored;_records=answers.mutableCopy;_index=index;_input=[saved[@"input"] isKindOfClass:NSString.class] ? saved[@"input"] : @"";_options=validOptions ? options : @[];NSInteger selection=[saved[@"selected"] respondsToSelector:@selector(integerValue)] ? [saved[@"selected"] integerValue] : -1;_selectedOption=selection>=0 && selection<_options.count ? selection : -1;_sessionID=[saved[@"session"] isKindOfClass:NSString.class] ? saved[@"session"] : _sessionID;}
        }
    } return self;
}
- (NSArray *)answers { return _records.copy; }
- (BOOL)answered { return _index<_records.count; }
- (BOOL)complete { return _index>=_items.count; }
- (NSUInteger)correctCount { NSUInteger count=0;for(NSDictionary *r in _records)if([r[@"correct"] boolValue])count++;return count; }
- (NSUInteger)skippedCount { NSUInteger count=0;for(NSDictionary *r in _records)if([r[@"skipped"] boolValue])count++;return count; }
- (NSArray *)wrongWords {
    NSMutableArray *words=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(NSDictionary *r in _records)if(![r[@"correct"] boolValue] && ![r[@"skipped"] boolValue]){
        NSDictionary *word=r[@"word"];NSString *key=[NSString stringWithFormat:@"%@:%@",word[@"book_id"],word[@"english"]];
        if(![seen containsObject:key]){[words addObject:word];[seen addObject:key];}
    }return words;
}
- (void)save {
    [_defaults setObject:@{@"version":@1,@"items":_items,@"answers":_records,@"index":@(_index),@"input":_input ?: @"",@"options":_options ?: @[],@"selected":@(_selectedOption),@"session":_sessionID} forKey:_key];
}
- (BOOL)submit:(NSString *)answer correct:(BOOL)correct skipped:(BOOL)skipped {
    if(self.complete || self.answered)return NO;
    [_records addObject:@{@"word":_items[_index],@"answer":answer ?: @"",@"correct":@(correct && !skipped),@"skipped":@(skipped)}];[self save];return YES;
}
- (void)advance {
    if(!self.answered || self.complete)return;
    _index++;_input=@"";_options=@[];_selectedOption=-1;[self save];
    if(self.complete){
        NSMutableArray *history=[[_defaults arrayForKey:@"NCEPracticeHistory"] mutableCopy] ?: [NSMutableArray new];
        [history addObject:@{@"session":_sessionID,@"items":_items,@"answers":_records.copy,@"date":NSDate.date}];
        if(history.count>30)[history removeObjectsInRange:NSMakeRange(0,history.count-30)];
        [_defaults setObject:history forKey:@"NCEPracticeHistory"];
    }
}
- (void)restartWithItems:(NSArray<NSDictionary *> *)items {
    _items=items.copy;_records=[NSMutableArray new];_index=0;_options=@[];_selectedOption=-1;_input=@"";_sessionID=NSUUID.UUID.UUIDString;[self save];
}
@end
