//
//  FRLayerModel.h
//  FRLayeredNavigationController
//
//  Created by Stefan Wehr on 28.08.12.
//
//

#import <Foundation/Foundation.h>

#import "FRLayerController.h"

typedef NSArray FRLayerControllersOperations;

typedef enum {
    FRSnappingPointsMethodNearest,
    FRSnappingPointsMethodCompact,
    FRSnappingPointsMethodExpand
} FRSnappingPointsMethod;

@interface FRLayerMoveContext : NSObject {
    @private
    NSInteger _startIndex;
    NSInteger _snappingIndex;
}
@end

@interface FRLayerModel : NSObject {
    @private
    NSMutableArray *_viewControllers;
    CGFloat _width;
}

- (NSArray *)layeredViewControllers;
- (FRLayerController *)rootLayerViewController;
- (FRLayerController *)topLayerViewController;
- (CGFloat)pushLayerController:(FRLayerController *)ctrl;
- (FRLayerController *)popLayerController;
- (void)setWidth:(CGFloat)width;
- (FRLayerMoveContext *)initialMoveContextFor:(CGPoint)ctrl;
- (FRLayerMoveContext *)moveBy:(CGFloat)xTrans touched:(FRLayerController *)ctrl;
- (FRLayerMoveContext *)continueMove:(FRLayerMoveContext *)ctx by:(CGFloat)xTrans;
- (void)endMove:(FRLayerMoveContext *)ctx method:(FRSnappingPointsMethod)method;
- (BOOL)areViewControllersMaximallyCompressed;

@end
