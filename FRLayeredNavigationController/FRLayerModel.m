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

#pragma mark Helper classes

@interface FRLayoutOperation : NSObject {
@private
    NSInteger _priority;
}
- (NSInteger)priority;
- (id)initWithPriority:(NSInteger)prio;
@end

@implementation FRLayoutOperation
- (id)initWithPriority:(NSInteger)prio
{
    if ((self = [super init])) {
        self->_priority = prio;
    }
    return self;
}

- (NSInteger)priority
{
    return self->_priority;
}
@end

@interface FRLayoutOperationSnappingPoint : FRLayoutOperation {
    @private
    CGFloat _snapPointX;
    NSInteger _nextIndex;
    FRLayerController *_controller;
}
@property (nonatomic, strong) FRLayerController *controller;
- (CGFloat)snapPointX;
- (NSInteger)nextIndex;
- (id)initWithPriority:(NSInteger)prio
            controller:(FRLayerController *)controller
            snapPointX:(CGFloat)snapPointX
             nextIndex:(NSInteger)nextIndex;
@end

@implementation FRLayoutOperationSnappingPoint

@synthesize controller = _controller;

- (id)initWithPriority:(NSInteger)prio
            controller:(FRLayerController *)controller
            snapPointX:(CGFloat)snapPointX
             nextIndex:(NSInteger)nextIndex
{
    if ((self = [super initWithPriority:prio])) {
        self->_snapPointX = snapPointX;
        self->_nextIndex = nextIndex;
        self.controller = controller;
    }
    return self;
}

- (CGFloat)snapPointX
{
    return self->_snapPointX;
}

- (NSInteger)nextIndex
{
    return self->_nextIndex;
}
@end

@interface FRLayoutOperationRightMargin : FRLayoutOperation {
    @private
    NSInteger _nextIndex;
    FRLayerController *_controller;
}
@property (nonatomic, strong) FRLayerController *controller;
- (NSInteger)nextIndex;
- (id)initWithPriority:(NSInteger)prio
            controller:(FRLayerController *)controller
             nextIndex:(NSInteger)nextIndex;
@end

@implementation FRLayoutOperationRightMargin

@synthesize controller = _controller;

- (id)initWithPriority:(NSInteger)prio
            controller:(FRLayerController *)controller
             nextIndex:(NSInteger)nextIndex
{
    if ((self = [super initWithPriority:prio])) {
        self->_nextIndex = nextIndex;
        self.controller = controller;
    }
    return self;
}

- (NSInteger)nextIndex
{
    return self->_nextIndex;
}
@end

@interface FRLayoutOperationResize : FRLayoutOperation
@end

@implementation FRLayoutOperationResize
@end

#pragma mark Model implementation

@interface FRLayerModel ()
@property (nonatomic, strong) NSMutableArray *viewControllers;
- (void)doLayout;
@end

@implementation FRLayerModel

- (id)init {
    if ((self = [super init])) {
        self.viewControllers = [NSMutableArray array];
    }
    return self;
}

#pragma mark Public API

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

- (CGFloat)pushLayerController:(FRLayerController *)ctrl {
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    CGFloat neededWidth;
    BOOL useMaxWidth = ctrl.maximumWidth;
    if (item.width <= 0) {
        if (useMaxWidth) {
            neededWidth = FRLayeredNavigationControllerStandardMiniumWidth;
        } else {
            neededWidth = FRLayeredNavigationControllerStandardWidth;
        }
    } else {
        neededWidth = item.width;
    }
    item.currentWidth = neededWidth;
    if (self.viewControllers.count == 0) {
        item.currentViewPosition = FRPointSetX(item.currentViewPosition, 0);
        item.initialViewPosition = FRPointSetX(item.initialViewPosition, 0);
        [self.viewControllers  addObject:ctrl];
        return self->_width;
    } else {
        CGFloat rightX = [self widthOfAllLayers];
        item.currentViewPosition = FRPointSetX(item.currentViewPosition, rightX);
        item.initialViewPosition = FRPointSetX(item.initialViewPosition, rightX);
        [self.viewControllers  addObject:ctrl];
        [self doLayout];
        return MAX(self->_width, rightX);
    }
}

- (FRLayerController *)popLayerController {
    NSInteger n = self.viewControllers.count;
    if (n == 0) {
        NSException *ex = [NSException exceptionWithName:NSRangeException
                                                  reason:@"Attempt to pop FRLayerController from empty FRLayerModel"
                                                userInfo:nil];
        [ex raise];
        return nil;
    } else {
        FRLayerController *ctrl = [self.viewControllers objectAtIndex:(n - 1)];
        [self.viewControllers removeLastObject];
        if (n > 1) {
            [self doLayout];
        }
        return ctrl;
    }
}

- (void)setWidth:(CGFloat)newWidth {
    if (FRFloatEquals(self->_width, newWidth)) {
        return;
    } else {
        self->_width = newWidth;
        [self doLayout];
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

#pragma mark Layout utilities

- (void)enumerateSnappingPointsAsc:(BOOL)asc block:(void (^)(FRLayoutOperation *op, BOOL *stop))block
{
    NSMutableArray *arr = [NSMutableArray array];
    for (NSInteger i = 0; i < self.viewControllers.count; i++) {
        FRLayerController *ctrl = [self.viewControllers objectAtIndex:i];
        FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
        NSInteger nextIndex = i + 1;
        for (FRLayerSnappingPoint *snapPoint in item.snappingPoints) {
            FRLayoutOperation *op = [[FRLayoutOperationSnappingPoint alloc] initWithPriority:snapPoint.priority
                                                                                  controller:ctrl
                                                                                  snapPointX:snapPoint.x
                                                                                   nextIndex:nextIndex];
            [arr addObject:op];
        }
        FRLayoutOperation *op = [[FRLayoutOperationRightMargin alloc] initWithPriority:item.rightMarginSnappingPriority
                                                                            controller:ctrl
                                                                             nextIndex:nextIndex];
        [arr addObject:op];
        if (i == self.viewControllers.count - 1) {
            op = [[FRLayoutOperationResize alloc] initWithPriority:item.resizePriority];
            [arr addObject:op];
        }
    }
    NSArray *sorted = [arr sortedArrayUsingComparator:^(FRLayoutOperation *op1, FRLayoutOperation *op2) {
            NSInteger p1 = op1.priority;
            NSInteger p2 = op2.priority;
            if (p1 < p2) {
                return (asc ? NSOrderedAscending : NSOrderedDescending);
            } else if (p1 > p2) {
                return (asc ? NSOrderedDescending : NSOrderedAscending);
            } else {
                return NSOrderedSame;
            }
        }];
    for (FRLayoutOperation *op in sorted) {
        BOOL stop = NO;
        block(op, &stop);
        if (stop) {
            break;
        }
    }
}

- (CGFloat)widthOfAllLayers {
    FRLayerController *top = self.topLayerViewController;
    FRLayeredNavigationItem *topItem = top.layeredNavigationItem;
    CGFloat w = topItem.currentViewPosition.x + topItem.currentWidth;
    return w;
}

- (void)fillSpace {
    CGFloat w = self->_width;
    for (FRLayerController *lc in self.viewControllers) {
        if (lc.maximumWidth) {
            FRLayeredNavigationItem *item = lc.layeredNavigationItem;
            CGFloat add = w - (item.currentViewPosition.x + item.currentWidth);
            if (add > 0) {
                item.currentWidth += add;
            }
        }
    }   
}

#pragma mark Enlarging

// Returns the space made available. The result is never larger than the space parameter.
- (CGFloat)enlargeByResizing:(CGFloat)space
{
    CGFloat before = [self widthOfAllLayers];
    for (FRLayerController *lc in self.viewControllers) {
        if (lc.maximumWidth) {
            FRLayeredNavigationItem *item = lc.layeredNavigationItem;
            item.currentWidth += space;
        }
    }
    return [self widthOfAllLayers] - before;
}

// Returns the space made available. The result is never larger than the availableSpace parameter.
// Returns -1 if no further enlargements possible
- (CGFloat)enlargeByMovingToSnappingPoint:(CGFloat)snapPointX
                               controller:(FRLayerController *)ctrl
                                nextIndex:(NSInteger)nextIndex
                           availableSpace:(CGFloat)availableSpace
                   setInitialViewPosition:(BOOL)setInitialViewPosition
{
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    CGFloat snapPointAbsX = item.currentViewPosition.x + snapPointX;
    CGFloat spaceGained = 0;
    NSArray *vcs = self.viewControllers;
    if (nextIndex < vcs.count) {
        FRLayerController *next = [vcs objectAtIndex:nextIndex];
        FRLayeredNavigationItem *nextItem = next.layeredNavigationItem;
        if (nextItem.initialViewPosition.x < snapPointAbsX) {
            CGFloat transX = snapPointAbsX - nextItem.currentViewPosition.x;
            if (transX > 0) {
                if (transX > availableSpace) {
                    return -1;
                } else {
                    spaceGained = transX;
                    // move layers to the right
                    for (NSInteger i = nextIndex; i < vcs.count; i++) {
                        FRLayerController *lc = [vcs objectAtIndex:i];
                        FRLayeredNavigationItem *lcItem = lc.layeredNavigationItem;
                        lcItem.currentViewPosition = FRPointTransX(lcItem.currentViewPosition, transX);
                        if (lc != next) { // dealt with later
                            lcItem.initialViewPosition = FRPointTransX(lcItem.initialViewPosition, transX);
                        }
                    }
                }
            }
            if (setInitialViewPosition) {
                // move nextItem.initialViewPosition to the right
                nextItem.initialViewPosition = FRPointSetX(nextItem.initialViewPosition, snapPointAbsX);
            }
        }
    }
    return spaceGained;
}

- (CGFloat)enlargeByMovingToRightMarginOf:(FRLayerController *)ctrl
                                nextIndex:(NSInteger)nextIndex
                           availableSpace:(CGFloat)availableSpace
{
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    return [self enlargeByMovingToSnappingPoint:item.currentWidth
                                     controller:ctrl
                                      nextIndex:nextIndex
                                 availableSpace:availableSpace
                         setInitialViewPosition:NO];
}

- (void)enlargeBy:(CGFloat)space {
    __block CGFloat spaceStillAvailable = space;
    // move initialViewPositions
    [self enumerateSnappingPointsAsc:YES block:^(FRLayoutOperation *op,
                                                 BOOL *stop)
     {
         CGFloat spaceGained = -1;
         if ([op.class isSubclassOfClass:FRLayoutOperationSnappingPoint.class]) {
             FRLayoutOperationSnappingPoint *snapOp = (FRLayoutOperationSnappingPoint *)op;
             spaceGained = [self enlargeByMovingToSnappingPoint:snapOp.snapPointX
                                                     controller:snapOp.controller
                                                      nextIndex:snapOp.nextIndex
                                                 availableSpace:spaceStillAvailable
                                         setInitialViewPosition:YES];
         } else if ([op.class isSubclassOfClass:FRLayoutOperationRightMargin.class]) {
             FRLayoutOperationRightMargin *rightMargin = (FRLayoutOperationRightMargin *)op;
             spaceGained = [self enlargeByMovingToRightMarginOf:rightMargin.controller
                                                      nextIndex:rightMargin.nextIndex
                                                 availableSpace:spaceStillAvailable];
         } else {
             spaceGained = [self enlargeByResizing:spaceStillAvailable];
         }
         NSAssert(spaceGained <= spaceStillAvailable, @"spaceGained > spaceStillAvailable");
         if (spaceGained < 0) {
             *stop = YES;
         } else {
             spaceStillAvailable = spaceStillAvailable - spaceGained;
         }
     }];
    [self fillSpace];
}

#pragma mark Shrinking

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

// Returns the space gained by resizing.
- (CGFloat)shrinkByResizing:(CGFloat)space {
    CGFloat before = [self widthOfAllLayers];
    CGFloat f = MIN(space, [self maxShrinkByResizing]);
    if (f > 0) {
        for (FRLayerController *lc in self.viewControllers) {
            if (lc.maximumWidth) {
                lc.layeredNavigationItem.currentWidth = f;
            }
        }
    }
    return before - [self widthOfAllLayers];
}

// Returns the space gained by moving the the given snap point.
- (CGFloat) shrinkByMovingToSnappingPoint:(CGFloat)snapPointX
                               controller:(FRLayerController *)ctrl
                                nextIndex:(NSInteger)nextIndex
                              spaceNeeded:(CGFloat)spaceNeeded
{
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    CGFloat snapPointAbsX = item.currentViewPosition.x + snapPointX;
    CGFloat spaceLost = 0;
    NSArray *vcs = self.viewControllers;
    if (nextIndex < vcs.count) {
        FRLayerController *next = [vcs objectAtIndex:nextIndex];
        FRLayeredNavigationItem *nextItem = next.layeredNavigationItem;
        if (nextItem.initialViewPosition.x > snapPointAbsX) {
            CGFloat transX = snapPointAbsX - nextItem.currentViewPosition.x;
            if (transX < 0) {
                spaceLost = -transX;
                // move layers the left
                for (NSInteger i = nextIndex; i < vcs.count; i++) {
                    FRLayerController *lc = [vcs objectAtIndex:i];
                    FRLayeredNavigationItem *lcItem = lc.layeredNavigationItem;
                    lcItem.currentViewPosition = FRPointTransX(lcItem.currentViewPosition, transX);
                    if (lc != next) { // dealt with later
                        lcItem.initialViewPosition = FRPointTransX(lcItem.initialViewPosition, transX);
                    }
                }
            }
            // move nextItem.initialViewPosition to the right
            nextItem.initialViewPosition = FRPointSetX(nextItem.initialViewPosition, snapPointAbsX);
        }
    }
    return spaceLost;
}

- (void)shrinkBy:(CGFloat)space {
    if (space <= 0) {
        return;
    }
    __block CGFloat spaceNeeded = space;
    [self enumerateSnappingPointsAsc:NO block:^(FRLayoutOperation *op,
                                                 BOOL *stop)
     {
         CGFloat spaceLost = 0;
         if ([op.class isSubclassOfClass:FRLayoutOperationSnappingPoint.class]) {
             FRLayoutOperationSnappingPoint *snapOp = (FRLayoutOperationSnappingPoint *)op;
             spaceLost = [self shrinkByMovingToSnappingPoint:snapOp.snapPointX
                                                  controller:snapOp.controller
                                                   nextIndex:snapOp.nextIndex
                                                 spaceNeeded:spaceNeeded];
         } else if ([op.class isSubclassOfClass:FRLayoutOperationRightMargin.class]) {
             // do nothing
         } else {
             spaceLost = [self shrinkByResizing:spaceNeeded];
         }
         spaceNeeded = spaceNeeded - spaceLost;
         if (spaceNeeded <= 0) {
             *stop = YES;
         }
     }];
    // compensate moving to far to the left by resizing
    if (spaceNeeded < 0) {
        [self enlargeByResizing:-spaceNeeded];
    }
    [self fillSpace];
}

# pragma mark Layout

- (void)doLayout {
    CGFloat curWidth = [self widthOfAllLayers];
    if (curWidth < self->_width) {
        [self enlargeBy:(self->_width - curWidth)];
    } else if (self->_width < curWidth) {
        [self shrinkBy:(curWidth - self->_width)];
    }
}
@end

