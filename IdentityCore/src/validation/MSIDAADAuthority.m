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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDAADAuthority.h"
#import "MSIDAadAuthorityResolver.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAADTenant.h"

@implementation MSIDAADAuthority

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError **)error
{
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        _url = [self.class normalizedAuthorityUrl:url context:context error:error];
        if (!_url) return nil;
        _tenant = [self.class tenantFromAuthorityUrl:self.url context:context error:error];
        _authorityCache = [MSIDAadAuthorityCache sharedInstance];
    }
    
    return self;
}

- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                           rawTenant:(NSString *)rawTenant
                             context:(nullable id<MSIDRequestContext>)context
                               error:(NSError **)error
{
    self = [self initWithURL:url context:context error:error];
    if (self)
    {
        if (rawTenant && [self.tenant isTenantless])
        {
            _url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", [_url msidHostWithPortIfNecessary], rawTenant]];
            
            if (![self.class isAuthorityFormatValid:_url context:context error:error]) return nil;
            
            _tenant = [self.class tenantFromAuthorityUrl:self.url context:context error:error];
        }
    }
    
    return self;
}

- (void)setAuthorityCache:(MSIDAadAuthorityCache *)authorityCache
{
    _authorityCache = authorityCache ? authorityCache : [MSIDAadAuthorityCache sharedInstance];
}

- (void)resolveAndValidate:(BOOL)validate
         userPrincipalName:(__unused NSString *)upn
                   context:(id<MSIDRequestContext>)context
           completionBlock:(MSIDAuthorityInfoBlock)completionBlock
{
    NSParameterAssert(completionBlock);
    
    id <MSIDAuthorityResolving> resolver = [MSIDAadAuthorityResolver new];
    [resolver resolveAuthority:self
             userPrincipalName:nil
                      validate:validate
                       context:context
               completionBlock:completionBlock];
}

- (NSURL *)networkUrlWithContext:(id<MSIDRequestContext>)context
{
    return [self.authorityCache networkUrlForAuthority:self.url context:context];
}

- (NSURL *)cacheUrlWithContext:(id<MSIDRequestContext>)context
{
    return [self.authorityCache cacheUrlForAuthority:self.url context:context];
}

- (NSArray<NSURL *> *)cacheAliases
{
    return [self.authorityCache cacheAliasesForAuthority:self.url];
}

- (nonnull NSURL *)universalAuthorityURL
{
//    AAD v1 endpoint supports only "common" path.
//    AAD v2 endpoint supports both common and organizations.
//    For legacy cache lookups we need to use common authority for compatibility purposes.
//    This method returns "common" authority if "organizations" authority was passed.
//    Otherwise, returns original authority.
    
    if (self.tenant.type == MSIDAADTenantTypeOrganizations)
    {
        __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:self.url rawTenant:MSIDAADTenantTypeCommonRawValue context:nil error:nil];
        
        return authority.url;
    }
    
    return self.url;
}

+ (BOOL)isAuthorityFormatValid:(NSURL *)url
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (![super isAuthorityFormatValid:url context:context error:error]) return NO;
    
    // TODO: ???
//    if ([url.host.lowercaseString isEqualToString:MSIDTrustedAuthority])
//    {
//        if (error)
//        {
//            __auto_type message = [NSString stringWithFormat:@"%@ has been deprecated. Use %@ instead.", MSIDTrustedAuthority, MSIDTrustedAuthorityWorldWide];
//            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, message, nil, nil, nil, context.correlationId, nil);
//        }
//        return NO;
//    }
    
    __auto_type tenant = [self tenantFromAuthorityUrl:url context:context error:error];
    
    if ([tenant.rawTenant isEqualToString:@"adfs"])
    {
        if (error)
        {
            __auto_type message = [NSString stringWithFormat:@"Trying to initialize AAD authority with ADFS authority url."];
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, message, nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    if ([tenant.rawTenant isEqualToString:@"tfp"])
    {
        if (error)
        {
            __auto_type message = [NSString stringWithFormat:@"Trying to initialize AAD authority with B2C authority url."];
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, message, nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return tenant != nil;
}

+ (instancetype)aadAuthorityWithAuthorityURL:(NSURL *)authorityUrl
                                   rawTenant:(NSString *)rawTenant
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError **)error;
{
    if (![self.class isAuthorityFormatValid:authorityUrl context:context error:error]) return nil;
    
    authorityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", [authorityUrl msidHostWithPortIfNecessary], rawTenant]];
    
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    return authority;
}

#pragma mark - Private

+ (NSURL *)normalizedAuthorityUrl:(NSURL *)url
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    if (![self isAuthorityFormatValid:url context:context error:error])
    {
        return nil;
    }
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", [url msidHostWithPortIfNecessary], url.pathComponents[1]]];
}

+ (MSIDAADTenant *)tenantFromAuthorityUrl:(NSURL *)url
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSArray *paths = url.pathComponents;
    
    if ([paths count] < 2)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"authority must have AAD tenant.", nil, nil, nil, context.correlationId, nil);
        }
        
        return nil;
    }
    
    NSString *rawTenant = [paths[1] lowercaseString];
    return [[MSIDAADTenant alloc] initWithRawTenant:rawTenant context:context error:error];
}

@end
