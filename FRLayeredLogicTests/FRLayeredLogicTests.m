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
#import "Utils.h"

#define SNAP_A ((CGFloat)10)
#define SNAP_B ((CGFloat)90)
#define SNAP_C ((CGFloat)20)
#define SNAP_D ((CGFloat)70)

#define WIDTH_1 ((CGFloat)100)
#define WIDTH_2 ((CGFloat)120)
#define WIDTH_3 ((CGFloat)90)
#define WIDTH_4 ((CGFloat)110)

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
    self.layer1 = [self newLayer:@"layer1" maxWidth:NO config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_1;
        [navItem addSnappingPointX:SNAP_A priority:1];
        [navItem addSnappingPointX:SNAP_B priority:3];
        navItem.rightMarginSnappingPriority = 7;
    }];
    self.layer2 = [self newLayer:@"layer2" maxWidth:NO config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_2;
    }];
    self.layer3 = [self newLayer:@"layer3" maxWidth:YES config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_3;
        [navItem addSnappingPointX:SNAP_C priority:2];
        [navItem addSnappingPointX:SNAP_D priority:4];
        navItem.rightMarginSnappingPriority = 8;
        navItem.resizePriority = 6;
    }];
    self.layer4 = [self newLayer:@"layer4" maxWidth:YES config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_4;
        navItem.resizePriority = 9;
    }];
    /* We have the following model

width:             100               120                min. 90         min. 110
resize prios:                                           6               9
               +--------------+  +----------------+  +--------------+  +--------+
               | layer1       |  | layer2         |  | layer3       |  | layer4 |
               |              |  |                |  |              |  |        |
               +--------------+  +----------------+  +--------------+  +--------+
snapping name:   A          B                             C      D
snapping X:     10         90                            20     70
snapping prio:   1          3                            2       4
right snap prio               7                                     8
     */
}

- (void)tearDown
{
    // Tear-down code here.
    [super tearDown];
}

- (FRLayerController *)newLayer:(NSString *)name
                       maxWidth:(BOOL)maxWidth
                         config:(void (^)(FRLayeredNavigationItem *item))config
{
    FRLayerController *ctrl = [[FRLayerController alloc] initWithContentViewController:nil maximumWidth:maxWidth];
    config(ctrl.layeredNavigationItem);
    ctrl.name = name;
    return ctrl;
}

#define AssertOp(__layer, __ops, __from, __to, __oldWidth, __newWidth) \
    do { \
//STAssertEqualsWithAccuracy(__layer.layeredNavigationItem.currentViewPosition.x, (CGFloat)__from, 0.001, \
//                                   @"currentViewPosition.x of %@ not at %f as expected before ops", __layer, __from); \
//        STAssertEqualsWithAccuracy(__layer.layeredNavigationItem.currentWidth, (CGFloat)__oldWidth, 0.001, \
//                                   @"currentWidth of %@ not %f as expected before ops", __layer, __oldWidth); \
//        [self applyOps:__ops on:__layer]; \
        STAssertEqualsWithAccuracy(__layer.layeredNavigationItem.currentViewPosition.x, (CGFloat)__to, 0.001, \
                                   @"currentViewPosition.x of %@ not at %f as expected after ops %@", \
                                   __layer, __to, __ops); \
        STAssertEqualsWithAccuracy(__layer.layeredNavigationItem.currentWidth, (CGFloat)__newWidth, 0.001, \
                                   @"currentWidth of %@ not %f as expected after ops %@", \
                                   __layer, __newWidth, __ops); \
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

#define AssertLayer(__layer, __initPos, __currentPos, __currentWidth) \
    do { \
        STAssertEquals(__layer.layeredNavigationItem.initialViewPosition.x, (CGFloat)__initPos, \
                       @"initialViewPosition is wrong", nil); \
        STAssertEquals(__layer.layeredNavigationItem.currentViewPosition.x, (CGFloat)__currentPos, \
                       @"currentViewPosition is wrong", nil); \
        STAssertEquals(__layer.layeredNavigationItem.currentWidth, (CGFloat)__currentWidth, \
                       @"currentWidth is wrong", nil); \
    } while (0)

- (void)testLayerModelChanges
{
    [self.model setWidth:50];

    CGFloat from = [self.model pushLayerController:self.layer1];
    STAssertEquals(from, (CGFloat)50.0, nil);
    AssertLayer(self.layer1, 0, 0, WIDTH_1);

    [self.model setWidth:90];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);

    from = [self.model pushLayerController:self.layer2];
    STAssertEquals(from, (CGFloat)100.0, nil);
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);

    [self.model setWidth:209]; // no fit with snapping point B
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);

    [self.model setWidth:210]; // exact fit with snapping point B
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);

    [self.model pushLayerController:self.layer3]; // no fit with snapping point B
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);

    [self.model setWidth:300]; // exact fit with snapping point B
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3);

    [self.model setWidth:320]; // even more space
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3 + 20);

    [self.model setWidth:220]; // no fit with snapping point B
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);

    [self.model popLayerController]; // fit with right margin of layer1
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    [self.model setWidth:209]; // not fit with snapping point B
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);

    from = [self.model pushLayerController:self.layer3];
    STAssertEquals(from, (CGFloat)209.0, nil);
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);

    [self.model setWidth:390]; // fits exactly with snapping points B and D (if layer4 is pushed soon)
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, 390 - SNAP_B - WIDTH_2);

    [self.model pushLayerController:self.layer4]; // fit with B and D
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, 390 - SNAP_B - WIDTH_2);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D, SNAP_B + WIDTH_2 + SNAP_D, WIDTH_4);
    
    [self.model setWidth:410]; // move layer2 to the right, extend layer4
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, 410 - WIDTH_1 - WIDTH_2);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_4 + 10);

    [self.model setWidth:420]; // move layer4 to the right but shrink it
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, 420 - WIDTH_1 - WIDTH_2);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4);
    
    [self.model setWidth:50];
    [self.model setWidth:420]; // again, different starting point
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, 420 - WIDTH_1 - WIDTH_2);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4);
    
    // TODO: - make remaining tests running
    //       - check whether resetting initialViewPosition all the time is ok
    //       - graphical demo and test
    
    // EVERYTHING OK UNTIL HERE
    
    
    [self.model setWidth:380]; // fit with B and C
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + SNAP_B, WIDTH_1 + SNAP_B, 380 - WIDTH_1 - SNAP_B);
    AssertLayer(self.layer4,  WIDTH_1 + SNAP_B + SNAP_C, WIDTH_1 + SNAP_B + SNAP_C, WIDTH_4);
    
    /*
    ops = [self.model setWidth:270]; // fit with A and C
    STAssertEquals(ops.count, 3U, nil);
    AssertMoves(self.layer2, ops, SNAP_B, SNAP_A);
    AssertResize(self.layer3, ops, WIDTH_3 + 180 + 20 - 30, 140);
    AssertResize(self.layer4, ops, WIDTH_4 + 20 - 30 + 50, 120);
    STAssertEquals(self.layer1.layeredNavigationItem.initialViewPosition.x, (CGFloat)0, nil);
    STAssertEquals(self.layer2.layeredNavigationItem.initialViewPosition.x, SNAP_A, nil);
    STAssertEquals(self.layer3.layeredNavigationItem.initialViewPosition.x, SNAP_A + WIDTH_2, nil);
    STAssertEquals(self.layer4.layeredNavigationItem.initialViewPosition.x, SNAP_A + WIDTH_2 + SNAP_C, nil);

    ops = [self.model setWidth:260]; // exactly fit with A and C
    STAssertEquals(ops.count, 2U, nil);
    AssertResize(self.layer3, ops, 140, 130);
    AssertResize(self.layer4, ops, 120, 110);

    ops = [self.model setWidth:225];
    STAssertEquals(ops.count, 2U, nil);
    AssertResize(self.layer3, ops, 140, 95);
    AssertResize(self.layer4, ops, 120, 110);

    ops = [self.model setWidth:215];
    STAssertEquals(ops.count, 2U, nil);
    AssertResize(self.layer3, ops, 140, 90);
    AssertResize(self.layer4, ops, 120, 110);
    */
}


@end
