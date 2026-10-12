#import <Foundation/Foundation.h>

@interface NCEPracticeSession : NSObject
@property(nonatomic,readonly) NSArray<NSDictionary *> *items;
@property(nonatomic,readonly) NSArray<NSDictionary *> *answers;
@property(nonatomic,readonly) NSUInteger index;
@property(nonatomic,readonly) BOOL answered;
@property(nonatomic,readonly) BOOL complete;
@property(nonatomic,readonly) NSUInteger correctCount;
@property(nonatomic,readonly) NSUInteger skippedCount;
@property(nonatomic,readonly) NSArray<NSDictionary *> *wrongWords;
@property(nonatomic,copy) NSString *input;
@property(nonatomic) NSInteger selectedOption;
@property(nonatomic,copy) NSArray<NSDictionary *> *options;
- (instancetype)initWithItems:(NSArray<NSDictionary *> *)items key:(NSString *)key defaults:(NSUserDefaults *)defaults;
- (void)save;
- (BOOL)submit:(NSString *)answer correct:(BOOL)correct skipped:(BOOL)skipped;
- (void)advance;
- (void)restartWithItems:(NSArray<NSDictionary *> *)items;
@end
