//
//  ControlsView.h
//  BluShepherd
//
//  Created by Simon Fell on 1/1/17.
//  Copyright © 2017 Simon Fell. All rights reserved.
//

#import "StatusWatcherView.h"


@interface ControlsView : StatusWatcherView

@property (readonly) BOOL playing;
@property (readonly) BOOL shuffling;

@end
