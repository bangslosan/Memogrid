//
//  MGViewController.m
//  Memogrid
//
//  Created by Seraphin Hochart on 2013-02-17.
//  Copyright (c) 2013 Seraphin Hochart. All rights reserved.
//

#import "MGViewController.h"
#import "MGNextLevelViewController.h"
#import "MGMenuViewController.h"
#import "MGUserLevel.h"
#import <AudioToolbox/AudioServices.h>

@interface MGViewController ()

@end

@implementation MGViewController

#define kAlertTutorial 234
#define kAlertShaking  2345

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initVars]; // Init Variables
    [self initUI];   // Setup UI
    [self initGame]; // Init Game
}

-(void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    [self stopGuessing];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self initPreGame];
    [self.view layoutSubviews];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [b_ready setHidden:YES];
    [UIView animateWithDuration:0.3 animations:^{
        l_currentlvl.alpha = 0;
        mg_square.alpha = 0;
        b_ready.alpha = 0;
    }];
}

#pragma mark - INITIALIZATION

- (void) initVars
{
    [self becomeFirstResponder];
    canPlay        = NO;
    debugMode      = NO;
}

- (void) initPreGame
{
    // Display Level starts at index 1, whereas real level starts at 0
    int current = [[MGUserLevel sharedInstance] current_level];
    GameMode mode = [[MGUserLevel sharedInstance] current_mode];
    l_currentlvl.text = [NSString stringWithFormat:@"%02d", current+1];
    
    // Set views
    [mg_square setHidden:YES];
    [b_ready setHidden:NO];
    [b_ready startBlinking];
    b_ready.userInteractionEnabled = YES;
    b_ready.alpha = 0;

    [UIView animateWithDuration:0.4 animations:^{
        mg_square.alpha = 0;
        l_currentlvl.alpha = 1;
        b_ready.alpha = 1;
    }];
    
    if (current == 0 && mode == Sequence) {
        UIAlertView *firstTime = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"classic_to_sequence", nil) delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [firstTime show];
    }
}

- (void) initGame
{    
    // Init rectangle de jeu
    mg_square = [[MGSquare alloc] initWithFrame:[self getMainSquareFrameForOrientation:[self interfaceOrientation]]];
    mg_square.backgroundColor = [UIColor clearColor];
    mg_square.canPlay = canPlay;
    [self.view addSubview:mg_square];
    [self.view bringSubviewToFront:b_ready];
    
    mg_level = [[MGLevelManager alloc] init];
    [MGLevelManager init];
    
    // Detect if it is the user's first time
    BOOL isFirstTime = [[NSUserDefaults standardUserDefaults] boolForKey:@"isFirstTime"];
    if (!isFirstTime) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isFirstTime"];
        
        UIAlertView *firstTime = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"start_to_tutorial", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"notnow", nil) otherButtonTitles:NSLocalizedString(@"Tutorial", nil), nil];
        firstTime.tag = kAlertTutorial;
        [firstTime show];
    }
}

- (void) initUI
{
    self.view.backgroundColor = C_BACK;
}

- (CGRect) getMainSquareFrameForOrientation:(UIInterfaceOrientation)orientation
{
    float pos_x = ((IS_IPAD) ? [UIScreen mainScreen].bounds.size.width/2 - (((sq_SIZE+2) * ROWS)/2) : 1.5);
    float pos_y = [UIScreen mainScreen].bounds.size.height/2 - (((sq_SIZE+2) * ROWS)/2);
    
    if (orientation == UIInterfaceOrientationLandscapeLeft || self.interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        pos_x = ((IS_IPAD) ? [UIScreen mainScreen].bounds.size.height/2 - (((sq_SIZE+2) * ROWS)/2) : 1.5);
        pos_y = [UIScreen mainScreen].bounds.size.width/2 - (((sq_SIZE+2) * ROWS)/2);
    }
    CGRect rect_game = CGRectMake(pos_x, pos_y, (sq_SIZE+2) * ROWS, (sq_SIZE+2) * COLS);
    
    return rect_game;
}

#pragma mark - INTERFACE FUNCTIONS


- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    mg_square.frame = [self getMainSquareFrameForOrientation:toInterfaceOrientation];
}


#pragma mark - GAME INIT

- (IBAction) startGame
{    
    // Start Level

    [UIView animateWithDuration:0.3 animations:^{
        l_currentlvl.alpha = 0;
        [b_ready setHidden:YES];
        [mg_square setHidden:NO];
        b_ready.alpha   = 0;
        mg_square.alpha = 1;
    } completion:^(BOOL finished) {
        // Set user/view interactions
        b_ready.userInteractionEnabled = NO;
        [self stopGuessing];
        
        // Go to the next level from the UserLevel Singleton
        GameMode gm_current = [[MGUserLevel sharedInstance] current_mode];
        int current         = [[MGUserLevel sharedInstance] current_level];

        int difficulty = [MGLevelManager getDifficultyFromLevel:current andMode:gm_current];
        [self startGameWithLevel:current andDifficulty:difficulty andMode:gm_current];
    }];
    
}

#pragma mark - GAME FLOW FUNCTIONS

- (void) startGameWithLevel:(int)level andDifficulty:(int)difficulty andMode:(GameMode)mode
{
    level = (level > 24) ? 24 : level; // Don't go over 25
    difficulty = (debugMode) ? 2 : difficulty;
    
    [mg_square setGameWithDifficulty:difficulty andMode:mode];
    
    // If we are in Simons/Sequence, provide a bigger delay.
    float delay = (mode == Sequence || mode == Simon) ? (0.4*difficulty)+0.5 : 2.0;
    
    [self performSelector:@selector(startGuessing) withObject:self afterDelay:delay];
    
    // Analytics
    //NSDictionary *d_analytics = [[NSDictionary alloc] initWithObjects:@[[MGLevelManager modeToString:mode], [NSString stringWithFormat:@"%i",level]] forKeys:@[@"mode", @"level"] ];
    //[PFAnalytics trackEvent:@"Game - Start" dimensions:d_analytics];
}

- (void) startGuessing
{
    [self clear];
    [self userCanPlay:YES];
}

- (void) stopGuessing
{
    [self clear];
    [self userCanPlay:NO];
}

- (void) failedGame
{
    // 1. Show what the user should have tapped & vibrate
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    [self userCanPlay:NO];
    [mg_square showAnswer];
    
    // Analytics
    //GameMode mode = [[MGUserLevel sharedInstance] current_mode];
    //int level     = [[MGUserLevel sharedInstance] current_level];
    //NSDictionary *d_analytics = [[NSDictionary alloc] initWithObjects:@[[MGLevelManager modeToString:mode], [NSString stringWithFormat:@"%i",level]] forKeys:@[@"mode", @"level"] ];
    //[PFAnalytics trackEvent:@"Game - Failed" dimensions:d_analytics];
    
    // 2. Then go to the Lost page.
    [self performSelector:@selector(endedLevelWithSuccess:) withObject:NO afterDelay:1.0];
}

- (void) succeededGame
{
    [self userCanPlay:NO];
    
    // Call the end function with a delay so we can have time to show user's feedback
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self endedLevelWithSuccess:YES];
    });
}

- (void) endedLevelWithSuccess:(BOOL)didWin
{
    [self stopGuessing];
    
    GameMode mode = [[MGUserLevel sharedInstance] current_mode];
    int level     = [[MGUserLevel sharedInstance] current_level];
    
    // Analytics
    //NSDictionary *d_analytics = [[NSDictionary alloc] initWithObjects:@[[MGLevelManager modeToString:mode], [NSString stringWithFormat:@"%i",level]] forKeys:@[@"mode", @"level"] ];
    
    if (didWin) {
        [MGLevelManager setUserFinishedLevel:level forMode:mode];
        level++;
        
        // Switch from Classic to Sequence
        if (level > 24 && mode == Classic) {
            mode = Sequence;
            level = 0;
            NSLog(@"Moving from Classic to Sequence");
            UIAlertView *al_nextMode = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"congratulations", nil) message:NSLocalizedString(@"finished_classic_message", nil) delegate:self cancelButtonTitle:@"Next" otherButtonTitles: nil];
            [al_nextMode show];
        }
        
        // Done the game!
        if (level > 24 && mode == Sequence) {
            level--; // put it back for the same level.
            // Congratulations
            UIAlertView *al_done = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"congratulations", nil) message:NSLocalizedString(@"finished_sequence_message", nil) delegate:self cancelButtonTitle:@"Yay!" otherButtonTitles: nil];
            [al_done show];
        }

        //[PFAnalytics trackEvent:@"Game - Succeeded" dimensions:d_analytics];
        [[MGUserLevel sharedInstance] setCurrentLevel:level forMode:mode];
        MGNextLevelViewController *vc_next = [[MGNextLevelViewController alloc] init];
        [self presentModalViewController:vc_next withPushDirection:kCATransitionFromTop];

    } else {
        // Start over
        //[PFAnalytics trackEvent:@"Game - Failed" dimensions:d_analytics];
        [self initPreGame];
    }
    
}

#pragma mark - GAME FUNCTIONS

- (void) userCanPlay:(BOOL)usercanplay
{
    canPlay = usercanplay;
    mg_square.canPlay = canPlay;
    b_newgame.hidden = !usercanplay;
}

- (void) clear
{
    [mg_square clear];
}

- (IBAction)reset
{
    [self clear];
}

#pragma mark - SHAKE MOTION

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event { //RESTART NEW GAME WHEN iPHONE IS SHAKED
	if (event.subtype == UIEventSubtypeMotionShake)
	{
		UIAlertView * shakeAns = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"shake_title", nil)
                                  message:NSLocalizedString(@"shake_message", nil)
                                  delegate:self
                                  cancelButtonTitle:NSLocalizedString(@"no", nil)
                                  otherButtonTitles:@"OK",nil];
        shakeAns.tag = kAlertShaking;
		[shakeAns show];
	}
}

- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == kAlertTutorial) {
        // First time playing
        // Shaking alert
        if (buttonIndex == 1) {
            [self performSegueWithIdentifier:@"goToTutorial" sender:self];
            // [PFAnalytics trackEvent:@"Game - First Tutorial"];
        } else {
            NSLog(@"Cancel Tutorial");
        }
    } else if (actionSheet.tag == kAlertShaking){
        // Shaking alert
        if (buttonIndex == 1) {
            [self startGame];
            NSLog(@"Reset");
        } else {
            NSLog(@"cancel");
        }
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}


@end
