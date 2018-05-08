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

#import "MSIDHelpers.h"
#import "MSIDContants.h"
#import "MSIDDeviceId.h"

@implementation MSIDHelpers

+ (NSInteger)msidIntegerValue:(id)value
{
    if (value && [value respondsToSelector:@selector(integerValue)])
    {
        return [value integerValue];
    }
    
    return 0;
}

+ (NSString *)normalizeUserId:(NSString *)userId
{
    if (!userId)
    {
        return nil;
    }
    NSString *normalized = [userId msidTrimmedString].lowercaseString;

    return normalized.length ? normalized : nil;
}

+ (NSString *)msidAddClientVersionToURLString:(NSString *)urlString;
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url)
    {
        return nil;
    }
    
    // Pull apart the request URL and add the ADAL Client version to the query parameters
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    if (!components)
    {
        return nil;
    }
    
    NSString *query = [components percentEncodedQuery];
    // Don't bother adding it if it's already there
    if (query && [query containsString:MSID_VERSION_KEY])
    {
        return [url absoluteString];
    }
    
    NSString *clientVersionString = [NSString stringWithFormat:@"&%@=%@", MSID_VERSION_KEY, MSIDDeviceId.deviceId[MSID_VERSION_KEY]];
    if (query)
    {
        [components setPercentEncodedQuery:[query stringByAppendingString:clientVersionString]];
    }
    else
    {
        [components setPercentEncodedQuery:clientVersionString];
    }
    
    return [[components URL] absoluteString];
}

@end
