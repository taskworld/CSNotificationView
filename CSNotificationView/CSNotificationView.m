//
//  CSNotificationView.m
//  CSNotificationView
//
//  Created by Christian Schwarz on 01.09.13.
//  Copyright (c) 2013 Christian Schwarz. Check LICENSE.md.
//

#import "CSNotificationView.h"
#import "CSNotificationView_Private.h"

#import "CSLayerStealingBlurView.h"
#import "CSNativeBlurView.h"

@interface CSNotificationView ()

@property (nonatomic, strong) NSLayoutConstraint *topLayoutContraintForTitleLabel;
@property (nonatomic, getter=isAnimating) BOOL animating;

@end

@implementation CSNotificationView

#pragma mark + quick presentation

+ (void)showInViewController:(UIViewController *)viewController
                   tintColor:(UIColor *)tintColor
                       image:(UIImage *)image
                     message:(NSString *)message
                    duration:(NSTimeInterval)duration {
    NSAssert(message, @"'message' must not be nil.");
    
    __block CSNotificationView *note = [[CSNotificationView alloc] initWithParentViewController:viewController];
    note.tintColor = tintColor;
    note.image = image;
    note.messageLabel.text = message;
    
    void (^completion)() = ^{
        [note setVisible:NO animated:YES completion:nil];
    };
    [note setVisible:YES
            animated:YES
          completion:^{
              double delayInSeconds = duration;
              dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
              dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                  completion();
              });
          }];
}

+ (void)showInViewController:(UIViewController *)viewController
                   tintColor:(UIColor *)tintColor
                        font:(UIFont *)font
               textAlignment:(NSTextAlignment)textAlignment
                       image:(UIImage *)image
                     message:(NSString *)message
                    duration:(NSTimeInterval)duration {
    NSAssert(message, @"'message' must not be nil.");
    
    __block CSNotificationView *note = [[CSNotificationView alloc] initWithParentViewController:viewController];
    note.tintColor = tintColor;
    note.image = image;
    note.messageLabel.text = message;
    note.messageLabel.textAlignment = textAlignment;
    note.messageLabel.font = font;
    
    void (^completion)() = ^{
        [note setVisible:NO animated:YES completion:nil];
    };
    [note setVisible:YES
            animated:YES
          completion:^{
              double delayInSeconds = duration;
              dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
              dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                  completion();
              });
          }];
}

+ (void)showInViewController:(UIViewController *)viewController
                       style:(CSNotificationViewStyle)style
                     message:(NSString *)message {
    [CSNotificationView showInViewController:viewController
                                   tintColor:[CSNotificationView blurTintColorForStyle:style]
                                       image:[CSNotificationView imageForStyle:style]
                                     message:message
                                    duration:kCSNotificationViewDefaultShowDuration];
}

#pragma mark + creators

+ (CSNotificationView *)notificationViewWithParentViewController:(UIViewController *)viewController
                                                       tintColor:(UIColor *)tintColor
                                                           image:(UIImage *)image
                                                         message:(NSString *)message {
    NSParameterAssert(viewController);
    
    CSNotificationView *note = [[CSNotificationView alloc] initWithParentViewController:viewController];
    note.tintColor = tintColor;
    note.image = image;
    note.messageLabel.text = message;
    
    return note;
}

+ (CSNotificationView *)notificationViewWithParentViewController:(UIViewController *)viewController
                                                           style:(CSNotificationViewStyle)style
                                                            font:(UIFont *)font {
    NSParameterAssert(viewController);
    
    CSNotificationView *note = [[CSNotificationView alloc] initWithParentViewController:viewController];
    note.style = style;
    note.tintColor = [self blurTintColorForStyle:style];
    note.image = [self imageForStyle:style];
    note.messageLabel.textAlignment = [self textAlignmentForStyle:style];
    note.messageLabel.font = font;
    note.titleLabel.textAlignment = [self textAlignmentForStyle:style];
    note.titleLabel.font = font;
    
    CGRect startFrame, endFrame;
    [note animationFramesForVisible:YES startFrame:&startFrame endFrame:&endFrame];
    
    note.frame = startFrame;
    
    if (note.style == CSNotificationViewStyleUpdate) {
        [note.parentNavigationController.view addSubview:note];
    } else if (note.parentNavigationController) {
        [note.parentNavigationController.view insertSubview:note belowSubview:note.parentNavigationController.navigationBar];
    } else {
        [note.parentViewController.view addSubview:note];
    }
    
    return note;
}

#pragma mark - lifecycle

- (instancetype)initWithParentViewController:(UIViewController *)viewController {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self setClipsToBounds:YES];
        
        //Blur view
        {
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
                //Use native effects
                self.blurView = [[CSNativeBlurView alloc] initWithFrame:CGRectZero];
            } else {
                //Use layer stealing
                self.blurView = [[CSLayerStealingBlurView alloc] initWithFrame:CGRectZero];
            }
            
            self.blurView.userInteractionEnabled = NO;
            self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
            self.blurView.clipsToBounds = NO;
            [self insertSubview:self.blurView atIndex:0];
        }
        
        //Parent view
        {
            self.parentViewController = viewController;
            
            NSAssert(!([self.parentViewController isKindOfClass:[UITableViewController class]] && !self.parentViewController.navigationController), @"Due to a bug in iOS 7.0.1|2|3 UITableViewController, CSNotificationView cannot present in UITableViewController without a parent UINavigationController");
            
            if (self.parentViewController.navigationController) {
                self.parentNavigationController = self.parentViewController.navigationController;
            }
            if ([self.parentViewController isKindOfClass:[UINavigationController class]]) {
                self.parentNavigationController = (UINavigationController *)self.parentViewController;
            }
        }
        
        //Notifications
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(navigationControllerWillShowViewControllerNotification:) name:kCSNotificationViewUINavigationControllerWillShowViewControllerNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(navigationControllerDidShowViewControllerNotification:) name:kCSNotificationViewUINavigationControllerDidShowViewControllerNotification object:nil];
        }
        
        //Key-Value Observing
        {
            [self addObserver:self forKeyPath:kCSNavigationBarBoundsKeyPath options:NSKeyValueObservingOptionNew context:kCSNavigationBarObservationContext];
        }
        
        //Content views
        {
            //messageLabel
            {
                _messageLabel = [[UILabel alloc] init];
                
                _messageLabel.textColor = [UIColor whiteColor];
                _messageLabel.backgroundColor = [UIColor clearColor];
                _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
                
                _messageLabel.numberOfLines = 2;
                _messageLabel.minimumScaleFactor = 0.6;
                _messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
                
                UIFontDescriptor *messageLabelFontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
                _messageLabel.font = [UIFont fontWithDescriptor:messageLabelFontDescriptor size:14.0f];
                _messageLabel.adjustsFontSizeToFitWidth = YES;
                
                [self addSubview:_messageLabel];
            }
            
            //titleLabel
            {
                _titleLabel = [[UILabel alloc] init];
                
                _titleLabel.textColor = [UIColor whiteColor];
                _titleLabel.backgroundColor = [UIColor clearColor];
                _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
                
                _titleLabel.numberOfLines = 2;
                _titleLabel.minimumScaleFactor = 0.6;
                _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
                
                UIFontDescriptor *titleLabelFontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
                _titleLabel.font = [UIFont fontWithDescriptor:titleLabelFontDescriptor size:14.0f];
                _titleLabel.adjustsFontSizeToFitWidth = YES;
                
                [self addSubview:_titleLabel];
            }
            
            //symbolView
            {
                [self updateSymbolView];
            }
        }
        
        //Interaction
        {
            //Tap gesture
            self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapInView:)];
            [self addGestureRecognizer:self.tapRecognizer];
        }
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:kCSNavigationBarBoundsKeyPath context:kCSNavigationBarObservationContext];
}

- (void)navigationControllerWillShowViewControllerNotification:(NSNotification *)note {
    if (self.visible && [self.parentNavigationController isEqual:note.object]) {
        __block typeof(self) weakself = self;
        [UIView animateWithDuration:0.1
                         animations:^{
                             CGRect endFrame;
                             [weakself animationFramesForVisible:weakself.visible startFrame:nil endFrame:&endFrame];
                             [weakself setFrame:endFrame];
                             [weakself updateConstraints];
                         }];
    }
}

- (void)navigationControllerDidShowViewControllerNotification:(NSNotification *)note {
    if (self.visible && [self.parentNavigationController.navigationController isEqual:note.object]) {
        //We're about to be pushed away! This might happen in a UISplitViewController with both master/detailViewControllers being UINavgiationControllers
        //Move to new parent
        
        __block typeof(self) weakself = self;
        [self setVisible:NO
                animated:NO
              completion:^{
                  weakself.parentNavigationController = note.object;
                  [weakself setVisible:YES animated:NO completion:nil];
              }];
    }
}

#pragma mark - Key-Value Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == kCSNavigationBarObservationContext && [keyPath isEqualToString:kCSNavigationBarBoundsKeyPath]) {
        self.frame = self.visible ? [self visibleFrame] : [self hiddenFrame];
        [self setNeedsLayout];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - layout

- (void)updateConstraints {
    [self removeConstraints:self.constraints];
    
    NSDictionary *bindings = @{ @"blurView": self.blurView };
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[blurView]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:bindings]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(-1)-[blurView]-(-1)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:bindings]];
    
    CGFloat symbolViewWidth = self.symbolView.tag != kCSNotificationViewEmptySymbolViewTag ? kCSNotificationViewSymbolViewSidelength : 0.0f;
    CGFloat symbolViewHeight = kCSNotificationViewSymbolViewSidelength;
    
    NSDictionary *metrics =
    @{ @"symbolViewWidth": [NSNumber numberWithFloat:symbolViewWidth],
       @"symbolViewHeight": [NSNumber numberWithFloat:symbolViewHeight] };
    
    [self addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"V:[_symbolView(symbolViewHeight)]"
                          options:0
                          metrics:metrics
                          views:NSDictionaryOfVariableBindings(_symbolView)]];
    
    [self addConstraint:[NSLayoutConstraint
                         constraintWithItem:_symbolView
                         attribute:NSLayoutAttributeLeading
                         relatedBy:NSLayoutRelationEqual
                         toItem:self
                         attribute:NSLayoutAttributeLeading
                         multiplier:1.0f
                         constant:15]];
    
    [self addConstraint:[NSLayoutConstraint
                         constraintWithItem:_symbolView
                         attribute:NSLayoutAttributeTop
                         relatedBy:NSLayoutRelationGreaterThanOrEqual
                         toItem:_titleLabel
                         attribute:NSLayoutAttributeTop
                         multiplier:1.0f
                         constant:6]];
    
    [self addConstraint:[NSLayoutConstraint
                         constraintWithItem:_titleLabel
                         attribute:NSLayoutAttributeBottom
                         relatedBy:NSLayoutRelationEqual
                         toItem:_messageLabel
                         attribute:NSLayoutAttributeTop
                         multiplier:1.0f
                         constant:0]];
    
    [self addConstraint:self.topLayoutContraintForTitleLabel];
    
    if (_image) {
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_titleLabel
                             attribute:NSLayoutAttributeLeft
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeLeft
                             multiplier:1.0f
                             constant:55]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_messageLabel
                             attribute:NSLayoutAttributeLeft
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeLeft
                             multiplier:1.0f
                             constant:55]];
    } else {
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_titleLabel
                             attribute:NSLayoutAttributeCenterX
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeCenterX
                             multiplier:1.0f
                             constant:0]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_messageLabel
                             attribute:NSLayoutAttributeCenterX
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeCenterX
                             multiplier:1.0f
                             constant:0]];
    }
    
    [super updateConstraints];
}

#pragma mark - tint color

- (void)setTintColor:(UIColor *)tintColor {
    _tintColor = tintColor;
    [self.blurView setBlurTintColor:tintColor];
    self.contentColor = [self legibleTextColorForBlurTintColor:tintColor];
}

#pragma mark - interaction

- (void)handleTapInView:(UITapGestureRecognizer *)tapGestureRecognizer {
    if (self.tapHandler && tapGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        self.tapHandler();
    }
}

#pragma mark - properties

- (NSLayoutConstraint *)topLayoutContraintForTitleLabel {
    if (!_topLayoutContraintForTitleLabel) {
        _topLayoutContraintForTitleLabel = [NSLayoutConstraint
                                            constraintWithItem:_titleLabel
                                            attribute:NSLayoutAttributeTop
                                            relatedBy:NSLayoutRelationGreaterThanOrEqual
                                            toItem:self
                                            attribute:NSLayoutAttributeTop
                                            multiplier:1.0f
                                            constant:[self topLayoutContriantMin]];
    }
    return _topLayoutContraintForTitleLabel;
}

#pragma mark - presentation

- (void)showWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image toViewController:(UIViewController *)viewController {
    if (!self.visible) {
        [self showWithTitle:title message:message image:image toViewController:viewController animated:NO];
    }
    else if ([self.messageLabel.text length] && ![self.messageLabel.text isEqualToString:message]) {
        [self showWithTitle:title message:message image:image toViewController:viewController animated:YES];
    }
}

- (void)showWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image toViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (!animated) {
        [self setTitle:title message:message image:image toViewController:viewController];
        self.topLayoutContraintForTitleLabel.constant = [self topLayoutContraintMiddle];
        [self layoutIfNeeded];
        [self setVisible:YES animated:YES completion:nil];
    }
    else if (!self.isAnimating) {
        self.animating = YES;
        
        __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:0.9 delay:1.2 usingSpringWithDamping:0.6 initialSpringVelocity:0.6 options:UIViewAnimationCurveEaseInOut animations:^{
            weakSelf.topLayoutContraintForTitleLabel.constant = [weakSelf topLayoutContraintMax];
            [weakSelf layoutIfNeeded];
            
        } completion:^(BOOL finished) {
            [weakSelf setTitle:title message:message image:image toViewController:viewController];
            weakSelf.topLayoutContraintForTitleLabel.constant = [weakSelf topLayoutContriantMin];
            [weakSelf layoutIfNeeded];
            
            [UIView animateWithDuration:1.2 delay:0.0 usingSpringWithDamping:0.6 initialSpringVelocity:0.6 options:UIViewAnimationCurveEaseInOut animations:^{
                weakSelf.topLayoutContraintForTitleLabel.constant = [weakSelf topLayoutContraintMiddle];
                [weakSelf layoutIfNeeded];
                
            } completion:^(BOOL finished) {
                weakSelf.animating = NO;
            }];
        }];
    }
}

- (void)setTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image toViewController:(UIViewController *)viewController {
    self.titleLabel.text = title;
    self.messageLabel.text = message;
    self.image = image;
    __weak typeof(self) weakSelf = self;
    self.tapHandler = ^{
        if ([weakSelf.parentViewController isKindOfClass:[UINavigationController class]] && viewController) {
            UINavigationController *navigationController = (UINavigationController *)weakSelf.parentViewController;
            [navigationController pushViewController:viewController animated:YES];
        }
        [weakSelf setVisible:NO animated:YES completion:nil];
    };
}

- (void)setVisible:(BOOL)visible animated:(BOOL)animated completion:(void (^)())completion {
    if (_visible != visible) {
        NSTimeInterval animationDuration = animated ? 0.4 : 0.0;
        
        CGRect startFrame, endFrame;
        [self animationFramesForVisible:visible startFrame:&startFrame endFrame:&endFrame];
        
        if (!self.superview) {
            self.frame = startFrame;
            
            if (self.style == CSNotificationViewStyleUpdate) {
                [self.parentNavigationController.view addSubview:self];
            } else if (self.parentNavigationController) {
                [self.parentNavigationController.view insertSubview:self belowSubview:self.parentNavigationController.navigationBar];
            } else {
                [self.parentViewController.view addSubview:self];
            }
        }
        
        __block typeof(self) weakself = self;
        [UIView animateWithDuration:1.0 delay:0.0 usingSpringWithDamping:0.6 initialSpringVelocity:0.6 options:UIViewAnimationCurveEaseInOut animations:^{
            [weakself setFrame:endFrame];
        } completion:^(BOOL finished) {
            if (!visible) {
                [weakself removeFromSuperview];
            }
            if (completion) {
                completion();
            }
        }];
        
        _visible = visible;
    } else if (completion) {
        completion();
    }
}

- (void)animationFramesForVisible:(BOOL)visible startFrame:(CGRect *)startFrame endFrame:(CGRect *)endFrame {
    if (startFrame)
        *startFrame = visible ? [self hiddenFrame] : [self visibleFrame];
    if (endFrame)
        *endFrame = visible ? [self visibleFrame] : [self hiddenFrame];
}

- (void)dismissWithStyle:(CSNotificationViewStyle)style message:(NSString *)message duration:(NSTimeInterval)duration animated:(BOOL)animated {
    NSParameterAssert(message);
    
    __block typeof(self) weakself = self;
    [UIView animateWithDuration:0.1
                     animations:^{
                         
                         weakself.showingActivity = NO;
                         weakself.image = [CSNotificationView imageForStyle:style];
                         weakself.messageLabel.text = message;
                         weakself.tintColor = [CSNotificationView blurTintColorForStyle:style];
                         
                     }
                     completion:^(BOOL finished) {
                         double delayInSeconds = 2.0;
                         dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                         dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                             [weakself setVisible:NO animated:animated completion:nil];
                         });
                     }];
}

#pragma mark - frame calculation

//Workaround as there is a bug: sometimes, when accessing topLayoutGuide, it will render contentSize of UITableViewControllers to be {0, 0}
- (CGFloat)topLayoutGuideLengthCalculation {
    CGFloat top = MIN([UIApplication sharedApplication].statusBarFrame.size.height, [UIApplication sharedApplication].statusBarFrame.size.width);
    
    if (self.parentNavigationController && !self.parentNavigationController.navigationBarHidden) {
        top += CGRectGetHeight(self.parentNavigationController.navigationBar.frame);
    }
    
    return top;
}

- (CGRect)visibleFrame {
    UIViewController *viewController = self.parentNavigationController ?: self.parentViewController;
    
    if (!viewController.isViewLoaded) {
        return CGRectZero;
    }
    
    CGFloat topLayoutGuideLength = [self topLayoutGuideLengthCalculation];
    
    CGSize transformedSize = CGSizeApplyAffineTransform(viewController.view.frame.size, viewController.view.transform);
    CGRect displayFrame = CGRectMake(0, 0, fabs(transformedSize.width), [self heightForNotificationView] + topLayoutGuideLength);
    
    return displayFrame;
}

- (CGRect)hiddenFrame {
    UIViewController *viewController = self.parentNavigationController ?: self.parentViewController;
    
    if (!viewController.isViewLoaded) {
        return CGRectZero;
    }
    
    CGFloat topLayoutGuideLength = [self topLayoutGuideLengthCalculation];
    
    CGSize transformedSize = CGSizeApplyAffineTransform(viewController.view.frame.size, viewController.view.transform);
    CGRect offscreenFrame = CGRectMake(0, -[self heightForNotificationView] - topLayoutGuideLength,
                                       fabs(transformedSize.width),
                                       [self heightForNotificationView] + topLayoutGuideLength);
    
    return offscreenFrame;
}

- (CGSize)intrinsicContentSize {
    CGRect currentRect = self.visible ? [self visibleFrame] : [self hiddenFrame];
    return currentRect.size;
}

#pragma mark - symbol view

- (void)updateSymbolView {
    [self.symbolView removeFromSuperview];
    
    if (self.isShowingActivity) {
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        indicator.color = self.contentColor;
        [indicator startAnimating];
        _symbolView = indicator;
    } else if (self.image) {
        //Generate UIImageView for symbolView
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.opaque = NO;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.contentMode = UIViewContentModeCenter;
        imageView.image = [self imageForSymbolView];
        _symbolView = imageView;
    } else {
        _symbolView = [[UIView alloc] initWithFrame:CGRectZero];
        _symbolView.tag = kCSNotificationViewEmptySymbolViewTag;
    }
    _symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_symbolView];
    [self setNeedsUpdateConstraints];
}

#pragma mark-- image

- (void)setImage:(UIImage *)image {
    if (![_image isEqual:image]) {
        _image = image;
        [self updateSymbolView];
    }
}

#pragma mark-- activity

- (void)setShowingActivity:(BOOL)showingActivity {
    if (_showingActivity != showingActivity) {
        _showingActivity = showingActivity;
        [self updateSymbolView];
    }
}

#pragma mark - content color

- (void)setContentColor:(UIColor *)contentColor {
    if (![_contentColor isEqual:contentColor]) {
        _contentColor = contentColor;
        self.messageLabel.textColor = _contentColor;
        [self updateSymbolView];
    }
}

#pragma mark helpers

- (UIColor *)legibleTextColorForBlurTintColor:(UIColor *)blurTintColor {
    CGFloat r, g, b, a;
    BOOL couldConvert = [blurTintColor getRed:&r green:&g blue:&b alpha:&a];
    
    UIColor *textColor = [UIColor whiteColor];
    
    CGFloat average = (r + g + b) / 3.0; //Not considering alpha here, transperency is added by toolbar
    if (couldConvert && average > 0.65)  //0.65 is mostly gut-feeling
    {
        textColor = [[UIColor alloc] initWithWhite:0.2 alpha:1.0];
    }
    
    return textColor;
}

- (UIImage *)imageFromAlphaChannelOfImage:(UIImage *)image replacementColor:(UIColor *)tintColor {
    if (!image)
        return nil;
    NSParameterAssert([tintColor isKindOfClass:[UIColor class]]);
    
    //Credits: https://gist.github.com/omz/1102091
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [image drawInRect:rect];
    CGContextSetFillColorWithColor(c, [tintColor CGColor]);
    CGContextSetBlendMode(c, kCGBlendModeSourceAtop);
    CGContextFillRect(c, rect);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

+ (UIImage *)imageForStyle:(CSNotificationViewStyle)style {
    UIImage *matchedImage = nil;
    
    // Either main bundle or framework bundle.
    NSBundle *containerBundle = [NSBundle bundleForClass:CSNotificationView.class];
    
    // CSNotificationView.bundle is generated by CocoaPods using `resource_bundle` in Podspec.
    NSBundle *assetsBundle = [NSBundle bundleWithURL:[containerBundle URLForResource:@"CSNotificationView" withExtension:@"bundle"]];
    
    switch (style) {
        case CSNotificationViewStyleSuccess:
            matchedImage = [UIImage imageWithContentsOfFile:[assetsBundle pathForResource:@"checkmark" ofType:@"png"]];
            break;
        case CSNotificationViewStyleError:
            matchedImage = [UIImage imageWithContentsOfFile:[assetsBundle pathForResource:@"exclamationMark" ofType:@"png"]];
            break;
        case CSNotificationViewStyleWarning:
        case CSNotificationViewStyleUpdate:
            matchedImage = nil;
            break;
        default:
            break;
    }
    return matchedImage;
}

+ (UIColor *)blurTintColorForStyle:(CSNotificationViewStyle)style {
    UIColor *blurTintColor;
    switch (style) {
        case CSNotificationViewStyleSuccess:
            blurTintColor = [UIColor colorWithRed:0.21 green:0.72 blue:0.00 alpha:1.0];
            break;
        case CSNotificationViewStyleError:
            blurTintColor = [UIColor redColor];
            break;
        case CSNotificationViewStyleWarning:
        case CSNotificationViewStyleUpdate:
            blurTintColor = [UIColor blackColor];
            break;
        default:
            break;
    }
    return blurTintColor;
}

+ (NSTextAlignment)textAlignmentForStyle:(CSNotificationViewStyle)style {
    return style == CSNotificationViewStyleUpdate ? NSTextAlignmentLeft : NSTextAlignmentCenter;
}

- (CGFloat)heightForNotificationView {
    return self.style == CSNotificationViewStyleUpdate ? 0.0f : 30.0f;
}

- (UIImage *)imageForSymbolView {
    return self.style == CSNotificationViewStyleUpdate ? self.image : [self imageFromAlphaChannelOfImage:self.image replacementColor:self.contentColor];
}

- (CGFloat)topLayoutContriantMin {
    return self.style == CSNotificationViewStyleUpdate ? -18.0f : 45.0f;
}

- (CGFloat)topLayoutContraintMiddle {
    return self.style == CSNotificationViewStyleUpdate ? 22.0f : 69.0f;
}

- (CGFloat)topLayoutContraintMax {
    return self.style == CSNotificationViewStyleUpdate ? 68.0f : 93.0f;
}

@end
