//
//  UVWelcomeViewController.m
//  UserVoice
//
//  Created by UserVoice on 12/15/09.
//  Copyright 2009 UserVoice Inc. All rights reserved.
//

#import "UVWelcomeViewController.h"
#import "UVStyleSheet.h"
#import "UVFooterView.h"
#import "UVSession.h"
#import "UVForum.h"
#import "UVClientConfig.h"
#import "UVSubdomain.h"
#import "UVQuestion.h"
#import "UVAnswer.h"
#import "UVNewTicketViewController.h"
#import "UVSuggestionListViewController.h"
#import "UVSignInViewController.h"
#import "UVStreamPoller.h"
#import <QuartzCore/QuartzCore.h>

#define UV_FORUM_LIST_TAG_CELL_LABEL 1000
#define UV_FORUM_LIST_TAG_CELL_IMAGE 1001
#define UV_FORUM_LIST_TAG_CELL_QUESTION_SEGMENTS 1002
#define UV_FORUM_LIST_TAG_CELL_MSG_TAG 1003
#define UV_FORUM_LIST_TAG_CELL_QUESTION_LABELS 1004

#define UV_FORUM_LIST_SECTION_FORUMS 0
#define UV_FORUM_LIST_SECTION_SUPPORT 1
#define UV_FORUM_LIST_SECTION_QUESTIONS 2

@implementation UVWelcomeViewController

@synthesize forum = _forum, 
	question = _question, 
	questions = _questions;

- (NSString *)backButtonTitle {
	return @"Welcome";
}

- (void)questionSegmentChanged:(id)sender {
	UISegmentedControl *segments = (UISegmentedControl *)sender;
	[self showActivityIndicator];
	// still using single question hack of assigning a single current one
	[UVAnswer createWithQuestion:self.question andValue:(segments.selectedSegmentIndex + 1) andDelegate:self];
}

- (void)didCreateAnswer:(UVAnswer *)theAnswer {
	[self hideActivityIndicator];
	self.question.currentAnswer = theAnswer;
	
	// Prompt for app store review if the returned rating indicates this (driven by
	// server side logic based on rating value) and if we actually have an app id.
	if (theAnswer.value >= 4 && [UVSession currentSession].clientConfig.itunesApplicationId) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Rating"
														message:@"Would you like to add your rating to the iTunes store?"
													   delegate:self
											  cancelButtonTitle:@"Cancel"
											  otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
	}
}

#pragma mark ===== UIAlertViewDelegate Methods =====

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.firstOtherButtonIndex) {
		NSString *url = [NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@",
						 [UVSession currentSession].clientConfig.itunesApplicationId];
		
		NSLog(@"Attempting to open iTunes page: %@", url);
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
	}
}

#pragma mark ===== table cells =====

- (void)initCellForForum:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    cell.textLabel.text = [_forum prompt];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (CGFloat)heightForViewWithHeader:(NSString *)header subheader:(NSString *)subheader 
{
	CGFloat screenWidth = [UVClientConfig getScreenWidth];
	
	if (subheader) {
		CGSize subSize = [subheader sizeWithFont:[UIFont systemFontOfSize:14]
							   constrainedToSize:CGSizeMake((screenWidth - 40), 9999)
								   lineBreakMode:UILineBreakModeWordWrap];
		return subSize.height + 35 + 5 + 5; // (subheader + header + padding between/bottom)
		
	} else if (header) {
		return 35 + 5; // header + padding bottom only
	}
	
	return 10;
}

- (void)initCellForSupport:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {    
    cell.textLabel.text = [NSString stringWithFormat:@"Contact %@", [UVSession currentSession].clientConfig.subdomain.name];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)addQuestionCell:(UIView *)view labelWithText:(NSString *)text alignment:(UITextAlignment)alignment {
	// Simply stack up all labels with the same frame. The alignment will take care of things.
	UILabel *label = [[UILabel alloc] initWithFrame:view.bounds];
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont systemFontOfSize:12];
	label.textColor = [UVStyleSheet tableViewHeaderColor];
	label.text = text;
	label.textAlignment = alignment;
	[view addSubview:label];
	[label release];
}

- (void)updateSegmentsValue:(UISegmentedControl *)segments {
	if (self.question.currentAnswer && self.question.currentAnswer.value > 0) {
		// Answers are 1-5 (0 means none), indexes 0-4
		segments.selectedSegmentIndex = self.question.currentAnswer.value - 1;
	} else {
		segments.selectedSegmentIndex = UISegmentedControlNoSegment;
	}
}

- (void)initCellForQuestion:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
	[self removeBackgroundFromCell:cell];	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	CGFloat screenWidth = [UVClientConfig getScreenWidth];
    CGFloat margin = (screenWidth > 480) ? 45 : 10;
	
	UIView *bg = [[UILabel alloc] initWithFrame:CGRectMake(-margin, -margin, screenWidth, 80)];		
	bg.backgroundColor = [UVStyleSheet backgroundColor];
	[cell.contentView addSubview:bg];
	[bg release];
	
	NSArray *items = [NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", nil];
	UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:items];
	segments.tag = UV_FORUM_LIST_TAG_CELL_QUESTION_SEGMENTS;
	segments.frame = CGRectMake(0, 0, (screenWidth - 2 * margin), 44);
	[self updateSegmentsValue:segments]; // necessary to avoid triggering an update when we set it in the customize method
	[segments addTarget:self action:@selector(questionSegmentChanged:) forControlEvents:UIControlEventValueChanged];
	// add segments
	[cell.contentView addSubview:segments];
	[segments release];
}

- (void)customizeCellForQuestion:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
	// disable unless user
	BOOL enabled = [UVSession currentSession].user != nil;
	UISegmentedControl *segments = (UISegmentedControl *)[cell.contentView viewWithTag:UV_FORUM_LIST_TAG_CELL_QUESTION_SEGMENTS];
	[segments setEnabled:enabled];
    CGFloat screenWidth = [UVClientConfig getScreenWidth];
    CGFloat margin = (screenWidth > 480) ? 45 : 10;
	
	if (enabled) {
		[[cell.contentView viewWithTag:UV_FORUM_LIST_TAG_CELL_MSG_TAG] setHidden:YES];
        UIView *questionLabels = [cell.contentView viewWithTag:UV_FORUM_LIST_TAG_CELL_QUESTION_LABELS];
        if (questionLabels == NULL) {
            questionLabels = [[[UIView alloc] initWithFrame:CGRectMake(10, 49, screenWidth - 2 * (margin + 10), 15)] autorelease];
            questionLabels.tag = UV_FORUM_LIST_TAG_CELL_QUESTION_LABELS;
            [self addQuestionCell:questionLabels labelWithText:@"Unlikely" alignment:UITextAlignmentLeft];
            [self addQuestionCell:questionLabels labelWithText:@"Maybe" alignment:UITextAlignmentCenter];
            [self addQuestionCell:questionLabels labelWithText:@"Absolutely" alignment:UITextAlignmentRight];
            [cell.contentView addSubview:questionLabels];
        } else {
            questionLabels.hidden = NO;
        }
	} else {
		[[cell.contentView viewWithTag:UV_FORUM_LIST_TAG_CELL_QUESTION_LABELS] setHidden:YES];
        UILabel *label = (UILabel *)[cell.contentView viewWithTag:UV_FORUM_LIST_TAG_CELL_MSG_TAG];
        if (label == NULL) {
            label = [[UILabel alloc] initWithFrame:CGRectMake(0, 46, screenWidth - 2 * margin, 20)];
            label.tag = UV_FORUM_LIST_TAG_CELL_MSG_TAG;
            label.textAlignment = UITextAlignmentCenter;
            label.font = [UIFont boldSystemFontOfSize:12];
            label.text = @"Please sign in to answer.";
            label.backgroundColor = [UIColor clearColor];
            label.textColor = [UVStyleSheet alertTextColor];

            [cell.contentView addSubview:label];
            [label release];
        } else {
            [label setHidden:NO];
        }
	}
}

- (void)initCellForSpacer:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
	[self removeBackgroundFromCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	CGFloat screenWidth = [UVClientConfig getScreenWidth];
	
	UIView *bg = [[UILabel alloc] initWithFrame:CGRectMake(-10, -10, screenWidth, 11)];		
	bg.backgroundColor = [UVStyleSheet backgroundColor];
	[cell.contentView addSubview:bg];
	[bg release];
}

- (UIView *)viewWithHeader:(NSString *)header subheader:(NSString *)subheader {
	CGFloat height = [self heightForViewWithHeader:header subheader:subheader];
	
	CGFloat screenWidth = [UVClientConfig getScreenWidth];
    CGFloat margin = ((screenWidth > 480) ? 45 : 10) + 10;
	
	UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, height)] autorelease];
	headerView.backgroundColor = [UVStyleSheet backgroundColor];
	
	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(margin, 5, (screenWidth - 2 * margin), 35)];
	title.text = header;
	title.font = [UIFont boldSystemFontOfSize:18];
	title.backgroundColor = [UIColor clearColor];
	title.textColor = [UVStyleSheet tableViewHeaderColor];
	[headerView addSubview:title];
	[title release];
	
	if (subheader) {
		UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, 33, (screenWidth - 2 * margin), height - (33 + 5))];
		subtitle.text = subheader;
		subtitle.lineBreakMode = UILineBreakModeWordWrap;
		subtitle.numberOfLines = 0;
		subtitle.font = [UIFont systemFontOfSize:14];
		subtitle.backgroundColor = [UIColor clearColor];
		subtitle.textColor = [UVStyleSheet tableViewHeaderColor];
		[headerView addSubview:subtitle];
		[subtitle release];
	}
	
	return headerView;
}

- (NSString *)headerTextForSection:(NSInteger)section {
	if (section == 0) {
		return @"Give Feedback";
		
	} else if (section == 1) {
		return [UVSession currentSession].clientConfig.ticketsEnabled ? @"Contact Support" : nil;
		
	} else {
		return [UVSession currentSession].clientConfig.questionsEnabled ? @"Leave A Rating" : nil;
	}
}

- (NSString *)subHeaderTextForSection:(NSInteger)section {	
	if (section <= UV_FORUM_LIST_SECTION_SUPPORT) {
		return nil;
		
	} else {
		NSArray *qs = [UVSession currentSession].clientConfig.questions;
		UVQuestion *q = [qs objectAtIndex:0];
		return [UVSession currentSession].clientConfig.questionsEnabled ? q.text : nil;
	}
}

#pragma mark ===== UITableViewDataSource Methods =====

- (UITableViewCell *)tableView:(UITableView *)theTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *identifier = @"";
	BOOL selectable = YES;

	UITableViewCellStyle style = UITableViewCellStyleDefault;	
	if (indexPath.section == UV_FORUM_LIST_SECTION_FORUMS) {
		identifier = @"Forum";
		
	} else if (indexPath.section == UV_FORUM_LIST_SECTION_SUPPORT) {		
		if ([UVSession currentSession].clientConfig.ticketsEnabled) {
			identifier = @"Support";
			
		} else {
			identifier = @"Spacer";
            selectable = NO;
		}
		
	} else if (indexPath.section == UV_FORUM_LIST_SECTION_QUESTIONS) {
		if ([UVSession currentSession].clientConfig.questionsEnabled) {
		
			identifier = @"Question";
			if ([UVSession currentSession].user == nil)
				selectable = YES;
			
		} else {
			identifier = @"Spacer";
            selectable = NO;
		}
	}
	
	return [self createCellForIdentifier:identifier
							   tableView:theTableView
							   indexPath:indexPath
								   style:style
							  selectable:selectable];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {	
	[theTableView deselectRowAtIndexPath:indexPath animated:YES];
	
	switch (indexPath.section) {
        case UV_FORUM_LIST_SECTION_FORUMS: {
            UVSuggestionListViewController *next = [[UVSuggestionListViewController alloc] initWithForum:self.forum];
            [self.navigationController pushViewController:next animated:YES];            
            [next release];
			break;
		}
        case UV_FORUM_LIST_SECTION_SUPPORT: {
            UVNewTicketViewController *next = [[UVNewTicketViewController alloc] init];
            [self.navigationController pushViewController:next animated:YES];
            [next release];
			break;
		}
		case UV_FORUM_LIST_SECTION_QUESTIONS: {
			if ([UVSession currentSession].user==nil) {
				UVSignInViewController *next = [[UVSignInViewController alloc] init];
				[self.navigationController pushViewController:next animated:YES];
				[next release];
			}
			break;
		}
		default:
			break;
	}
}

#pragma mark ===== UITableViewDelegate Methods =====

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == UV_FORUM_LIST_SECTION_FORUMS) {
		return 45;
		
	} else if (indexPath.section == UV_FORUM_LIST_SECTION_SUPPORT) {
		return [UVSession currentSession].clientConfig.ticketsEnabled ? 45 : 0.0;
		
	} else if (indexPath.section == UV_FORUM_LIST_SECTION_QUESTIONS) {
		return [UVSession currentSession].clientConfig.questionsEnabled ? 70 : 0.0;
	}
	return 0.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [self heightForViewWithHeader:[self headerTextForSection:section]
							   subheader:[self subHeaderTextForSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return [self viewWithHeader:[self headerTextForSection:section]
					  subheader:[self subHeaderTextForSection:section]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return 0.0;
}

#pragma mark ===== Basic View Methods =====

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	[super loadView];
	[self.navigationItem setHidesBackButton:YES animated:NO];
	
	CGRect frame = [self contentFrame];
	tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
	tableView.dataSource = self;
	tableView.delegate = self;
	tableView.sectionFooterHeight = 0.0;
	tableView.sectionHeaderHeight = 0.0;
    tableView.backgroundColor = [UVStyleSheet backgroundColor];
	tableView.tableFooterView = [UVFooterView footerViewForController:self];
	self.view = tableView;	
	
	if ([UVSession currentSession].clientConfig.questionsEnabled) {
		self.questions = [UVSession currentSession].clientConfig.questions;
		self.question = [_questions objectAtIndex:0];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];		
	
	self.forum = [UVSession currentSession].clientConfig.forum;		
	if ([self needsReload]) {
		NSLog(@"WelcomeView needs reload");
		
		UISegmentedControl *segments = 
			(UISegmentedControl *)[tableView viewWithTag:UV_FORUM_LIST_TAG_CELL_QUESTION_SEGMENTS];
		
		[(UVFooterView *)tableView.tableFooterView reloadFooter];
		[self updateSegmentsValue:segments];
	}

	[tableView reloadData];
    
    UVFooterView *footer = (UVFooterView *) self.tableView.tableFooterView;
    [footer reloadFooter];
}

- (void)dealloc {
    self.forum = nil;
    self.question = nil;
    self.tableView = nil;
    self.questions = nil;
    [super dealloc];
}

@end
