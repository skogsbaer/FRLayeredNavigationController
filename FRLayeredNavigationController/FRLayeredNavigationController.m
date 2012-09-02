/*
 * This file is part of FRLayeredNavigationController.
 *
 * Copyright (c) 2012, Johannes Weiß <weiss@tux4u.de>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name of the author may not be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FRDLog.h"
#import "FRLayeredNavigationController.h"
#import "FRLayerController.h"
#import "FRLayeredNavigationItem.h"
#import "FRLayeredNavigationItem+Protected.h"
#import "UIViewController+FRLayeredNavigationController.h"
#import "FRLayerModel.h"
#import "FRLayeredNavigationControllerConstants.h"

#import <QuartzCore/QuartzCore.h>

@interface FRLayeredNavigationController ()

@property (nonatomic, readwrite, strong) UIPanGestureRecognizer *panGR;
@property (nonatomic, readwrite, weak) UIViewController *outOfBoundsViewController;
@property (nonatomic, readwrite, weak) UIView *firstTouchedView;
@property (nonatomic, weak) UIView *dropNotificationView;
@property (nonatomic, readwrite, strong) FRLayerModel *model;
@property (nonatomic, readwrite, strong) FRLayerMoveContext *currentMoveContext;
@end

@implementation FRLayeredNavigationController

#pragma mark - Initialization/dealloc

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    return [self initWithRootViewController:rootViewController configuration:^(FRLayeredNavigationItem *item) {
        /* nothing */
    }];
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
                   configuration:(void (^)(FRLayeredNavigationItem *item))configuration
{
    self = [super init];
    if (self) {
        FRLayerController *layeredRC = [[FRLayerController alloc] initWithContentViewController:rootViewController
                                                                                   maximumWidth:NO];
        layeredRC.layeredNavigationItem.nextItemDistance = FRLayeredNavigationControllerStandardDistance;
        layeredRC.layeredNavigationItem.width = FRLayeredNavigationControllerStandardWidth;
        layeredRC.layeredNavigationItem.hasChrome = NO;
        layeredRC.layeredNavigationItem.displayShadow = NO;
        configuration(layeredRC.layeredNavigationItem);
        _outOfBoundsViewController = nil;
        _userInteractionEnabled = YES;
        _dropLayersWhenPulledRight = NO;

        self.model = [[FRLayerModel alloc] init];
        [self.model pushLayerController:layeredRC];
        [self addChildViewController:layeredRC];
        [layeredRC didMoveToParentViewController:self];
    }
    return self;
}

- (void)dealloc
{
    [self detachGestureRecognizer];
}


#pragma mark - UIViewController interface

- (void)loadView
{
    self.view = [[UIView alloc] init];

    for (FRLayerController *vc in self.model.layeredViewControllers) {
        vc.view.frame = CGRectMake(vc.layeredNavigationItem.currentViewPosition.x,
                                   vc.layeredNavigationItem.currentViewPosition.y,
                                   vc.layeredNavigationItem.width,
                                   CGRectGetHeight(self.view.bounds));
        vc.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:vc.view];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (self.userInteractionEnabled) {
        [self attachGestureRecognizer];
    }
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    FRDLOG(@"ORIENTATION, new size: %@", NSStringFromCGSize(self.view.bounds.size));
    [super didRotateFromInterfaceOrientation:orientation];
    [self doLayout];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self doLayout];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self doLayout];
}

- (void)viewWillUnload
{
    [self detachGestureRecognizer];
    self.firstTouchedView = nil;
    self.outOfBoundsViewController = nil;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.dropNotificationView = nil;
    NSLog(@"FRLayeredNavigationController (%@): viewDidUnload", self);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - UIGestureRecognizer delegate interface

- (void)handleGesture:(UIPanGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStatePossible: {
            //NSLog(@"UIGestureRecognizerStatePossible");
            break;
        }

        case UIGestureRecognizerStateBegan: {
            //NSLog(@"UIGestureRecognizerStateBegan");
            CGPoint p = [gestureRecognizer locationInView:self.view];
            self.currentMoveContext = [self.model initialMoveContextFor:p];
            break;
        }

        case UIGestureRecognizerStateChanged: {
            //NSLog(@"UIGestureRecognizerStateChanged, vel=%f", [gestureRecognizer velocityInView:firstView].x);

            const UIViewController *startVc = self.model.topLayerViewController;

            CGFloat f = [gestureRecognizer translationInView:self.view].x;
            self.currentMoveContext = [self.model continueMove:self.currentMoveContext by:f];
            [self doRender];

            /*
            [self moveViewControllersStartIndex:startVcIdx
                    xTranslation:[gestureRecognizer translationInView:self.view].x
                          withParentIndex:-1
                       parentLastPosition:CGPointZero
                      descendentOfTouched:NO];
             */
            [gestureRecognizer setTranslation:CGPointZero inView:startVc.view];

            if (self.dropLayersWhenPulledRight) {
                if (self.dropNotificationView == nil) {
                    if ([self layersInDropZone]) {
                        [self showDropNotification];
                    }
                } else {
                    if (![self layersInDropZone]) {
                        [self hideDropNotification];
                    }
                }
            } else {
                [self hideDropNotification];
            }

            break;
        }

        case UIGestureRecognizerStateEnded: {
            //NSLog(@"UIGestureRecognizerStateEnded");

            [self hideDropNotification];

            if (self.dropLayersWhenPulledRight && [self layersInDropZone]) {
                [self popToRootViewControllerAnimated:YES];
            }

            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionLayoutSubviews   animations:^{
                [self moveToSnappingPointsWithGestureRecognizer:gestureRecognizer];
            } completion:^(BOOL finished) {
                // do nothing
            }];

            self.currentMoveContext = nil;

            break;
        }

        default:
            break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isKindOfClass:[UISlider class]]) {
        // prevent recognizing touches on the slider
        return NO;
    }
    return YES;
}

#pragma mark - internal methods

- (void)moveToSnappingPointsWithGestureRecognizer:(UIPanGestureRecognizer *)g
{
    const CGFloat velocity = [g velocityInView:self.view].x;
    FRSnappingPointsMethod method;

    if (abs(velocity) > FRLayeredNavigationControllerSnappingVelocityThreshold) {
        if (velocity > 0) {
            method = FRSnappingPointsMethodExpand;
        } else {
            method = FRSnappingPointsMethodCompact;
        }
    } else {
        method = FRSnappingPointsMethodNearest;
    }
    [self.model endMove:self.currentMoveContext method:method];
    [self doRender];
}

- (void)doLayout
{
    CGFloat width = CGRectGetWidth(self.view.bounds);
    [self.model setWidth:width];
    [self doRender];
}

- (CGRect)getScreenBoundsForCurrentOrientation
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FRLayeredNavigationController getScreenBoundsForOrientation:orientation];
}

+ (CGRect)getScreenBoundsForOrientation:(UIInterfaceOrientation)orientation
{
    UIScreen *screen = [UIScreen mainScreen];
    CGRect fullScreenRect = screen.bounds; //implicitly in Portrait orientation.

    if (UIInterfaceOrientationIsLandscape(orientation))
    {
        CGRect temp;
        temp.size.width = fullScreenRect.size.height;
        temp.size.height = fullScreenRect.size.width;
        fullScreenRect = temp;
    }

    return fullScreenRect;
}

- (void)attachGestureRecognizer
{
    self.panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    self.panGR.maximumNumberOfTouches = 1;
    self.panGR.delegate = self;
    [self.view addGestureRecognizer:self.panGR];
}

- (void)detachGestureRecognizer
{
    [self.panGR removeTarget:self action:NULL];
    self.panGR.delegate = nil;
    self.panGR = nil;
}

- (FRLayerController *)layerControllerOf:(UIViewController *)vc
{
    for (FRLayerController *lvc in self.model.layeredViewControllers) {
        if (lvc.contentViewController == vc) {
            return lvc;
        }
    }
    return nil;
}

- (BOOL)layersInDropZone
{
    NSArray *vcs = self.model.layeredViewControllers;
    if ([vcs count] > 1) {
        const FRLayerController *rootVC = [vcs objectAtIndex:0];
        const FRLayerController *layer1VC = [vcs objectAtIndex:1];
        const FRLayeredNavigationItem *rootNI = rootVC.layeredNavigationItem;
        const FRLayeredNavigationItem *layer1NI = layer1VC.layeredNavigationItem;

        if (layer1NI.currentViewPosition.x - rootNI.currentViewPosition.x - rootNI.width > 300) {
            return YES;
        }
    }

    return NO;
}

- (void)showDropNotification
{
    const FRLayerController *rootVC = self.model.rootLayerViewController;
    const FRLayeredNavigationItem *rootNI = rootVC.layeredNavigationItem;

    UILabel *lv = [[UILabel alloc] init];
    lv.text = @"X";
    lv.backgroundColor = [UIColor clearColor];
    lv.textColor = [UIColor redColor];
    lv.frame = CGRectMake(rootNI.currentViewPosition.x + rootNI.width + 10,
                          (CGRectGetHeight(self.view.bounds)-100)/2,
                          100,
                          100);
    self.dropNotificationView = lv;
    [self.view insertSubview:self.dropNotificationView atIndex:0];
}

- (void)hideDropNotification
{
    if (self.dropNotificationView != nil) {
        [self.dropNotificationView removeFromSuperview];
        self.dropNotificationView = nil;
    }
}

- (void)doRender
{
    CGFloat height = CGRectGetHeight(self.view.bounds);
    for (FRLayerController *vc in self.model.layeredViewControllers) {
        CGRect f = vc.view.frame;
        FRLayeredNavigationItem *item = vc.layeredNavigationItem;
        CGPoint p = item.currentViewPosition;
        f.origin = CGPointMake(p.x, p.y);
        f.size = CGSizeMake(item.currentWidth, height);
        vc.view.frame = f;
    }
}

#pragma mark - Public API

- (void)popViewControllerAnimated:(BOOL)animated
{
    if ([self.model.layeredViewControllers count] == 1) {
        /* don't remove root view controller */
        return;
    }

    UIViewController *vc = [self.model popLayerController];

    CGRect goAwayFrame = CGRectMake(CGRectGetMinX(vc.view.frame),
                                    1024,
                                    CGRectGetWidth(vc.view.frame),
                                    CGRectGetHeight(vc.view.frame));

    void (^completeViewRemoval)(BOOL) = ^(BOOL finished) {
        [vc willMoveToParentViewController:nil];

        [vc.view removeFromSuperview];

        [vc removeFromParentViewController];

        [self doRender];
    };

    if (animated) {
        [UIView animateWithDuration:0.5
                              delay:0
                            options: UIViewAnimationCurveLinear
                         animations:^{
                             vc.view.frame = goAwayFrame;
                         }
                         completion:completeViewRemoval];
    } else {
        completeViewRemoval(YES);
    }
}

- (void)popToViewController:(UIViewController *)vc animated:(BOOL)animated
{
    UIViewController *currentVc;

    while ((currentVc = [self.model.layeredViewControllers lastObject])) {
        if (([currentVc class] == [FRLayerController class] &&
             ((FRLayerController*)currentVc).contentViewController == vc) ||
            ([currentVc class] != [FRLayerController class] &&
             currentVc == vc)) {
                break;
            }

        if ([self.model.layeredViewControllers count] == 1) {
            /* don't remove root view controller */
            return;
        }

        [self popViewControllerAnimated:animated];
    }
}

- (void)popToRootViewControllerAnimated:(BOOL)animated
{
    [self popToViewController:self.model.rootLayerViewController animated:animated];
}

- (void)pushViewController:(UIViewController *)contentViewController
                 inFrontOf:(UIViewController *)anchorViewController
              maximumWidth:(BOOL)maxWidth
                  animated:(BOOL)animated
             configuration:(void (^)(FRLayeredNavigationItem *item))configuration
{
    FRLayerController *newVC =
        [[FRLayerController alloc] initWithContentViewController:contentViewController maximumWidth:maxWidth];
    const FRLayerController *parentLayerController = [self layerControllerOf:anchorViewController];

    if (parentLayerController == nil) {
        /* view controller to push on not found */
        FRWLOG(@"WARNING: View controller to push in front of ('%@') not pushed (yet), pushing on top instead.",
               anchorViewController);
        [self pushViewController:contentViewController
                       inFrontOf:self.model.topLayerViewController.contentViewController
                    maximumWidth:maxWidth
                        animated:animated
                   configuration:configuration];
        return;
    }

    const FRLayeredNavigationItem *navItem = newVC.layeredNavigationItem;
    
    if (contentViewController.parentViewController.parentViewController == self) {
        /* no animation if the new content view controller is already a child of self */
        [self popToViewController:anchorViewController animated:NO];
    } else {
        [self popToViewController:anchorViewController animated:animated];
    }

    navItem.titleView = nil;
    navItem.title = nil;
    navItem.hasChrome = YES;
    navItem.displayShadow = YES;

    configuration(newVC.layeredNavigationItem);

    CGFloat srcX = [self.model pushLayerController:newVC];
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGRect offscreenFrame = CGRectMake(srcX, 0, navItem.currentWidth, height);
    newVC.view.frame = offscreenFrame;
    
    [self addChildViewController:newVC];
    [self.view addSubview:newVC.view];

    void (^doNewFrameMove)() = ^() {
        [self doRender];
    };
    void (^newFrameMoveCompleted)(BOOL) = ^(BOOL finished) {
        [newVC didMoveToParentViewController:self];
    };

    if(animated) {
        [UIView animateWithDuration:0.5
                              delay:0
                            options: UIViewAnimationCurveEaseOut
                         animations:^{
                             doNewFrameMove();
                         }
                         completion:^(BOOL finished) {
                             newFrameMoveCompleted(finished);
                         }];
    } else {
        doNewFrameMove();
        newFrameMoveCompleted(YES);
    }
}

- (void)pushViewController:(UIViewController *)contentViewController
                 inFrontOf:(UIViewController *)anchorViewController
              maximumWidth:(BOOL)maxWidth
                  animated:(BOOL)animated
{
    [self pushViewController:contentViewController
                   inFrontOf:anchorViewController
                maximumWidth:maxWidth
                    animated:animated
               configuration:^(FRLayeredNavigationItem *item) {
               }];
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
    if (self.userInteractionEnabled != userInteractionEnabled) {
        self->_userInteractionEnabled = userInteractionEnabled;

        if (self.userInteractionEnabled) {
            [self attachGestureRecognizer];
        } else {
            [self detachGestureRecognizer];
        }
    }
}

- (NSArray *)viewControllers
{
    NSArray *vcs = self.model.layeredViewControllers;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[vcs count]];
    [vcs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [result addObject:((FRLayerController*)obj).contentViewController];
    }];
    return [result copy];
}

- (UIViewController *)topViewController
{
    const FRLayerController *topLayerController = self.model.topLayerViewController;
    return topLayerController.contentViewController;
}

#pragma mark - properties

@synthesize panGR = _panGR;
@synthesize firstTouchedView = _firstTouchedView;
@synthesize outOfBoundsViewController = _outOfBoundsViewController;
@synthesize userInteractionEnabled = _userInteractionEnabled;
@synthesize dropLayersWhenPulledRight = _dropLayersWhenPulledRight;
@synthesize dropNotificationView = _dropNotificationView;
@synthesize model = _model;
@synthesize currentMoveContext = _currentMoveContext;

@end
