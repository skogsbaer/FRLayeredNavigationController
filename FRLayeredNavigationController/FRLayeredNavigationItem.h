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

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

@class FRLayerController;

/*
 * Ordering of layout operations if explicit priorities are equal. We consider the case of shrinking here,
 * enlarging is the inverse.
 *
 * - First we try to resize the layers.
 * - Then we consider the snapping, starting at the lowest layer. In each layer, we consider the snapping
 *   points from right to left.
 */
@interface FRLayerSnappingPoint : NSObject {
    @private
    CGFloat _x;
    NSInteger _priority;
}
@property (nonatomic, readonly) CGFloat x;
@property (nonatomic, readonly) NSInteger priority;
@end

/**
 * FRLayeredNavigationItem is used to configure one view controller layer. It is very similar to UINavigationItem .
 *
 */
@interface FRLayeredNavigationItem : NSObject {
    @private
    CGPoint _initialViewPosition;
    CGPoint _currentViewPosition;
    NSString *_title;
    UIView *_titleView;
    CGFloat _width;
    NSInteger _resizePriority;
    NSInteger _rightMarginSnappingPriority;
    CGFloat _nextItemDistance;
    BOOL _hasChrome;
    BOOL _displayShadow;
    BOOL _resizeOnMove;
    NSMutableSet *_internalSnappingPoints;
    FRLayerController __weak * _layerController;
    NSString *_name;
}

/**
 * The view position when the layers are compacted maximally.
 * Managed by internaly by FRLayeredNavigationController.
 */
@property (nonatomic, readonly) CGPoint initialViewPosition;

/**
 * The current view position. Managed by internaly by FRLayeredNavigationController.
 */
@property (nonatomic, readonly) CGPoint currentViewPosition;

/**
 * The navigation item’s title displayed in the center of the navigation bar.
 */
@property (nonatomic, readwrite, strong) NSString *title;

/**
 * A custom view displayed in the center of the navigation bar.
 */
@property (nonatomic, readwrite, strong) UIView *titleView;

/**
 * The layer's width in points. If the item's layer controller has `maximumWidth == YES`, then the property
 * defines the minimum width of the layer.
 */
@property (nonatomic, readwrite) CGFloat width;

@property (nonatomic, readwrite) NSInteger resizePriority;

/**
 * The layer's current width in points. Managed by internaly by FRLayeredNavigationController.
 */
@property (nonatomic, readonly) CGFloat currentWidth;

/**
 * The minimal distance (when the child layer is as far on the left as possible) to the next layer in points.
 */
@property (nonatomic, readwrite) CGFloat nextItemDistance;

/**
 * If the view controller should get decorated by some UI chrome: the navigation bar.
 */
@property (nonatomic, readwrite) BOOL hasChrome;

/**
 * If the view should display a shadow
 */
@property (nonatomic, readwrite) BOOL displayShadow;

/**
 * A custom bar button item displayed on the left of the navigation bar.
 */
@property (nonatomic, strong) UIBarButtonItem *leftBarButtonItem;

/**
 * A custom bar button item displayed on the right of the navigation bar.
 */
@property (nonatomic, strong) UIBarButtonItem *rightBarButtonItem;

@property (nonatomic, readwrite) NSInteger rightMarginSnappingPriority;
- (void)addSnappingPointX:(CGFloat)x priority:(NSInteger)priority;
- (NSSet *)snappingPoints;

@property (nonatomic, strong, readwrite) NSString *name;
@property (nonatomic, assign, readwrite) BOOL resizeOnMove;

@end
