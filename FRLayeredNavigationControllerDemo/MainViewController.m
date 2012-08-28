//
//  MainViewController.m
//  FRLayeredNavigationController
//
//  Created by Stefan Wehr on 16.08.12.
//
//

#import "MainViewController.h"
#import "SampleListViewController.h"
#import "FRLayeredNavigationController.h"
#import "FRLayeredNavigationItem.h"

@interface MainViewController ()
@property (nonatomic, strong) FRLayeredNavigationController *rootViewController;
@property (nonatomic, strong) UILabel *widthLabel;
@end

#define MARGIN_X 4
#define MARGIN_TOP 80
#define MARGIN_BOTTOM 4
#define FULL_WIDTH (1024 - 2 * MARGIN_X)

@implementation MainViewController

- (void)buttonClicked {
    UIView *v = self.rootViewController.view;
    CGFloat newWidth = (v.frame.size.width > 1000) ? 900 : FULL_WIDTH;
    [UIView animateWithDuration:1.0 delay:0.0 options: UIViewAnimationOptionLayoutSubviews animations:^{
        self.widthLabel.text = [NSString stringWithFormat:@"Width: %.0f", newWidth];
        CGRect frame = CGRectMake(v.frame.origin.x, v.frame.origin.y, newWidth, v.frame.size.height);
        v.frame = frame;
    } completion:^(BOOL finished) {
        // do nothing
    }];
}

- (id)init {
    if ((self = [super init])) {
        UIViewController *vc = [[SampleListViewController alloc] init];
        FRLayeredNavigationController *fvc = [[FRLayeredNavigationController alloc]
                                              initWithRootViewController:vc
                                                           configuration:^(FRLayeredNavigationItem *item) {
                                                               item.width = 200; //600;
                                                               item.nextItemDistance = 64; //2;
                                                           }];
        self.rootViewController = fvc;
    }
    return self;
}

- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768, 1024-44)];
    UIView *lv = self.rootViewController.view;
    lv.clipsToBounds = YES;
    lv.frame = CGRectMake(MARGIN_X, MARGIN_TOP, FULL_WIDTH, 768 - 44 - MARGIN_TOP - MARGIN_BOTTOM);
    [v addSubview:lv];
    lv.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    v.backgroundColor = [UIColor orangeColor];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [b setTitle:@"Change Size" forState:UIControlStateNormal];
    b.frame = CGRectMake(20, 20, 130, 40);
    [b addTarget:self action:@selector(buttonClicked) forControlEvents: UIControlEventTouchUpInside];
    [v addSubview:b];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(170, 20, 130, 40)];
    l.text = [NSString stringWithFormat:@"  Width: %.0f", lv.frame.size.width];
    self.widthLabel = l;
    [v addSubview:l];
    self.view = v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

@end
