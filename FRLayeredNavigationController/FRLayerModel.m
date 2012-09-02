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

@interface FRLayerMoveContext ()
- (id)initWithStartIndex:(NSInteger)i;
- (FRLayerMoveContext *)copyWithSnappingIndex:(NSInteger)i;
- (NSInteger)startIndex;
- (NSInteger)snappingIndex;
@end

@implementation FRLayerMoveContext

- (id)initWithStartIndex:(NSInteger)i {
    if ((self = [super init])) {
        self->_startIndex = i;
        self->_snappingIndex = i;
    }
    return self;
}

- (NSInteger)startIndex
{
    return self->_startIndex;
}

- (NSInteger)snappingIndex
{
    return self->_snappingIndex;
}

- (FRLayerMoveContext *)copyWithSnappingIndex:(NSInteger)i
{
    FRLayerMoveContext *ctx = [[FRLayerMoveContext alloc] initWithStartIndex:self->_startIndex];
    ctx->_snappingIndex = i;
    return ctx;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"FRLayerMoveContext { startIndex=%d, snappingIndex=%d }",
            self->_startIndex, self->_snappingIndex];
}
@end

@class FRLayoutOperationSnappingPoint;
@class FRLayoutOperationRightMargin;

@interface FRLayoutOperation : NSObject {
@private
    NSInteger _priority;
}
- (BOOL)isResize;
- (BOOL)isSnappingPoint;
- (BOOL)isRightMargin;
- (FRLayoutOperationSnappingPoint *)asSnappingPoint;
- (FRLayoutOperationRightMargin *)asRightMargin;
- (NSInteger)layerIndex;
- (NSInteger)priority;
- (id)initWithPriority:(NSInteger)prio;
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

@interface FRLayoutOperationRightMargin : FRLayoutOperation {
    @private
    NSInteger _nextIndex;
    CGFloat _explicitSnapPointX;
    FRLayerController *_controller;
}
@property (nonatomic, strong) FRLayerController *controller;
- (NSInteger)nextIndex;
- (CGFloat)explicitSnapPointX;
- (id)initWithPriority:(NSInteger)prio
            controller:(FRLayerController *)controller
             nextIndex:(NSInteger)nextIndex
    explicitSnapPointX:(CGFloat)explicitSnapPointX;
@end

@interface FRLayoutOperationResize : FRLayoutOperation
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

- (BOOL)isResize
{
    return [self.class isSubclassOfClass:FRLayoutOperationResize.class];
}

- (BOOL)isSnappingPoint
{
    return [self.class isSubclassOfClass:FRLayoutOperationSnappingPoint.class];
}

- (BOOL)isRightMargin
{
    return [self.class isSubclassOfClass:FRLayoutOperationRightMargin.class];
}

- (FRLayoutOperationSnappingPoint *)asSnappingPoint
{
    if (self.isSnappingPoint) {
        return (FRLayoutOperationSnappingPoint *)self;
    } else {
        return nil;
    }
}

- (FRLayoutOperationRightMargin *)asRightMargin
{
    if (self.isRightMargin) {
        return (FRLayoutOperationRightMargin *)self;
    } else {
        return nil;
    }
}

- (NSInteger)layerIndex
{
    return -1;
}

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

- (NSInteger)layerIndex
{
    return self->_nextIndex - 1;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"FRLayoutOperationSnappingPoint { priority=%d, "
            @"controller=%@, snapPointX=%f, nextIndex=%d }",
            self.priority, self.controller, self.snapPointX, self.nextIndex];
}
@end

@implementation FRLayoutOperationRightMargin

@synthesize controller = _controller;

- (id)initWithPriority:(NSInteger)prio
            controller:(FRLayerController *)controller
             nextIndex:(NSInteger)nextIndex
    explicitSnapPointX:(CGFloat)explicitSnapPointX
{
    if ((self = [super initWithPriority:prio])) {
        self->_nextIndex = nextIndex;
        self->_explicitSnapPointX = explicitSnapPointX;
        self.controller = controller;
    }
    return self;
}

- (CGFloat)explicitSnapPointX
{
    return self->_explicitSnapPointX;
}

- (NSInteger)nextIndex
{
    return self->_nextIndex;
}

- (NSInteger)layerIndex
{
    return self->_nextIndex - 1;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"FRLayoutOperationRightMargin { priority=%d, "
            @"controller=%@, nextIndex=%d }",
            self.priority, self.controller, self.nextIndex];
}
@end

@implementation FRLayoutOperationResize
- (NSString *)description
{
    return [NSString stringWithFormat:@"FRLayoutOperationResize { priority=%d }", self.priority];
}
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
        [self.viewControllers addObject:ctrl];
        return self->_width;
    } else {
        [self backToMinimumWidth];
        CGFloat rightX = [self widthOfAllLayers];
        item.currentViewPosition = FRPointSetX(item.currentViewPosition, rightX);
        item.initialViewPosition = FRPointSetX(item.initialViewPosition, rightX);
        FRLayerController *oldTop = [self topLayerViewController];
        [self.viewControllers addObject:ctrl];
        [self doLayout];
        // correct initialViewPosition
        FRLayeredNavigationItem *oldTopItem = oldTop.layeredNavigationItem;
        CGFloat maxSnapX = -1;
        for (FRLayerSnappingPoint *sp in oldTopItem.snappingPoints) {
            maxSnapX = MAX(sp.x, maxSnapX);
        }
        if (maxSnapX >= 0) {
            CGFloat absSnapX = oldTopItem.currentViewPosition.x + maxSnapX;
            if (item.initialViewPosition.x > absSnapX) {
                item.initialViewPosition = FRPointSetX(item.initialViewPosition, absSnapX);
            }
        }
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
        CGFloat maxSnapPointX = -1;
        for (FRLayerSnappingPoint *snapPoint in item.snappingPoints) {
            maxSnapPointX = MAX(maxSnapPointX, snapPoint.x);
            FRLayoutOperation *op = [[FRLayoutOperationSnappingPoint alloc] initWithPriority:snapPoint.priority
                                                                                  controller:ctrl
                                                                                  snapPointX:snapPoint.x
                                                                                   nextIndex:nextIndex];
            [arr addObject:op];
        }
        FRLayoutOperation *op = [[FRLayoutOperationRightMargin alloc] initWithPriority:item.rightMarginSnappingPriority
                                                                            controller:ctrl
                                                                             nextIndex:nextIndex
                                                                    explicitSnapPointX:maxSnapPointX];
        [arr addObject:op];
        if (i == self.viewControllers.count - 1) {
            op = [[FRLayoutOperationResize alloc] initWithPriority:item.resizePriority];
            [arr addObject:op];
        }
    }
    NSArray *sorted = [arr sortedArrayUsingComparator:^(FRLayoutOperation *op1, FRLayoutOperation *op2) {
        NSInteger p1 = op1.priority;
        NSInteger p2 = op2.priority;
        if (p1 == p2) {
            // resizing has the highest priority
            if (op1.isResize) {
                p1++;
            }
            if (op2.isResize) {
                p2++;
            }
            if (!op1.isResize && !op2.isResize) {
                // lower layers have higher priorities
                if (op1.layerIndex < op2.layerIndex) {
                    p1++;
                } else if (op2.layerIndex < op1.layerIndex) {
                    p2++;
                } else { // equal layers
                    // snapping points to the right have higher priorities
                    if (op1.isRightMargin) {
                        p1++;
                    }
                    if (op2.isRightMargin) {
                        p2++;
                    }
                    if (!op1.isRightMargin && !op2.isRightMargin) {
                        FRLayoutOperationSnappingPoint *sp1 = [op1 asSnappingPoint];
                        FRLayoutOperationSnappingPoint *sp2 = [op2 asSnappingPoint];
                        if (sp1.snapPointX < sp2.snapPointX) {
                            p2++;
                        } else if (sp2.snapPointX < sp1.snapPointX) {
                            p1++;
                        }
                    }
                }
            }
        }
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

- (void)backToMinimumWidth {
    for (FRLayerController *lc in self.viewControllers) {
        if (lc.maximumWidth) {
            FRLayeredNavigationItem *item = lc.layeredNavigationItem;
            item.currentWidth = (item.width <= 0) ? FRLayeredNavigationControllerStandardMiniumWidth : item.width;
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
                      initialViewPosition:(CGFloat)initialViewPosition
                               controller:(FRLayerController *)ctrl
                                nextIndex:(NSInteger)nextIndex
                           availableSpace:(CGFloat)availableSpace
{
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    CGFloat snapPointAbsX = item.currentViewPosition.x + snapPointX;
    CGFloat absInitialViewPosition = item.currentViewPosition.x + initialViewPosition;
    CGFloat spaceGained = 0;
    NSArray *vcs = self.viewControllers;
    if (nextIndex < vcs.count) {
        FRLayerController *next = [vcs objectAtIndex:nextIndex];
        FRLayeredNavigationItem *nextItem = next.layeredNavigationItem;
        //if (nextItem.initialViewPosition.x < snapPointAbsX) {
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
            // initialViewPosition < 0 if there is no explicit snapping point
            if (nextItem.initialViewPosition.x < absInitialViewPosition) {
                nextItem.initialViewPosition = FRPointSetX(nextItem.initialViewPosition, absInitialViewPosition);
            }
        }
    }
    return spaceGained;
}

- (CGFloat)enlargeByMovingToRightMargin:(FRLayoutOperationRightMargin *)op
                         availableSpace:(CGFloat)availableSpace
{
    return [self enlargeByMovingToSnappingPoint:op.controller.layeredNavigationItem.currentWidth
                            initialViewPosition:op.explicitSnapPointX
                                     controller:op.controller
                                      nextIndex:op.nextIndex
                                 availableSpace:availableSpace];
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
                                            initialViewPosition:snapOp.snapPointX
                                                     controller:snapOp.controller
                                                      nextIndex:snapOp.nextIndex
                                                 availableSpace:spaceStillAvailable];
         } else if ([op.class isSubclassOfClass:FRLayoutOperationRightMargin.class]) {
             FRLayoutOperationRightMargin *rightMargin = (FRLayoutOperationRightMargin *)op;
             spaceGained = [self enlargeByMovingToRightMargin:rightMargin
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
            // move nextItem.initialViewPosition to the left
            nextItem.initialViewPosition = FRPointSetX(nextItem.initialViewPosition, snapPointAbsX);
        }
        CGFloat transX = nextItem.initialViewPosition.x - nextItem.currentViewPosition.x;
        if (transX < 0) {
            spaceLost = -transX;
            // move layers the left
            for (NSInteger i = nextIndex; i < vcs.count; i++) {
                FRLayerController *lc = [vcs objectAtIndex:i];
                FRLayeredNavigationItem *lcItem = lc.layeredNavigationItem;
                lcItem.currentViewPosition = FRPointTransX(lcItem.currentViewPosition, transX);
                if (lc != next) { // already dealt with
                    lcItem.initialViewPosition = FRPointTransX(lcItem.initialViewPosition, transX);
                }
            }
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
}

# pragma mark Layout

- (void)doLayout {
    [self backToMinimumWidth];
    CGFloat curWidth = [self widthOfAllLayers];
    if (curWidth < self->_width) {
        [self enlargeBy:(self->_width - curWidth)];
    } else if (self->_width < curWidth) {
        [self shrinkBy:(curWidth - self->_width)];
    }
    [self fillSpace];
}

#pragma mark Moving

- (void)moveLayer:(NSInteger)index adjustInitialViewPosition:(BOOL)adjustInitPos xTrans:(CGFloat)xTrans
{
    FRLayerController *ctrl = [self.viewControllers objectAtIndex:index];
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    item.currentViewPosition = FRPointTransX(item.currentViewPosition, xTrans);
    if (adjustInitPos) {
        item.initialViewPosition = FRPointTransX(item.initialViewPosition, xTrans);
    }
    if (item.resizeOnMove && ctrl.maximumWidth) {
        CGFloat x = item.currentViewPosition.x;
        CGFloat newWidth = MAX(item.width, MAX(0, self->_width - x));
        item.currentWidth = newWidth;
    }
}
// 0 <= index < self.viewControllers.count
- (FRLayerMoveContext *)move:(FRLayerMoveContext *)ctx rightBy:(CGFloat)xTrans
{
    NSArray *vcs = self.viewControllers;
    CGFloat realXTrans;
    NSInteger index = ctx.startIndex;
    if (index == 0) {
        realXTrans = xTrans / 2;
    } else {
        FRLayerController *below = [vcs objectAtIndex:(index - 1)];
        FRLayeredNavigationItem *itemBelow = below.layeredNavigationItem;
        CGFloat rightBound = itemBelow.currentViewPosition.x + itemBelow.width;
        FRLayerController *ctrl = [vcs objectAtIndex:index];
        CGFloat curX = ctrl.layeredNavigationItem.currentViewPosition.x;
        CGFloat fullSpeedX = MIN(xTrans, MAX(0, rightBound - curX));
        CGFloat halfSpeedX = MAX(0, xTrans - fullSpeedX) / 2;
        realXTrans = fullSpeedX + halfSpeedX;
    }
    for (NSInteger i = index; i < vcs.count; i++) {
        [self moveLayer:i adjustInitialViewPosition:(i > index) xTrans:realXTrans];
    }
    return [ctx copyWithSnappingIndex:index];
}

// 0 <= index < self.viewControllers.count
- (FRLayerMoveContext *)move:(FRLayerMoveContext *)ctx leftBy:(CGFloat)xTrans
{
    CGFloat remXTrans = xTrans;
    NSInteger index = ctx.startIndex;
    NSInteger snappingIndex = index;
    for (NSInteger i = index; i >= 0 && remXTrans > 0; i--) {
        FRLayerController *ctrl = [self.viewControllers objectAtIndex:i];
        FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
        CGFloat transPossible = MAX(0, item.currentViewPosition.x - item.initialViewPosition.x);
        CGFloat transHere = MIN(remXTrans, transPossible);
        remXTrans = remXTrans - transHere;
        if (i == 0 && remXTrans > 0) {
            // do an out-of-bounds transition, half moving speed
            transHere += remXTrans / 2;
        }
        if (transHere > 0) {
            for (NSInteger j = i; j < self.viewControllers.count; j++) {
                [self moveLayer:j adjustInitialViewPosition:(j > i) xTrans:-transHere];
            }
        }
        snappingIndex = i;
    }
    return [ctx copyWithSnappingIndex:snappingIndex];
}

- (FRLayerMoveContext *)move:(FRLayerMoveContext *)ctx by:(CGFloat)xTrans {
    if (xTrans < 0) {
        return [self move:ctx leftBy:-xTrans];
    } else if (xTrans > 0) {
        return [self move:ctx rightBy:xTrans];
    } else {
        return ctx;
    }
}

- (FRLayerMoveContext *)initialMoveContextFor:(CGPoint)p
{
    NSArray *vcs = self.viewControllers;
    for (NSInteger i = vcs.count - 1; i >= 0; i--) {
        FRLayerController *ctrl = [vcs objectAtIndex:i];
        FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
        CGFloat itemX = item.currentViewPosition.x;
        if (p.x >= itemX && p.x <= itemX + item.currentWidth) {
            return [[FRLayerMoveContext alloc] initWithStartIndex:i];
        }
    }
    return nil;

}

- (FRLayerMoveContext *)moveBy:(CGFloat)xTrans touched:(FRLayerController *)ctrl
{
    NSInteger index = [self.viewControllers indexOfObject:ctrl];
    if (index == NSNotFound) {
        return nil;
    } else {
        FRLayerMoveContext *ctx = [[FRLayerMoveContext alloc] initWithStartIndex:index];
        return [self move:ctx by:xTrans];
    }
}

- (FRLayerMoveContext *)continueMove:(FRLayerMoveContext *)ctx by:(CGFloat)xTrans
{
    if (ctx == nil) {
        return nil;
    } else {
        return [self move:ctx by:xTrans];
    }
}

- (void)endMove:(FRLayerMoveContext *)ctx method:(FRSnappingPointsMethod)method {
    if (ctx == nil) {
        return;
    }
    NSInteger index = ctx.snappingIndex;
    NSArray *vcs = self.viewControllers;
    if (index < 0 || index >= vcs.count || ctx == nil) {
        return; // just a safety net
    }
    FRLayerController *ctrl = [vcs objectAtIndex:index];
    FRLayeredNavigationItem *item = ctrl.layeredNavigationItem;
    CGFloat curX = item.currentViewPosition.x;
    CGFloat leftX = item.initialViewPosition.x;
    CGFloat rightX;
    if (index == 0) {
        rightX = 0;
    } else {
        FRLayerController *below = [vcs objectAtIndex:(index - 1)];
        FRLayeredNavigationItem *itemBelow = below.layeredNavigationItem;
        rightX = itemBelow.currentViewPosition.x + itemBelow.width;
    }
    CGFloat targetX;
    switch (method) {
        case FRSnappingPointsMethodCompact:
            targetX = leftX;
            break;
        case FRSnappingPointsMethodExpand:
            targetX = rightX;
            break;
        case FRSnappingPointsMethodNearest:
            if (curX <= leftX) {
                targetX = leftX;
            } else if (curX >= rightX) {
                targetX = rightX;
            } else if ((curX - leftX) < (rightX - curX)) {
                targetX = leftX;
            } else {
                targetX = rightX;
            }
            break;
    }
    CGFloat xTrans = targetX - curX;
    for (NSInteger i = index; i < vcs.count; i++) {
        [self moveLayer:i adjustInitialViewPosition:(i > index) xTrans:xTrans];
    }
}

@end

