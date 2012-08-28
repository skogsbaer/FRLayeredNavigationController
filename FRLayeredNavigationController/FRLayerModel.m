//
//  FRLayerModel.m
//  FRLayeredNavigationController
//
//  Created by Stefan Wehr on 28.08.12.
//
//

#import "FRLayerModel.h"

@implementation FRLayerModel

- (NSArray *)layeredViewControllers {
    return nil;
}

- (FRLayerController *)rootLayerViewController {
    return nil;
}

- (FRLayerController *)topLayerViewController {
    return nil;
}

- (FRLayerControllersOperations *)pushLayerController:(FRLayerController *)ctrl {
    return nil;
}

- (FRLayerControllersOperations *)popLayerController:(FRLayerController **)ctrlPtr {
    return nil;
}

- (FRLayerControllersOperations *)setWidth:(CGFloat)width {
    return nil;
}

- (BOOL)areViewControllersMaximallyCompressed {
    return NO;
}

@end

@interface FRLayerControllerOperation ()
@property (nonatomic, strong) FRLayerController *layerController;
@property (nonatomic, assign) CGFloat xTranslation;
@property (nonatomic, assign) CGFloat widthChange;
@end

@implementation FRLayerControllerOperation

- (id)initWithLayerController:(FRLayerController *)layerController
                 xTranslation:(CGFloat)xTranslation
                  widthChange:(CGFloat)widthChange
{
    if ((self = [super init])) {
        self.layerController = layerController;
        self.xTranslation = xTranslation;
        self.widthChange = widthChange;
    }
    return self;
}

@synthesize layerController = _layerController;
@synthesize xTranslation = _xTranslation;
@synthesize widthChange = _widthChange;

@end

/*
- (BOOL)areViewControllersMaximallyCompressed
{
    for (FRLayerController *lvc in self.layeredViewControllers) {
        if (lvc.layeredNavigationItem.currentViewPosition.x > lvc.layeredNavigationItem.initialViewPosition.x) {
            // use leftmost initial view position
            return NO;
        }
    }
    return YES;
}

- (void)doLayout {
    for (FRLayerController *vc in self.layeredViewControllers) {
        CGRect f = vc.view.frame;
        if (vc.layeredNavigationItem.currentViewPosition.x < vc.layeredNavigationItem.initialViewPosition.x) {
            vc.layeredNavigationItem.currentViewPosition = vc.layeredNavigationItem.initialViewPosition;
        }
        f.origin = vc.layeredNavigationItem.currentViewPosition;

        if (vc.maximumWidth) {
            f.size.width = MAX(vc.layeredNavigationItem.width,
                               CGRectGetWidth(self.view.bounds) - vc.layeredNavigationItem.initialViewPosition.x);
            vc.layeredNavigationItem.width = CGRectGetWidth(f);
        }

        f.size.height = CGRectGetHeight(self.view.bounds);

        vc.view.frame = f;
    }
}

- (void)push {
    const CGFloat overallWidth = CGRectGetWidth(self.view.bounds) > 0 ?
    CGRectGetWidth(self.view.bounds) :
    [self getScreenBoundsForCurrentOrientation].size.width;

    CGFloat width;
    if (navItem.width > 0) {
        width = navItem.width;
    } else {
        width = newVC.maximumWidth ? overallWidth - initX : FRLayeredNavigationControllerStandardWidth;
        navItem.width = width;
    }

    CGRect onscreenFrame = CGRectMake(newVC.layeredNavigationItem.currentViewPosition.x,
                                      newVC.layeredNavigationItem.currentViewPosition.y,
                                      width,
                                      CGRectGetHeight(self.view.bounds));
    CGRect offscreenFrame = CGRectMake(MAX(1024, CGRectGetMinX(onscreenFrame)),
                                       0,
                                       CGRectGetWidth(onscreenFrame),
                                       CGRectGetHeight(onscreenFrame));
    newVC.view.frame = offscreenFrame;

    // later (in animation block):
    CGFloat saved = [self savePlaceWanted:CGRectGetMinX(onscreenFrame)+width-overallWidth];
    newVC.view.frame = CGRectMake(CGRectGetMinX(onscreenFrame) - saved,
                                  CGRectGetMinY(onscreenFrame),
                                  CGRectGetWidth(onscreenFrame),
                                  CGRectGetHeight(onscreenFrame));
    newVC.layeredNavigationItem.currentViewPosition = newVC.view.frame.origin;
}
 */
