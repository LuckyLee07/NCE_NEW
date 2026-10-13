#import "NCEReaderWordLabel.h"
#import "NCEWordLookup.h"
#import "NCEAcademyTheme.h"
#import "NCELocalization.h"

@implementation NCEReaderWordLabel
- (UIAccessibilityTraits)accessibilityTraits { return UIAccessibilityTraitStaticText; }
- (BOOL)accessibilityActivate { if(self.playSentence){self.playSentence();return YES;}return [super accessibilityActivate]; }
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        self.userInteractionEnabled=YES;self.numberOfLines=0;self.lineBreakMode=NSLineBreakByWordWrapping;
        self.isAccessibilityElement=YES;self.accessibilityTraits=UIAccessibilityTraitStaticText;
        self.font=NCEFont(19,UIFontWeightMedium);self.textColor=NCEInk();self.adjustsFontForContentSizeCategory=YES;
        _highlightedWord=NSMakeRange(NSNotFound,0);
        UILongPressGestureRecognizer *press=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        press.minimumPressDuration=0.45;press.allowableMovement=8;press.delegate=self;
        [self addGestureRecognizer:press];
        UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapSentence:)];
        [tap requireGestureRecognizerToFail:press];[self addGestureRecognizer:tap];
        self.accessibilityHint=NCELocalizedString(@"点击播放句子，长按单词查看释义");
    }return self;
}
- (void)configureText:(NSString *)text {
    self.text=text;
    NSMutableArray *actions=[NSMutableArray new];
    for(NSValue *value in [NCEWordLookup wordRangesInText:text]){
        NSRange range=value.rangeValue;__weak typeof(self) weakSelf=self;
        UIAccessibilityCustomAction *action=[[UIAccessibilityCustomAction alloc] initWithName:[NSString stringWithFormat:NCELocalizedString(@"查词：%@"),[text substringWithRange:range]] actionHandler:^BOOL(UIAccessibilityCustomAction *action){
            typeof(self) self=weakSelf;if(!self.lookupWord)return NO;self.lookupWord(range);return YES;
        }];[actions addObject:action];
    }self.accessibilityCustomActions=actions;
}
- (void)setHighlightedWord:(NSRange)range {
    if(range.location==NSNotFound || range.location>self.text.length || range.length>self.text.length-range.location)range=NSMakeRange(NSNotFound,0);
    _highlightedWord=range;
    NSMutableAttributedString *text=[[NSMutableAttributedString alloc] initWithString:self.text ?: @"" attributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:self.textColor}];
    if(range.location!=NSNotFound && NSMaxRange(range)<=text.length){
        [text addAttributes:@{NSBackgroundColorAttributeName:NCESky(),NSForegroundColorAttributeName:NCEBlue(),NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)} range:range];
    }self.attributedText=text;
    self.accessibilityValue=range.location==NSNotFound ? nil : [self.text substringWithRange:range];
}
- (NSRange)wordAtPoint:(CGPoint)point {
    NSString *text=self.text ?: @"";if(!text.length)return NSMakeRange(NSNotFound,0);
    NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.alignment=self.textAlignment;style.lineBreakMode=self.lineBreakMode;
    NSTextStorage *storage=[[NSTextStorage alloc] initWithString:text attributes:@{NSFontAttributeName:self.font,NSParagraphStyleAttributeName:style}];
    NSLayoutManager *layout=[NSLayoutManager new];NSTextContainer *container=[[NSTextContainer alloc] initWithSize:self.bounds.size];
    container.lineFragmentPadding=0;container.maximumNumberOfLines=self.numberOfLines;container.lineBreakMode=self.lineBreakMode;
    [storage addLayoutManager:layout];[layout addTextContainer:container];[layout ensureLayoutForTextContainer:container];
    CGRect used=[layout usedRectForTextContainer:container];point.y-=MAX(0,(self.bounds.size.height-used.size.height)/2);
    NSUInteger glyph=[layout glyphIndexForPoint:point inTextContainer:container];if(glyph>=layout.numberOfGlyphs)return NSMakeRange(NSNotFound,0);
    CGRect glyphRect=[layout boundingRectForGlyphRange:NSMakeRange(glyph,1) inTextContainer:container];
    // Do not snap whitespace or the empty area at a line's end to a nearby word.
    if(!CGRectContainsPoint(glyphRect,point))return NSMakeRange(NSNotFound,0);
    NSUInteger character=[layout characterIndexForGlyphAtIndex:glyph];
    for(NSValue *value in [NCEWordLookup wordRangesInText:text])if(NSLocationInRange(character,value.rangeValue))return value.rangeValue;
    return NSMakeRange(NSNotFound,0);
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return [self wordAtPoint:[gestureRecognizer locationInView:self]].location!=NSNotFound;
}
- (void)longPress:(UILongPressGestureRecognizer *)press {
    if(press.state!=UIGestureRecognizerStateBegan)return;
    NSRange range=[self wordAtPoint:[press locationInView:self]];
    if(range.location!=NSNotFound && self.lookupWord)self.lookupWord(range);
}
- (void)tapSentence:(UITapGestureRecognizer *)tap {
    if(tap.state==UIGestureRecognizerStateRecognized && self.playSentence)self.playSentence();
}
@end
