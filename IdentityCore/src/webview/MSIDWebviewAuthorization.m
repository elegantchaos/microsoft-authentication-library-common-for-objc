//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDWebviewAuthorization.h"
#import <SafariServices/SafariServices.h>
#import "MSIDSystemWebviewController.h"
#import "MSIDError.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDTelemetry.h"
#import "MSIDOAuth2EmbeddedWebviewController.h"
#import "MSIDSystemWebviewController.h"

@implementation MSIDWebviewAuthorization

static MSIDWebviewSession *s_currentSession = nil;

+ (void)startEmbeddedWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                          factory:(MSIDOauth2Factory *)factory
                                          context:(id<MSIDRequestContext>)context
                                completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    NSString *state = [factory requestState];
    NSURL *startURL = [factory startURLFromConfiguration:configuration requestState:state];
    (void)startURL;
    (void)state;
    
    MSIDOAuth2EmbeddedWebviewController *embeddedWebviewController = [[MSIDOAuth2EmbeddedWebviewController alloc] init];
    [self startWebviewAuth:embeddedWebviewController
                   factory:factory
              requestState:state
                   context:context
         completionHandler:completionHandler];
}

+ (void)startEmbeddedWebviewWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                                 factory:(MSIDOauth2Factory *)factory
                                                 webview:(WKWebView *)webview
                                                 context:(id<MSIDRequestContext>)context
                                       completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    NSString *state = [factory requestState];
    NSURL *startURL = [factory startURLFromConfiguration:configuration requestState:state];
    (void)startURL;
    (void)state;
    
    MSIDOAuth2EmbeddedWebviewController *embeddedWebviewController = [[MSIDOAuth2EmbeddedWebviewController alloc] init];
    [self startWebviewAuth:embeddedWebviewController
                   factory:factory
              requestState:state
                   context:context
         completionHandler:completionHandler];
}

+ (void)startSystemWebviewWebviewAuthWithConfiguration:(MSIDWebviewConfiguration *)configuration
                                               factory:(MSIDOauth2Factory *)factory
                                               context:(id<MSIDRequestContext>)context
                                     completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    NSString *state = [factory requestState];
    NSURL *startURL = [factory startURLFromConfiguration:configuration requestState:state];
    
    MSIDSystemWebviewController *systemWebviewController = [[MSIDSystemWebviewController alloc] initWithStartURL:startURL
                                                                                               callbackURLScheme:configuration.redirectUri
                                                                                                         context:context];

    [self startWebviewAuth:systemWebviewController
                   factory:factory
              requestState:state
                   context:context
         completionHandler:completionHandler];
}


+ (void)startWebviewAuth:(id<MSIDWebviewInteracting>)webviewController
                 factory:(MSIDOauth2Factory *)factory
            requestState:(NSString *)state
                 context:(id<MSIDRequestContext>)context
       completionHandler:(MSIDWebviewAuthCompletionHandler)completionHandler
{
    if (![self setCurrentWebSession:webviewController startURL:webviewController.startURL factory:factory requestState:state])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionAlreadyRunning, @"Only one interactive session is allowed at a time.", nil, nil, nil, context.correlationId, nil);
        
        completionHandler(nil, error);
        return;
    }
    
    void (^startCompletionBlock)(NSURL *, NSError *) = ^void(NSURL *callbackURL, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            [MSIDWebviewAuthorization clearCurrentWebAuthSessionAndFactory];
            return;
        }
        
        NSError *responseError = nil;
        
        MSIDWebOAuth2Response *response = [s_currentSession.factory responseWithURL:callbackURL
                                                                       requestState:s_currentSession.requestState
                                                                            context:nil
                                                                              error:&responseError];
        
        completionHandler(response, responseError);
        [MSIDWebviewAuthorization clearCurrentWebAuthSessionAndFactory];
    };
    
    if (![s_currentSession.webviewController startWithCompletionHandler:startCompletionBlock])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractiveSessionStartFailure, @"Interactive web session failed to start.", nil, nil, nil, context.correlationId, nil);
        
        completionHandler(nil, error);
    }
}


+ (BOOL)setCurrentWebSession:(id<MSIDWebviewInteracting>)newWebSession
                    startURL:(NSURL *)startURL
                     factory:(MSIDOauth2Factory *)factory
                requestState:(NSString *)state

{
    @synchronized([MSIDWebviewAuthorization class])
    {
        if (s_currentSession) {
            MSID_LOG_INFO(nil, @"Session is already running. Please wait or cancel the session before setting it new.");
            return NO;   
        }

        s_currentSession = [[MSIDWebviewSession alloc] initWithWebviewController:newWebSession
                                                                        startURL:startURL
                                                                         factory:factory
                                                                    requestState:state];
     
        return YES;
    }
    return NO;
}


+ (void)clearCurrentWebAuthSessionAndFactory
{
    @synchronized ([MSIDWebviewAuthorization class])
    {
        if (!s_currentSession)
        {
            // There's no error param because this isn't on a critical path. Just log that you are
            // trying to clear a session when there isn't one.
            MSID_LOG_INFO(nil, @"Trying to clear out an empty session");
        }
        
        s_currentSession = nil;
    }
}

+ (MSIDWebviewSession *)currentSession
{
    return s_currentSession;
}

+ (void)cancelCurrentSession
{
    @synchronized([MSIDWebviewAuthorization class])
    {
        if (s_currentSession)
        {
            [s_currentSession.webviewController cancel];
            s_currentSession = nil;
        }
    }
}


+ (BOOL)handleURLResponseForSystemWebviewController:(NSURL *)url;
{
#if TARGET_OS_IPHONE
    @synchronized([MSIDWebviewAuthorization class])
    {
        if (s_currentSession &&
            [(NSObject *)s_currentSession.webviewController isKindOfClass:MSIDSystemWebviewController.class])
        {
            return [((MSIDSystemWebviewController *)s_currentSession.webviewController) handleURLResponseForSafariViewController:url];
        }
    }
#endif
    return NO;
}


@end



