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

#import <Foundation/Foundation.h>
#import "MSIDAuthorityCacheRecord.h"
#import "MSIDCache.h"

@interface MSIDAadAuthorityCache : MSIDCache

+ (MSIDAadAuthorityCache *)sharedInstance;

- (NSURL *)networkUrlForAuthority:(NSURL *)authority
                          context:(id<MSIDRequestContext>)context;

- (NSURL *)cacheUrlForAuthority:(NSURL *)authority
                        context:(id<MSIDRequestContext>)context;

- (NSString *)cacheEnvironmentForEnvironment:(NSString *)environment
                                     context:(id<MSIDRequestContext>)context;

/*!
 Returns an array of authority URLs for the provided URL, in the order that cache lookups
 should be attempted.
 
 @param  authority   The authority URL the developer provided for the authority context
 */
- (NSArray<NSURL *> *)cacheAliasesForAuthority:(NSURL *)authority;

- (NSArray<NSString *> *)cacheAliasesForEnvironment:(NSString *)environment;
- (NSArray<NSURL *> *)cacheAliasesForAuthorities:(NSArray<NSURL *> *)authorities;

- (void)processMetadata:(NSArray<NSDictionary *> *)metadata
   openIdConfigEndpoint:(NSURL *)openIdConfigEndpoint
              authority:(NSURL *)authority
                context:(id<MSIDRequestContext>)context
             completion:(void (^)(BOOL result, NSError *error))completion;

- (void)addInvalidRecord:(NSURL *)authority
              oauthError:(NSError *)oauthError
                 context:(id<MSIDRequestContext>)context;

@end
