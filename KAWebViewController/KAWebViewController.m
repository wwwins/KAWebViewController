//
//  KAWViewController.m
//  KAWebViewController
//
//  Created by Kyle Adams on 08-04-14.
//  Copyright (c) 2014 Kyle Adams. All rights reserved.
//

#import "KAWebViewController.h"
#import "KAWToolbarItems.h"

#define FORWARD_BUTTON @"KAWForward"
#define BACK_BUTTON @"KAWBack"
#define IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

#define UIAlertView_Alert 1
#define UIAlertView_Confirm 2

#define EVENT_FROM_WEBVEIEW_TO_LOGIN @"ModalSegueFromWebViewToLogin"
#define EVENT_CALLBACK_FROM_WEBVIEW_TO_LOGIN @"ModalSegueFromWebViewToLoginCallBack"

@interface KAWebViewController () <UIWebViewDelegate, UIScrollViewDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) KAWToolbarItems *toolbar;

@property NSString *alertCallback;
@property NSString *confirmCallback;
@property NSString *externalCallback;
@property NSString *callbackFn;

@end

@implementation KAWebViewController

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.url = url;
    }
    return self;
}

#pragma mark - Properties

- (UIWebView *)webView
{
    if (!_webView) {
        _webView = [[UIWebView alloc] init];
    }
    return _webView;
}

- (KAWToolbarItems *)toolbar
{
    if (!_toolbar) {
        _toolbar = [[KAWToolbarItems alloc] initWithTarget:self];
        [self setButtonActions];
    }
    return _toolbar;
}

- (void)setUrl:(NSURL *)url
{
    _url = url;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    [self.webView loadRequest:[NSURLRequest requestWithURL:self.url]];
}

- (void)postWithURL:(NSURL *)url withParams:(NSString *)params;
{
  _url = url;
  self.webView.delegate = self;
  self.webView.scalesPageToFit = YES;
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL: self.url];
  [request setHTTPMethod: @"POST"];
  [request setHTTPBody: [params dataUsingEncoding: NSUTF8StringEncoding]];
  [self.webView loadRequest: request];
}

- (void)setButtonActions
{
    self.toolbar.refreshButton.action = @selector(refreshPage);
    self.toolbar.stopButton.action = @selector(stopRefresh);
    self.toolbar.backButton.action = @selector(previousPage);
    self.toolbar.forwardButton.action = @selector(forwardPage);
    self.toolbar.actionButton.action = @selector(actionPressed);
}

#pragma mark - Target Actions

-(void)previousPage
{
    [self.webView goBack];
}

-(void)forwardPage
{
    [self.webView goForward];
}

- (void)refreshPage
{
    [self.webView reload];
}

- (void)stopRefresh
{
    [self.webView stopLoading];
    [self updateUI];
}

- (void)actionPressed
{
    //needs some work
    NSArray *actionItems = @[self.webView.request.URL];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:actionItems applicationActivities:nil];
    
    [self presentViewController:avc animated:YES completion:nil];
}

#pragma mark - UIViewController Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    //self.navigationController.toolbar.barTintColor = self.navigationController.navigationBar.tintColor;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.view = self.webView;
}

- (void)updateUI
{
    [self setToolbarItemsForState:self.webView.loading];
    
    self.toolbar.backButton.enabled = self.webView.canGoBack ? YES : NO;
    self.toolbar.forwardButton.enabled = self.webView.canGoForward? YES : NO;
    
    if (!IPAD) {
        if (self.navigationController.toolbar.hidden) {
            [self.navigationController setToolbarHidden:NO animated:NO];
        }
    }
}

- (void)setToolbarItemsForState:(BOOL)loading
{
    if (loading) {
        if (!IPAD) {
            self.toolbarItems = self.toolbar.toolBarItemsWhenLoading;
        } else {
            self.navigationItem.rightBarButtonItems = self.toolbar.toolBarItemsWhenLoading.reverseObjectEnumerator.allObjects;
        }
        
    } else {
        if (!IPAD) {
            self.toolbarItems = self.toolbar.toolBarItemsWhenDoneLoading;
        } else {
            self.navigationItem.rightBarButtonItems = self.toolbar.toolBarItemsWhenDoneLoading.reverseObjectEnumerator.allObjects;
        }
        
        //self.title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];

    }
}

#pragma mark - add event listener for the login callback

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  addEventListener(self, @selector(loginCallBackWithData:), EVENT_CALLBACK_FROM_WEBVIEW_TO_LOGIN, nil);
}


- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  
  [self.navigationController setToolbarHidden:YES animated:YES];
  removeEventListener(self, EVENT_CALLBACK_FROM_WEBVIEW_TO_LOGIN, nil);
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self updateUI];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self updateUI];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self updateUI];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
  
  NSLog(@">>>request=%@",request.URL.absoluteString);
  
  if([request.URL.scheme isEqual:@"jsonp"])
  {
    
    NSDictionary *json =[NSJSONSerialization JSONObjectWithData: [request.URL.host dataUsingEncoding:NSUTF8StringEncoding] options: NSJSONReadingMutableContainers error: nil];
    NSString *name=[json objectForKey:@"name"];
    NSArray *params=[json objectForKey:@"params"];
    NSString *callback=[json objectForKey:@"callback"];
    
    if([name isEqualToString:@"alert"])
    {
      
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[params objectAtIndex:0]
                                                      message:[params objectAtIndex:1]
                                                     delegate:self
                                            cancelButtonTitle:@"確定"
                                            otherButtonTitles:nil];
      alert.tag = UIAlertView_Alert;
      [alert show];
      _alertCallback=callback;
    }
    
    if([name isEqualToString:@"confirm"])
    {
      
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[params objectAtIndex:0]
                                                      message:[params objectAtIndex:1]
                                                     delegate:self
                                            cancelButtonTitle:[params objectAtIndex:2]
                                            otherButtonTitles:[params objectAtIndex:3], nil];
      alert.tag = UIAlertView_Confirm;
      [alert show];
      _confirmCallback=callback;
    }
    
    if([name isEqualToString:@"open"])
    {
      [self openBroswer:[params objectAtIndex:0]];
      NSString *exejs=[callback stringByAppendingString:@"()"];
      [self runScript:exejs];
    }
    
    if ([name isEqualToString:@"Login"]) {
      _externalCallback = @"ExternalCallback";
      _callbackFn = callback;
//      [self runScript:[callback stringByAppendingString:@"('true')"]];
      dispatchEvent(EVENT_FROM_WEBVEIEW_TO_LOGIN, nil);
    }
    
    return NO;
  }
  
  if (![request.URL.scheme isEqual:@"http"] && ![request.URL.scheme isEqual:@"https"]) {
    [[UIApplication sharedApplication] openURL:[request URL]];
    return NO;
  }
  return YES;
}

#pragma mark - for js

- (void)openBroswer:(NSString*)url{
  [[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:url]];
}

- (void)runScript:(NSString *)script{
  [self.webView stringByEvaluatingJavaScriptFromString:script];
}

#pragma mark - perform externalCallback

- (void)loginCallBackWithData:(NSNotification *)notification
{
  trace(@"loginCallBackWithData:%@",notification.userInfo);
  
  NSDictionary *dic = notification.userInfo;
  if ([[dic valueForKeyPath:@"Success"] boolValue]){
    [self runScript:[_externalCallback stringByAppendingString:[NSString stringWithFormat:@"('%@',true,'%@')",_callbackFn,[dic valueForKey:@"Token"]]]];
    
  }
  else {
    [self runScript:[_externalCallback stringByAppendingString:[NSString stringWithFormat:@"('%@',false)", _callbackFn]]];
    
  }
}

@end
