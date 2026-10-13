#import <UIKit/UIKit.h>

@interface NCEReaderWordLabel : UILabel <UIGestureRecognizerDelegate>
@property(nonatomic,copy) void (^lookupWord)(NSRange range);
@property(nonatomic,copy) void (^playSentence)(void);
@property(nonatomic,assign) NSRange highlightedWord;
- (void)configureText:(NSString *)text;
@end
