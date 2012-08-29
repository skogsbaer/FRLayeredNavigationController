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

// Responsibilities:
// - Updates initialViewPosition according to snappingPoints with priorities
// - Sets currentViewPosition and currentWidth on push
// - Computes changes w.r.t. currentViewPosition and currentWidth
// - Does *not* return a operation for popping the topmost layer
@interface FRLayerModel : NSObject {
    @private
    NSMutableArray *_viewControllers;
    CGFloat _width;
    CGFloat _screenWidth;
}

- (NSArray *)layeredViewControllers;
- (FRLayerController *)rootLayerViewController;
- (FRLayerController *)topLayerViewController;
- (FRLayerControllersOperations *)pushLayerController:(FRLayerController *)ctrl;
- (FRLayerControllersOperations *)popLayerController:(FRLayerController **)ctrlPtr;
- (FRLayerControllersOperations *)setWidth:(CGFloat)width;
- (BOOL)areViewControllersMaximallyCompressed;

@end

@interface FRLayerControllerOperation : NSObject {
    @private
    FRLayerController *_layerController;
    CGFloat _xTranslation;
    CGFloat _widthChange;
}
- (FRLayerController *)layerController;
- (CGFloat)xTranslation;
- (CGFloat)widthChange;
@end


