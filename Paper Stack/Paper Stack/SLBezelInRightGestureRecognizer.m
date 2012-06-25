//
//  SLBezelGestureRecognizer.m
//  Paper Stack
//
//  Created by Adam Wulf on 6/19/12.
//  Copyright (c) 2012 Visere. All rights reserved.
//

#import "SLBezelInRightGestureRecognizer.h"
#import "Constants.h"

@implementation SLBezelInRightGestureRecognizer
@synthesize panDirection;
@synthesize numberOfRepeatingBezels;

-(id) initWithTarget:(id)target action:(SEL)action{
    self = [super initWithTarget:target action:action];
    ignoredTouches = [[NSMutableSet alloc] init];
    validTouches = [[NSMutableSet alloc] init];
    numberOfRepeatingBezels = 0;
    dateOfLastBezelEnding = nil;
    return self;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer{
    return YES;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer{
    return NO;
}

/**
 * finds the touch that is furthest left
 *
 * right now, this gesture is effectively hard coded to
 * allow for bezeling in from the right.
 *
 * it would need a refactor to support gesturing from
 * other sides, despite what its API looks like
 */
-(CGPoint) furthestLeftTouchLocation{
    CGPoint ret = CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
    for(int i=0;i<[self numberOfTouches];i++){
        CGPoint ret2 = [self locationOfTouch:i inView:self.view];
        BOOL isIgnoredTouchLocation = NO;
        if([self numberOfTouches] > 2){
            for(UITouch* touch in ignoredTouches){
                CGPoint igLoc = [touch locationInView:self.view];
                isIgnoredTouchLocation = isIgnoredTouchLocation || CGPointEqualToPoint(ret2, igLoc);
            }
        }
        if(!isIgnoredTouchLocation && ret2.x < ret.x){
            ret = ret2;
        }
    }
    return ret;
}
/**
 * returns the furthest right touch point of the gesture
 */
-(CGPoint) furthestRightTouchLocation{
    CGPoint ret = CGPointZero;
    for(int i=0;i<[self numberOfTouches];i++){
        CGPoint ret2 = [self locationOfTouch:i inView:self.view];
        BOOL isIgnoredTouchLocation = NO;
        if([self numberOfTouches] > 2){
            for(UITouch* touch in ignoredTouches){
                CGPoint igLoc = [touch locationInView:self.view];
                isIgnoredTouchLocation = isIgnoredTouchLocation || CGPointEqualToPoint(ret2, igLoc);
            }
        }
        if(!isIgnoredTouchLocation && ret2.x > ret.x){
            ret = ret2;
        }
    }
    return ret;
}

/**
 * returns the furthest point of the gesture if possible,
 * otherwise returns default behavior.
 *
 * this is so that the translation isn't an average of
 * touch locations but will follow the lead finger in
 * the gesture.
 */
-(CGPoint) translationInView:(UIView *)view{
    if(self.view){
        CGPoint p = [self furthestLeftTouchLocation];
        return p;
    }
    return CGPointZero;
}

/**
 * the first touch of a gesture.
 * this touch may interrupt an animation on this frame, so set the frame
 * to match that of the animation.
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    BOOL foundValidTouch = NO;
    for(UITouch* touch in touches){
        CGPoint point = [touch locationInView:self.view];
        if(point.x < self.view.frame.size.width - kBezelInGestureWidth){
            // only accept touches on the right bezel
            [self ignoreTouch:touch forEvent:event];
        }else{
            [validTouches addObject:touch];
            foundValidTouch = YES;
        }
    }
    if(!foundValidTouch) return;
    
    panDirection = SLBezelDirectionNone;
    lastKnownLocation = [self furthestLeftTouchLocation];
    
    // ok, a touch began, and we need to start the gesture
    // and increment our repeat count
    //
    // we have to manually track valid touches for this gesture
    //
    // the default for a gesture recognizer:
    //   after the recognizer is set to UIGestureRecognizerStateEnded,
    //   then all touches from that gesture are ignored for the rest
    //   of the life of that touch
    //
    // we want to support the user gesturing with two fingers into the bezel,
    // then gesturing both OR just one finger back off the bezel and repeating.
    //
    // since we want to effectively re-use a touch for the 2nd bezel gesture,
    // we'll keep the gesture alive and just increment the repeat count counter
    // instead of ending the gesture entirely.
    //
    if([validTouches count] >= 2){
        if(!dateOfLastBezelEnding || [dateOfLastBezelEnding timeIntervalSinceNow] > -.5){
            numberOfRepeatingBezels++;
        }else{
            numberOfRepeatingBezels = 1;
        }
        if(self.state != UIGestureRecognizerStateBegan){
            self.state = UIGestureRecognizerStateBegan;
        }
        [dateOfLastBezelEnding release];
        dateOfLastBezelEnding = nil;
    }
}

/**
 * when the touch moves, track which direction the gesture
 * is moving and record it
 */
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    CGPoint p = [self furthestLeftTouchLocation];
    if(p.x != lastKnownLocation.x){
        panDirection = SLBezelDirectionNone;
        if(p.x < lastKnownLocation.x){
            panDirection = panDirection | SLBezelDirectionLeft;
        }
        if(p.x > lastKnownLocation.x){
            panDirection = panDirection | SLBezelDirectionRight;
        }
        if(p.y > lastKnownLocation.y){
            panDirection = panDirection | SLBezelDirectionDown;
        }
        if(p.y < lastKnownLocation.y){
            panDirection = panDirection | SLBezelDirectionUp;
        }
        lastKnownLocation = p;
    }
    if(self.state == UIGestureRecognizerStateBegan){
        firstKnownLocation = [self furthestRightTouchLocation];
    }
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    for(UITouch* touch in touches){
        [ignoredTouches removeObject:touch];
        [validTouches removeObject:touch];
    }
    if([validTouches count] == 0 && self.state == UIGestureRecognizerStateChanged){
        self.state = UIGestureRecognizerStateEnded;
        [dateOfLastBezelEnding release];
        dateOfLastBezelEnding = [[NSDate date] retain];
    }
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    if(self.state == UIGestureRecognizerStateChanged ||
       self.state == UIGestureRecognizerStateBegan){
        self.state = UIGestureRecognizerStateCancelled;
    }
    for(UITouch* touch in touches){
        [ignoredTouches removeObject:touch];
        [validTouches removeObject:touch];
    }
    if([validTouches count] == 0 && self.state == UIGestureRecognizerStateChanged){
        self.state = UIGestureRecognizerStateCancelled;
        [dateOfLastBezelEnding release];
        dateOfLastBezelEnding = [[NSDate date] retain];
    }
}
-(void)ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event{
    [ignoredTouches addObject:touch];
    [super ignoreTouch:touch forEvent:event];
}
- (void)reset{
    [super reset];
    panDirection = SLBezelDirectionNone;
    [ignoredTouches removeAllObjects];
}
- (void) resetPageCount{
    numberOfRepeatingBezels = 0;
    [dateOfLastBezelEnding release];
    dateOfLastBezelEnding = nil;
}
@end
