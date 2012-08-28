//
//  FRLayeredLogicTests.m
//  FRLayeredLogicTests
//
//  Created by Stefan Wehr on 28.08.12.
//
//

#import "FRLayeredLogicTests.h"

#import "FRLayerModel.h"
#import "FRLayerController+Protected.h"
#import "FRLayeredNavigationItem.h"
#import "FRLayeredNavigationItem+Protected.h"

#define SNAP_A ((CGFloat)10)
#define SNAP_B ((CGFloat)90)
#define SNAP_C ((CGFloat)20)
#define SNAP_D ((CGFloat)70)

#define WIDTH_1 ((CGFloat)100)
#define WIDTH_2 ((CGFloat)120)
#define WIDTH_3 ((CGFloat)90)
#define WIDTH_4 ((CGFloat)50)

@interface FRLayeredLogicTests ()
@property (nonatomic, strong) FRLayerModel *model;
@property (nonatomic, strong) FRLayerController *layer1;
@property (nonatomic, strong) FRLayerController *layer2;
@property (nonatomic, strong) FRLayerController *layer3;
@property (nonatomic, strong) FRLayerController *layer4;
@end

@implementation FRLayeredLogicTests

- (void)setUp
{
    [super setUp];
    self.model = [[FRLayerModel alloc] init];
    self.layer1 = [self newLayer:NO config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_1;
        [navItem addSnappingPointX:SNAP_A priority:1];
        [navItem addSnappingPointX:SNAP_B priority:3];
    }];
    self.layer2 = [self newLayer:NO config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_2;
    }];
    self.layer3 = [self newLayer:YES config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_3;
        [navItem addSnappingPointX:SNAP_C priority:2];
        [navItem addSnappingPointX:SNAP_D priority:4];
    }];
    self.layer4 = [self newLayer:YES config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_4;
    }];
    /* We have the following model

width:             100               120                min. 90         min. 110
               +--------------+  +----------------+  +--------------+  +--------+
               | layer1       |  | layer2         |  | layer3       |  | layer4 |
               |              |  |                |  |              |  |        |
               +--------------+  +----------------+  +--------------+  +--------+
snapping name:   A          B                            C      D
snapping X:     10         90                           20      70
snapping prio:   1          3                            2      4
     */
}

- (void)tearDown
{
    // Tear-down code here.
    [super tearDown];
}

- (FRLayerController *)newLayer:(BOOL)maxWidth config:(void (^)(FRLayeredNavigationItem *item))config {
    FRLayerController *ctrl = [[FRLayerController alloc] initWithContentViewController:nil maximumWidth:maxWidth];
    config(ctrl.layeredNavigationItem);
    return ctrl;
}

- (void)applyOps:(FRLayerControllersOperations *)ops on:(FRLayerController *)layer {
    for (FRLayerControllerOperation *op in ops) {
        if (op.layerController == layer) {
            CGFloat x = layer.layeredNavigationItem.currentViewPosition.x + op.xTranslation;
            CGFloat y = layer.layeredNavigationItem.currentViewPosition.y;
            layer.layeredNavigationItem.currentViewPosition = CGPointMake(x, y);
            layer.layeredNavigationItem.currentWidth += op.widthChange;
        }
    }
}

#define AssertOp(__layer, __op, __from, __to, __oldWidth, __newWidth) \
    do { \
        STAssertEqualsWithAccuracy((CGFloat)__from, __layer.layeredNavigationItem.currentViewPosition.x, 0.001, nil); \
        STAssertEqualsWithAccuracy((CGFloat)__oldWidth, __layer.layeredNavigationItem.currentWidth, 0.001, nil); \
        [self applyOps:__op on:__layer]; \
        STAssertEqualsWithAccuracy((CGFloat)__to, __layer.layeredNavigationItem.currentViewPosition.x, 0.001, nil); \
        STAssertEqualsWithAccuracy((CGFloat)__newWidth, __layer.layeredNavigationItem.currentWidth, 0.001, nil); \
    } while (0)

#define AssertMoves(__layer, __op, __from, __to) \
    AssertOp(__layer, __op, __from, __to, \
             __layer.layeredNavigationItem.currentWidth, \
             __layer.layeredNavigationItem.currentWidth)

#define AssertNoOp(__layer, __op) \
    AssertMoves(__layer, __op, \
                __layer.layeredNavigationItem.currentViewPosition.x, \
                __layer.layeredNavigationItem.currentViewPosition.x)

#define AssertResize(__layer, __op, __oldWidth, __newWidth) \
    AssertOp(__layer, __op, \
             __layer.layeredNavigationItem.currentViewPosition.x, \
             __layer.layeredNavigationItem.currentViewPosition.x, \
             __oldWidth, __newWidth)

- (void)testLayerModelChanges
{
    FRLayerControllersOperations *ops;

    ops = [self.model setWidth:50];
    STAssertEquals(0U, ops.count, nil);

    ops = [self.model pushLayerController:self.layer1];
    STAssertEquals(1U, ops.count, nil);
    AssertMoves(self.layer1, ops, 50, 0);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:90];
    STAssertEquals(0U, ops.count, nil);

    ops = [self.model pushLayerController:self.layer2];
    STAssertEquals(1U, ops.count, nil);
    AssertNoOp(self.layer1, ops);
    AssertMoves(self.layer2, ops, WIDTH_1, SNAP_A);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:209]; // not fit with snapping point B
    STAssertEquals(0U, ops.count, nil);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:210]; // exact fit with snapping point B
    STAssertEquals(1U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_A, SNAP_B);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model pushLayerController:self.layer3]; // no fit with snapping point B
    STAssertEquals(2U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_B, SNAP_A);
    AssertMoves(self.layer3, ops, SNAP_B + WIDTH_2, SNAP_A + WIDTH_2);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:300]; // exact fit with snapping point B
    STAssertEquals(2U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_A, SNAP_B);
    AssertMoves(self.layer3, ops, SNAP_A + WIDTH_2, SNAP_B + WIDTH_2);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:320]; // even more space
    STAssertEquals(1U, ops.count, nil);
    AssertResize(self.layer3, ops, WIDTH_3, WIDTH_3 + 20);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:220]; // no fit with snapping point B
    STAssertEquals(2U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_B, SNAP_A);
    AssertOp(self.layer3, ops, SNAP_B + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3 + 20, WIDTH_3);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model popLayerController:NULL]; // fit with snapping point B
    STAssertEquals(1U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_A, SNAP_B);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:209]; // not fit with snapping point B
    STAssertEquals(1U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_B, SNAP_A);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    
    ops = [self.model pushLayerController:self.layer3];
    STAssertEquals(1U, ops.count, nil);
    AssertMoves(self.layer3, ops, 209, SNAP_A + WIDTH_2);
    STAssertEquals(WIDTH_3, self.layer3.layeredNavigationItem.currentWidth, nil);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:390]; // fits exactly with snapping points B and D (if layer4 is pushed soon)
    STAssertEquals(2U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_A, SNAP_B);
    AssertOp(self.layer3, ops, SNAP_A + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3, WIDTH_3 + 180);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model pushLayerController:self.layer4]; // fit with B and D
    STAssertEquals(1U, ops.count, nil);
    AssertMoves(self.layer4, ops, 390, SNAP_B + WIDTH_2 + SNAP_D);
    STAssertEquals(WIDTH_4, self.layer4.layeredNavigationItem.currentWidth, nil);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2 + SNAP_D, self.layer4.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:410]; // resize layer3 and layer4
    STAssertEquals(2U, ops.count, nil);
    AssertResize(self.layer3, ops, WIDTH_3, WIDTH_3 + 180 + 20);
    AssertResize(self.layer4, ops, WIDTH_4, WIDTH_4 + 20);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2 + SNAP_D, self.layer4.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:380]; // fit with B and C
    STAssertEquals(2U, ops.count, nil);
    AssertResize(self.layer3, ops, WIDTH_3 + 180 + 20, WIDTH_3 + 180 + 20 - 30);
    AssertOp(self.layer4, ops, SNAP_B + WIDTH_2 + SNAP_D, SNAP_B + WIDTH_2 + SNAP_C,
                WIDTH_4 + 20, WIDTH_4 + 20 - 30 + 50);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_B + WIDTH_2 + SNAP_C, self.layer4.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:270]; // fit with A and C
    STAssertEquals(3U, ops.count, nil);
    AssertMoves(self.layer2, ops, SNAP_B, SNAP_A);
    AssertResize(self.layer3, ops, WIDTH_3 + 180 + 20 - 30, 140);
    AssertResize(self.layer4, ops, WIDTH_4 + 20 - 30 + 50, 120);
    STAssertEquals((CGFloat)0, self.layer1.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A, self.layer2.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A + WIDTH_2, self.layer3.layeredNavigationItem.initialViewPosition.x, nil);
    STAssertEquals(SNAP_A + WIDTH_2 + SNAP_C, self.layer4.layeredNavigationItem.initialViewPosition.x, nil);

    ops = [self.model setWidth:260]; // exactly fit with A and C
    STAssertEquals(2U, ops.count, nil);
    AssertResize(self.layer3, ops, 140, 130);
    AssertResize(self.layer4, ops, 120, 110);

    ops = [self.model setWidth:225];
    STAssertEquals(2U, ops.count, nil);
    AssertResize(self.layer3, ops, 140, 95);
    AssertResize(self.layer4, ops, 120, 110);

    ops = [self.model setWidth:215];
    STAssertEquals(2U, ops.count, nil);
    AssertResize(self.layer3, ops, 140, 90);
    AssertResize(self.layer4, ops, 120, 110);
}


@end
