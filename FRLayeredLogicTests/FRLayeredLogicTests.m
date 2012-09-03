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
        navItem.resizeOnMove = YES;
    }];
    self.layer4 = [self newLayer:@"layer4" maxWidth:YES config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_4;
        navItem.resizePriority = 9;
        navItem.resizeOnMove = YES;
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

#define AssertLayer(__layer, __initPos, __currentPos, __currentWidth) \
    do { \
        STAssertEquals(__layer.layeredNavigationItem.initialViewPosition.x, (CGFloat)__initPos, \
                       @"initialViewPosition of %@ is wrong", __layer.name, nil); \
        STAssertEquals(__layer.layeredNavigationItem.currentViewPosition.x, (CGFloat)__currentPos, \
                       @"currentViewPosition of %@ is wrong", __layer.name, nil); \
        STAssertEquals(__layer.layeredNavigationItem.currentWidth, (CGFloat)__currentWidth, \
                       @"currentWidth of %@ is wrong", __layer.name, nil); \
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
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D, SNAP_B + WIDTH_2 + SNAP_D, WIDTH_4);

    [self.model setWidth:410]; // move layer2 to the right, extend layer4
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_4 + 10);

    [self.model setWidth:420]; // move layer4 to the right but shrink it
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4);

    [self.model setWidth:50];
    [self.model setWidth:420]; // again, different starting point
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4);

    [self.model setWidth:380]; // fit with B and C
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_C, SNAP_B + WIDTH_2 + SNAP_C, WIDTH_4 + 40);

    [self.model setWidth:270]; // fit with A and C
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_A + WIDTH_2 + SNAP_C, SNAP_A + WIDTH_2 + SNAP_C, WIDTH_4 + 10);

    [self.model setWidth:260]; // exactly fit with A and C
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_A + WIDTH_2 + SNAP_C, SNAP_A + WIDTH_2 + SNAP_C, WIDTH_4);

    [self.model setWidth:225];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_A + WIDTH_2 + SNAP_C, SNAP_A + WIDTH_2 + SNAP_C, WIDTH_4);

    [self.model setWidth:215];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_A + WIDTH_2 + SNAP_C, SNAP_A + WIDTH_2 + SNAP_C, WIDTH_4);
}

#define PRIO 10

- (void)testLayerModelChangesEqualPriorities
{
    self.model = [[FRLayerModel alloc] init];
    self.layer1 = [self newLayer:@"layer1" maxWidth:NO config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_1;
        [navItem addSnappingPointX:SNAP_A priority:PRIO];
        [navItem addSnappingPointX:SNAP_B priority:PRIO];
        navItem.rightMarginSnappingPriority = PRIO;
        navItem.resizePriority = PRIO;
    }];
    self.layer2 = [self newLayer:@"layer2" maxWidth:NO config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_2;
        navItem.rightMarginSnappingPriority = PRIO;
        navItem.resizePriority = PRIO;
    }];
    self.layer3 = [self newLayer:@"layer3" maxWidth:YES config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_3;
        [navItem addSnappingPointX:SNAP_C priority:PRIO];
        [navItem addSnappingPointX:SNAP_D priority:PRIO];
        navItem.rightMarginSnappingPriority = PRIO;
        navItem.resizePriority = PRIO;
    }];
    self.layer4 = [self newLayer:@"layer4" maxWidth:YES config:^(FRLayeredNavigationItem *navItem) {
        navItem.width = WIDTH_4;
        navItem.rightMarginSnappingPriority = PRIO;
        navItem.resizePriority = PRIO;
    }];

    [self.model setWidth:220];
    [self.model pushLayerController:self.layer1];
    [self.model pushLayerController:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    [self.model setWidth:210];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);

    [self.model setWidth:200];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);

    [self.model setWidth:420];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    [self.model pushLayerController:self.layer3];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3 + WIDTH_4);

    [self.model pushLayerController:self.layer4];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4);

    [self.model setWidth:440];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4 + 20);

    [self.model setWidth:420];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4);

    [self.model setWidth:400];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_A + WIDTH_2 + SNAP_D, SNAP_A + WIDTH_2 + WIDTH_3, WIDTH_4 + 90 - 20);

    [self.model setWidth:330];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_A + WIDTH_2 + SNAP_D, SNAP_A + WIDTH_2 + WIDTH_3, WIDTH_4);

    [self.model setWidth:320];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, WIDTH_2);
    AssertLayer(self.layer3, SNAP_A + WIDTH_2, SNAP_A + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_A + WIDTH_2 + SNAP_D, SNAP_A + WIDTH_2 + SNAP_D, WIDTH_4 + 10);
}

- (void)testLayerModelChangesExplicitMovements
{
    [self.model setWidth:310];
    [self.model pushLayerController:self.layer1];
    [self.model pushLayerController:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    FRLayeredNavigationItem *item2 = self.layer2.layeredNavigationItem;
    item2.currentViewPosition = FRPointSetX(item2.currentViewPosition, 90);

    [self.model pushLayerController:self.layer3];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, 90, WIDTH_2);
    AssertLayer(self.layer3, 90 + WIDTH_2, 90 + WIDTH_2, 100);
}

- (void)testWhereTopLayerIsShorterThenSecondLayer
{
    self.layer2.layeredNavigationItem.width = 50;
    self.layer3.layeredNavigationItem.width = 50;
    [self.model setWidth:120];
    [self.model pushLayerController:self.layer1];
    [self.model pushLayerController:self.layer2];
    [self.model pushLayerController:self.layer3];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_A, SNAP_A, 50);
    AssertLayer(self.layer3, SNAP_A + 50, SNAP_A + 50, 60);
}

- (void)testMovements
{
    [self.model setWidth:420];
    [self.model pushLayerController:self.layer1];
    [self.model pushLayerController:self.layer2];
    [self.model pushLayerController:self.layer3];
    [self.model pushLayerController:self.layer4];
    // all layers are now full exanded
#define AssertInitialPositions \
    do { \
        AssertLayer(self.layer1, 0, 0, WIDTH_1); \
        AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2); \
        AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3); \
        AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3, WIDTH_4); \
    } while(0)
    AssertInitialPositions;

    FRLayerMoveContext *ctx = [self.model moveBy:10 touched:self.layer2];
    // moving out of bounds halfs the moving speed
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1 + 5, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 + 5, WIDTH_1 + WIDTH_2 + 5, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D + 5, WIDTH_1 + WIDTH_2 + WIDTH_3 + 5, WIDTH_4);

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertInitialPositions;

    ctx = [self.model moveBy:-5 touched:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1 - 5, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 5, WIDTH_1 + WIDTH_2 - 5, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 5, WIDTH_1 + WIDTH_2 + WIDTH_3 - 5, WIDTH_4 + 5);

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest]; // nearest prefers right over left
    AssertInitialPositions;

    ctx = [self.model moveBy:-6 touched:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1 - 6, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 6, WIDTH_1 + WIDTH_2 - 6, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 6, WIDTH_1 + WIDTH_2 + WIDTH_3 - 6, WIDTH_4 + 6);

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D, SNAP_B + WIDTH_2 + WIDTH_3, WIDTH_4 + 10);

    ctx = [self.model moveBy:3 touched:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B + 3, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2 + 3, SNAP_B + WIDTH_2 + 3, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D + 3, SNAP_B + WIDTH_2 + WIDTH_3 + 3, WIDTH_4 + 7);
   
    [self.model endMove:ctx method:FRSnappingPointsMethodExpand];
    AssertInitialPositions;


    ctx = [self.model moveBy:-20 touched:self.layer2];
    AssertLayer(self.layer1, 0, -5, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B - 5, WIDTH_1 - 15, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 15, WIDTH_1 + WIDTH_2 - 15, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 15, WIDTH_1 + WIDTH_2 + WIDTH_3 - 15, WIDTH_4 + 15);

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D, SNAP_B + WIDTH_2 + WIDTH_3, WIDTH_4 + 10);

    ctx = [self.model moveBy:10 touched:self.layer2];
    AssertInitialPositions;

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertInitialPositions;

    ctx = [self.model moveBy:-5 touched:self.layer3];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1 - 5, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 5, WIDTH_1 + WIDTH_2 - 5, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 5, WIDTH_1 + WIDTH_2 + WIDTH_3 - 5, WIDTH_4 + 5);

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertInitialPositions;

    ctx = [self.model moveBy:-20 touched:self.layer3];
    AssertLayer(self.layer1, 0, -5, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B - 5, SNAP_B - 5, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 15, WIDTH_1 + WIDTH_2 - 15, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 15, WIDTH_1 + WIDTH_2 + WIDTH_3 - 15, WIDTH_4 + 15);

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 10, WIDTH_1 + WIDTH_2 - 10, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 10, WIDTH_1 + WIDTH_2 + WIDTH_3 - 10, WIDTH_4 + 10);

    ctx = [self.model moveBy:-20 touched:self.layer3];
    AssertLayer(self.layer1, 0, -10, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B - 10, SNAP_B - 10, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 20, WIDTH_1 + WIDTH_2 - 20, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 20, WIDTH_1 + WIDTH_2 + WIDTH_3 - 20, WIDTH_4 + 20);

    [self.model endMove:ctx method:FRSnappingPointsMethodCompact]; // snapping points method does not matter here
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 10, WIDTH_1 + WIDTH_2 - 10, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 10, WIDTH_1 + WIDTH_2 + WIDTH_3 - 10, WIDTH_4 + 10);

    ctx = [self.model moveBy:-20 touched:self.layer3];
    [self.model endMove:ctx method:FRSnappingPointsMethodExpand]; // snapping points method does not matter here
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 10, WIDTH_1 + WIDTH_2 - 10, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 10, WIDTH_1 + WIDTH_2 + WIDTH_3 - 10, WIDTH_4 + 10);

    ctx = [self.model moveBy:20 touched:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1 + 5, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 + 5, WIDTH_1 + WIDTH_2 + 5, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D + 5, WIDTH_1 + WIDTH_2 + WIDTH_3 + 5, WIDTH_4);

    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertInitialPositions;

    self.layer3.layeredNavigationItem.resizeOnMove = NO;
    self.layer4.layeredNavigationItem.resizeOnMove = NO;
    ctx = [self.model moveBy:-10 touched:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 10, WIDTH_1 + WIDTH_2 - 10, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 10, WIDTH_1 + WIDTH_2 + WIDTH_3 - 10, WIDTH_4);
    
    [self.model endMove:ctx method:FRSnappingPointsMethodExpand];
    AssertInitialPositions;

    self.layer3.layeredNavigationItem.resizeOnMove = YES;
    self.layer4.layeredNavigationItem.resizeOnMove = YES;
    
    ctx = [self.model moveBy:10 touched:self.layer4];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3 + 5, WIDTH_4);
    
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertInitialPositions;
    
    ctx = [self.model moveBy:-10 touched:self.layer4];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + WIDTH_3 - 10, WIDTH_4 + 10);
  
    ctx = [self.model continueMove:ctx by:-10];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_4 + 20);

    ctx = [self.model continueMove:ctx by:-5];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1 - 5, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 5, WIDTH_1 + WIDTH_2 - 5, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 5, WIDTH_1 + WIDTH_2 + SNAP_D - 5, WIDTH_4 + 25);
    
    [self.model endMove:ctx method:FRSnappingPointsMethodCompact];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D, SNAP_B + WIDTH_2 + SNAP_D, WIDTH_4 + 30);

    ctx = [self.model moveBy:10 touched:self.layer2];
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    ctx = [self.model moveBy:15 touched:self.layer4];
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertInitialPositions;
    
    // do the -10, -10, -5 movements in one step
    ctx = [self.model moveBy:-25 touched:self.layer4];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1 - 5, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2 - 5, WIDTH_1 + WIDTH_2 - 5, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D - 5, WIDTH_1 + WIDTH_2 + SNAP_D - 5, WIDTH_4 + 25);
    
    [self.model endMove:ctx method:FRSnappingPointsMethodExpand];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    AssertLayer(self.layer3, WIDTH_1 + WIDTH_2, WIDTH_1 + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_1 + WIDTH_2 + SNAP_D, WIDTH_4 + 20);
    
    ctx = [self.model moveBy:10 touched:self.layer2];
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    ctx = [self.model moveBy:15 touched:self.layer4];
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertInitialPositions;
    
    ctx = [self.model moveBy:-40 touched:self.layer4];
    AssertLayer(self.layer1, 0, -5, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B - 5, SNAP_B - 5, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2 - 5, SNAP_B + WIDTH_2 - 5, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D - 5, SNAP_B + WIDTH_2 + SNAP_D - 5,
                420 - (SNAP_B - 5) - WIDTH_2 - SNAP_D);
    
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, WIDTH_3);
    AssertLayer(self.layer4, SNAP_B + WIDTH_2 + SNAP_D, SNAP_B + WIDTH_2 + SNAP_D, 420 - SNAP_B - WIDTH_2 - SNAP_D);
}

- (void)testMovementBug1
{
    [self.model setWidth:420];
    [self.model pushLayerController:self.layer1];
    [self.model pushLayerController:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    FRLayerMoveContext *ctx = [self.model moveBy:-70 touched:self.layer2];
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
}

- (void)testLeftRightMovement
{
    [self.model setWidth:420];
    [self.model pushLayerController:self.layer1];
    [self.model pushLayerController:self.layer2];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    FRLayerMoveContext *ctx = [self.model moveBy:-20 touched:self.layer2];
    AssertLayer(self.layer1, 0, -5, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B - 5, WIDTH_1 - 15, WIDTH_2);
    ctx = [self.model continueMove:ctx by:20];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    ctx = [self.model moveBy:-11 touched:self.layer2];
    ctx = [self.model continueMove:ctx by:40];
    [self.model endMove:ctx method:FRSnappingPointsMethodCompact];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);

    ctx = [self.model moveBy:-5 touched:self.layer2];
    ctx = [self.model continueMove:ctx by:40];
    [self.model endMove:ctx method:FRSnappingPointsMethodExpand];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    ctx = [self.model moveBy:-20 touched:self.layer2];
    ctx = [self.model continueMove:ctx by:20];
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, WIDTH_1, WIDTH_2);

    ctx = [self.model moveBy:-20 touched:self.layer2];
    ctx = [self.model continueMove:ctx by:2];
    [self.model endMove:ctx method:FRSnappingPointsMethodNearest];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
}

- (void)testResizeBug1
{
    [self.model setWidth:310];
    self.layer3.layeredNavigationItem.resizePriority = 2;
    [self.model pushLayerController:self.layer1];
    [self.model pushLayerController:self.layer2];
    [self.model pushLayerController:self.layer3];
    AssertLayer(self.layer1, 0, 0, WIDTH_1);
    AssertLayer(self.layer2, SNAP_B, SNAP_B, WIDTH_2);
    AssertLayer(self.layer3, SNAP_B + WIDTH_2, SNAP_B + WIDTH_2, 100);
}
@end
