//
//  FRLayerModel.m
//  FRLayeredNavigationController
//
//  Created by Stefan Wehr on 28.08.12.
//
//

#import "FRLayerModel.h"
#import "FRLayeredNavigationItem.h"
#import "FRLayeredNavigationItem+Protected.h"
#import "FRLayeredNavigationControllerConstants.h"
#import "Utils.h"

@interface FRLayerModel ()
@property (nonatomic, strong) NSMutableArray *viewControllers;
- (NSMutableArray *)doLayout;
@end

@interface FRLayerControllerOperation ()
@property (nonatomic, strong) FRLayerController *layerController;
@property (nonatomic, assign) CGFloat xTranslation;
@property (nonatomic, assign) CGFloat widthChange;
- (id)initWithLayerController:(FRLayerController *)layerController
                 xTranslation:(CGFloat)xTranslation
                  widthChange:(CGFloat)widthChange;
@end

@implementation FRLayerModel

- (id)init {
    if ((self = [super init])) {
        self.viewControllers = [NSMutableArray array];
    }
    return self;
}

- (NSArray *)layeredViewControllers {
    return [self.viewControllers copy];
}

- (FRLayerController *)rootLayerViewController {
    if (self.viewControllers.count == 0) {
        return nil;
    } else {
        return [self.viewControllers objectAtIndex:0];
    }
}

- (FRLayerController *)topLayerViewController {
    NSInteger n = self.viewControllers.count;
    if (n == 0) {
        return nil;
    } else {
        return [self.viewControllers objectAtIndex:(n - 1)];
    }
}

- (NSInteger)highestPriorityLowerThan:(NSInteger)n {
    NSInteger maxFound = -1;
    for (FRLayerController *lc in self.viewControllers) {
        for (FRLayerSnappingPoint *snapPoint in lc.layeredNavigationItem.snappingPoints) {
            if (snapPoint.priority < n && snapPoint.priority > maxFound) {
                maxFound = snapPoint.priority;
            }
        }
    }
    return maxFound;
}

#define MAX_INT 100000

- (NSInteger)lowestPriorityHigherThan:(NSInteger)n {
    NSInteger minFound = MAX_INT;
    for (FRLayerController *lc in self.viewControllers) {
        for (FRLayerSnappingPoint *snapPoint in lc.layeredNavigationItem.snappingPoints) {
            if (snapPoint.priority > n && snapPoint.priority < minFound) {
                minFound = snapPoint.priority;
            }
        }
    }
    return minFound;
}

- (void)enumerateSnappingPointsAsc:(BOOL)asc block:(void (^)(FRLayerController *ctrl,
                                                             FRLayerSnappingPoint *snapPoint,
                                                             NSArray *nextVCs,
                                                             BOOL *stop))block
{
    // brain-dead implementation for now;
    NSInteger prio = asc ? -1 : MAX_INT;
    while (asc ? (prio < MAX_INT) : (prio >= 0)) {
        if (asc) {
            prio = [self lowestPriorityHigherThan:prio];
        } else {
            prio = [self highestPriorityLowerThan:prio];
        }
        NSArray *vcs = self.viewControllers;
        for (NSInteger i = asc ? (vcs.count - 1) : 0; asc ? (i >= 0) : (i < vcs.count); asc ? i-- : i++) {
            FRLayerController *ctrl = [vcs objectAtIndex:i];
            for (FRLayerSnappingPoint *snapPoint in ctrl.layeredNavigationItem.snappingPoints) {
                if (snapPoint.priority == prio) {
                    NSArray *nextVcs = [NSArray array];
                    if (i < vcs.count - 1) {
                        NSRange theRange;
                        theRange.location = i + 1;
                        theRange.length = vcs.count - 1 - i;
                        nextVcs = [vcs subarrayWithRange:theRange];
                    }
                    BOOL stop = NO;
                    block(ctrl, snapPoint, nextVcs, &stop);
                    if (stop) {
                        return;
                    }
                }
            }
        }
    }
}

- (CGFloat)widthOfAllLayers {
    FRLayerController *top = self.topLayerViewController;
    FRLayeredNavigationItem *topItem = top.layeredNavigationItem;
    CGFloat w = topItem.currentViewPosition.x + topItem.currentWidth;
    return w;
}

- (FRSegment)makeSpace:(CGFloat)neededWidth
          useAvailable:(BOOL)useAvailable
            operations:(NSMutableArray *)operations
{
    FRLayerController *top = self.topLayerViewController;
    if (top == nil) {
        CGFloat w = useAvailable ? MAX(self->_width, neededWidth) : neededWidth;
        FRSegment seg = FRMakeSegment(0.0, w);
        return seg;
    }
    CGFloat currentWidth = [self widthOfAllLayers];
    CGFloat availableWidth = self->_width - currentWidth;
    if (availableWidth >= neededWidth) {
        CGFloat w = useAvailable ? availableWidth : neededWidth;
        FRSegment seg = FRMakeSegment(currentWidth, w);
        return seg;
    }
    // ok, we really need to make some space
    CGFloat widthStillNeeded = neededWidth - availableWidth;
    __block CGFloat savedSpace = 0.0;
    __block CGFloat newX = currentWidth;
    [self enumerateSnappingPointsAsc:NO block:^(FRLayerController *ctrl,
                                                FRLayerSnappingPoint *snapPoint,
                                                NSArray *nextVCs,
                                                BOOL *stop)
    {
        FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
        CGFloat snapPointAbsX = item.currentViewPosition.x + snapPoint.x;
        if (nextVCs.count > 0) {
            FRLayerController *next = [nextVCs objectAtIndex:0];
            FRLayeredNavigationItem *nextItem = next.layeredNavigationItem;
            // possibly move next to the left
            CGFloat xTrans = snapPointAbsX - nextItem.currentViewPosition.x;
            if (xTrans < 0) {
                // do the move
                for (FRLayerController *vc in nextVCs) {
                    FRLayerControllerOperation *op = [[FRLayerControllerOperation alloc] initWithLayerController:vc
                                                                                                    xTranslation:xTrans
                                                                                                     widthChange:0.0];
                    [operations addObject:op];
                }
                savedSpace += -xTrans;
                newX = newX + xTrans;
            }
        } else {
            // ctrl is the current topmost layer (below the layer to be pushed)
            newX = snapPointAbsX;
        }
        if (savedSpace >= widthStillNeeded) {
            *stop = YES;
        }
    }];
    CGFloat w = useAvailable ? MAX(availableWidth + savedSpace, neededWidth) : neededWidth;
    FRSegment seg = FRMakeSegment(newX, w);
    return seg;
}

- (FRLayerControllersOperations *)pushLayerController:(FRLayerController *)ctrl {
    NSMutableArray *ops = [NSMutableArray array];
    // make space for new layer
    BOOL useMaxWidth = ctrl.maximumWidth;
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    CGFloat newLayerWidth = item.width;
    CGFloat neededWidth;
    if (newLayerWidth <= 0) {
        if (useMaxWidth) {
            neededWidth = FRLayeredNavigationControllerStandardMiniumWidth;
        } else {
            neededWidth = FRLayeredNavigationControllerStandardWidth;
        }
    } else {
        neededWidth = newLayerWidth;
    }
    FRSegment seg = [self makeSpace:neededWidth
                       useAvailable:useMaxWidth
                         operations:ops];

    // slide in new layer
    CGFloat startX = MAX(self->_width, seg.x);
    item.currentWidth = seg.width;
    item.currentViewPosition = FRPointSetX(item.currentViewPosition, startX);
    CGFloat xTrans = seg.x - startX;
    FRLayerControllerOperation *op = [[FRLayerControllerOperation alloc] initWithLayerController:ctrl
                                                                                    xTranslation:xTrans
                                                                                     widthChange:0.0];
    [ops addObject:op];

    // update initialViewPosition
    FRLayerController *top = self.topLayerViewController;
    FRLayeredNavigationItem *topItem = top.layeredNavigationItem;
    if (top != nil && seg.x < topItem.currentViewPosition.x + topItem.currentWidth) {
        item.initialViewPosition = FRPointSetX(item.initialViewPosition, seg.x - xTrans);
    } else {
        // compensate for slide-in
        item.initialViewPosition = FRPointSetX(item.initialViewPosition, -xTrans);
    }
    // update internal datastructures
    [self.viewControllers  addObject:ctrl];

    // return result
    return ops;
}

- (FRLayerControllersOperations *)popLayerController:(FRLayerController **)ctrlPtr {
    NSInteger n = self.viewControllers.count;
    if (n == 0) {
        NSException *ex = [NSException exceptionWithName:NSRangeException
                                                  reason:@"Attempt to pop FRLayerController from empty FRLayerModel"                                                userInfo:nil];
        [ex raise];
        return nil;
    } else {
        FRLayerController *ctrl = [self.viewControllers objectAtIndex:(n - 1)];
        if (ctrlPtr != NULL) {
            *ctrlPtr = ctrl;
        }
        [self.viewControllers removeLastObject];
        return [self doLayout];
    }
}

- (void)enlargeBy:(CGFloat)space operations:(NSMutableArray *)operations {
    __block CGFloat spaceStillAvailable = space;
    // move initialViewPositions
    [self enumerateSnappingPointsAsc:YES block:^(FRLayerController *ctrl,
                                                 FRLayerSnappingPoint *snapPoint,
                                                 NSArray *nextVCs,
                                                 BOOL *stop)
     {
         FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
         CGFloat snapPointAbsX = item.currentViewPosition.x + snapPoint.x;
         if (nextVCs.count > 0) {
             FRLayerController *next = [nextVCs objectAtIndex:0];
             FRLayeredNavigationItem *nextItem = next.layeredNavigationItem;
             if (nextItem.initialViewPosition.x < snapPointAbsX) {
                 CGFloat transX = snapPointAbsX - nextItem.currentViewPosition.x;
                 if (transX > 0) {
                     if (transX > spaceStillAvailable) {
                         *stop = YES;
                     } else {
                         spaceStillAvailable = spaceStillAvailable - transX;
                         // move layers the right
                         for (FRLayerController *lc in nextVCs) {
                             FRLayerControllerOperation *op = [[FRLayerControllerOperation alloc]
                                                               initWithLayerController:lc
                                                                          xTranslation:transX
                                                                           widthChange:0.0];
                             [operations addObject:op];
                         }
                         // adjust initialViewPosition, compensate for transCurX
                         nextItem.initialViewPosition = FRPointSetX(nextItem.initialViewPosition,
                                                                    snapPointAbsX - transX);
                     }
                 } else {
                     // only move nextItem.initialViewPosition to the right
                     nextItem.initialViewPosition = FRPointSetX(nextItem.initialViewPosition, snapPointAbsX);
                 }
             }
         }
     }];
     // enlarge
     if (spaceStillAvailable > 0) {
         for (FRLayerController *lc in self.viewControllers) {
             if (lc.maximumWidth) {
                 FRLayerControllerOperation *op = [[FRLayerControllerOperation alloc]
                                                   initWithLayerController:lc
                                                              xTranslation:0.0
                                                               widthChange:spaceStillAvailable];
                 [operations addObject:op];
             }
         }
     }
}

- (CGFloat)maxShrinkByResizing {
    CGFloat shrink = -1;
    for (FRLayerController *lc in self.viewControllers) {
        if (lc.maximumWidth) {
            FRLayeredNavigationItem *item = lc.layeredNavigationItem;
            CGFloat minWidth = MAX(0, item.width);
            CGFloat delta = item.currentWidth - minWidth;
            if (shrink < 0 || shrink > delta) {
                shrink = delta;
            }
        }
    }
    return MAX(0, shrink);
}

- (void)shrinkBy:(CGFloat)space operations:(NSMutableArray *)operations {
    if (space <= 0) {
        return;
    }
    CGFloat shrinkByResizing = [self maxShrinkByResizing];
    if (shrinkByResizing > 0) {
        for (FRLayerController *lc in self.viewControllers) {
            if (lc.maximumWidth) {
                FRLayerControllerOperation *op = [[FRLayerControllerOperation alloc]
                                                  initWithLayerController:lc
                                                  xTranslation:0.0
                                                  widthChange:-shrinkByResizing];
            [operations addObject:op];
            }
        }
        space = space - shrinkByResizing;
    }
    if (space <= 0) {
        return;
    }

    __block CGFloat spaceStillNeeded = space;
    // move initialViewPositions
    [self enumerateSnappingPointsAsc:NO block:^(FRLayerController *ctrl,
                                                 FRLayerSnappingPoint *snapPoint,
                                                 NSArray *nextVCs,
                                                 BOOL *stop)
     {
         if (spaceStillNeeded <= 0) {
             *stop = YES;
         } else {
             FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
             CGFloat snapPointAbsX = item.currentViewPosition.x + snapPoint.x;
             if (nextVCs.count > 0) {
                 FRLayerController *next = [nextVCs objectAtIndex:0];
                 FRLayeredNavigationItem *nextItem = next.layeredNavigationItem;
                 if (snapPointAbsX < nextItem.initialViewPosition.x) {
                     nextItem.initialViewPosition = FRPointSetX(nextItem.initialViewPosition, snapPointAbsX);
                 }
                 CGFloat transX = nextItem.initialViewPosition.x - nextItem.currentViewPosition.x;
                 if (transX < 0) {
                     spaceStillNeeded = spaceStillNeeded + transX;
                     // move layers the left
                     for (FRLayerController *lc in nextVCs) {
                         FRLayerControllerOperation *op = [[FRLayerControllerOperation alloc]
                                                           initWithLayerController:lc
                                                                      xTranslation:transX
                                                                       widthChange:0.0];
                         [operations addObject:op];
                     }
                     // compensate for transX on initialViewPosition
                     nextItem.initialViewPosition = FRPointTransX(nextItem.initialViewPosition, -transX);
                 }
             }
         }
     }];
}

- (NSMutableArray *)doLayout {
    CGFloat curWidth = [self widthOfAllLayers];
    NSMutableArray *ops = [NSMutableArray array];
    if (curWidth < self->_width) {
        [self enlargeBy:(self->_width - curWidth) operations:ops];
    } else {
        [self shrinkBy:(curWidth - self->_width) operations:ops];
    }
    return ops;
}

- (FRLayerControllersOperations *)setWidth:(CGFloat)newWidth {
    if (FRFloatEquals(self->_width, newWidth)) {
        return [NSArray array];
    } else {
        self->_width = newWidth;
        return [self doLayout];
    }
}

- (BOOL)areViewControllersMaximallyCompressed {
    for (FRLayerController *lvc in self.viewControllers) {
        if (lvc.layeredNavigationItem.currentViewPosition.x > lvc.layeredNavigationItem.initialViewPosition.x) {
            return NO;
        }
    }
    return YES;
}

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

- (NSString *)description {
    return [NSString stringWithFormat:@"FRLayerControllerOperation {"
            @" layerController=%@, xTranslation=%f, widthChange=%f }",
            self.layerController, self.xTranslation, self.widthChange];
}

@synthesize layerController = _layerController;
@synthesize xTranslation = _xTranslation;
@synthesize widthChange = _widthChange;

@end

/*


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
