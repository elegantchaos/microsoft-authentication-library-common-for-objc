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

#import "NSData+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"
#import "NSData+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"

typedef unsigned char byte;

#define RANDOM_STRING_MAX_SIZE 1024

@implementation NSString (MSIDExtensions)

/// <summary>
/// Base64 URL decode a set of bytes.
/// </summary>
/// <remarks>
/// See RFC 4648, Section 5 plus switch characters 62 and 63 and no padding.
/// For a good overview of Base64 encoding, see http://en.wikipedia.org/wiki/Base64
/// This SDK will use rfc7515 and decode using padding. See https://tools.ietf.org/html/rfc7515#appendix-C
/// </remarks>
+ (NSData *)msidBase64UrlDecodeData:(NSString *)encodedString
{
    NSUInteger paddedLength = encodedString.length + (4 - (encodedString.length % 4));
    NSString *paddedString = [encodedString stringByPaddingToLength:paddedLength withString:@"=" startingAtIndex:0];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:paddedString options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return data;
}


// Base64 URL encodes a string
- (NSString *)msidBase64UrlEncode
{
    NSData *decodedData = [self dataUsingEncoding:NSUTF8StringEncoding];
    
    return [decodedData msidBase64UrlEncodedString];
}


- (NSString *)msidBase64UrlDecode
{
    NSData *data = [self.class msidBase64UrlDecodeData:self];
    if (!data) return nil;
    
    char lastByte;
    [data getBytes:&lastByte range:NSMakeRange([data length] - 1, 1)];
    
    // Data here can be null terminated or not
    // - stringWithUTF8String expects a null-terminated c array of bytes in UTF8 encoding
    //   https://developer.apple.com/documentation/foundation/nsstring/1497379-stringwithutf8string
    // - initWithData expects UTF16 which cannot be stored in a null-terminated byte string.
    //   https://developer.apple.com/documentation/foundation/nsstring/1416374-initwithdata?language=objc
    //
    // We need to check for null terminated string data by looking at the last bit.
    // If we call initWithData on null-terminated, we get back a nil string.
    if (lastByte == 0x0) {
        // If null terminated
        return [NSString stringWithUTF8String:[data bytes]];
    } else {
        // string is not null-terminated
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
}


+ (BOOL)msidIsStringNilOrBlank:(NSString *)string
{
    if (!string || [string isKindOfClass:[NSNull class]] || !string.length)
    {
        return YES;
    }
    
    static NSCharacterSet *nonWhiteCharSet;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        nonWhiteCharSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    });
    
    return [string rangeOfCharacterFromSet:nonWhiteCharSet].location == NSNotFound;
}


- (NSString *)msidTrimmedString
{
    //The white characters set is cached by the system:
    NSCharacterSet* set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [self stringByTrimmingCharactersInSet:set];
}


- (NSString *)msidWwwFormUrlDecode
{
    // Two step decode: first replace + with a space, then percent unescape
    CFMutableStringRef decodedString = CFStringCreateMutableCopy( NULL, 0, (__bridge CFStringRef)self );
    CFStringFindAndReplace( decodedString, CFSTR("+"), CFSTR(" "), CFRangeMake( 0, CFStringGetLength( decodedString ) ), kCFCompareCaseInsensitive );
    
    CFStringRef unescapedString = CFURLCreateStringByReplacingPercentEscapes( NULL,                    // Allocator
                                                                                          decodedString,           // Original string
                                                                                          CFSTR("")); // Encoding
    CFRelease( decodedString );
    
    return CFBridgingRelease(unescapedString);
}


- (NSString *)msidWwwFormUrlEncode
{
    static NSCharacterSet* set = nil;
 
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSMutableCharacterSet *allowedSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [allowedSet addCharactersInString:@" "];
        [allowedSet removeCharactersInString:@"!$&'()*+,/:;=?@"];
        
        set = allowedSet;
    });
    
    NSString *encodedString = [self stringByAddingPercentEncodingWithAllowedCharacters:set];
    return [encodedString stringByReplacingOccurrencesOfString:@" " withString:@"+"];
}


- (NSString *)msidTokenHash
{
    NSString *returnStr = [[[self msidData] msidSHA256] msidHexString];
    
    // 7 characters is sufficient to differentiate tokens in the log, otherwise the hashes start making log lines hard to read
    return [returnStr substringToIndex:7];
}

+ (NSString *)msidRandomUrlSafeStringOfByteSize:(NSUInteger)size
{
    if (size > RANDOM_STRING_MAX_SIZE)
    {
        return nil;
    }
    
    NSMutableData *data = [NSMutableData dataWithLength:size];
    int result = SecRandomCopyBytes(kSecRandomDefault, data.length, data.mutableBytes);
    
    if (result != 0)
    {
        return nil;
    }
    
    return [data msidBase64UrlEncodedString];
}


+ (NSString *)msidHexStringFromData:(NSData *)data
{
    const unsigned char *charBytes = (const unsigned char *)data.bytes;
    
    if (!charBytes) return nil;
    NSUInteger dataLength = data.length;
    NSMutableString *result = [NSMutableString stringWithCapacity:dataLength];
    
    for (int i = 0; i < dataLength; i++)
    {
        [result appendFormat:@"%02x", charBytes[i]];
    }
    
    return result;
}


/// <summary>
/// Base64 URL encode a set of bytes.
/// </summary>
/// <remarks>
/// See RFC 4648, Section 5 plus switch characters 62 and 63 and no padding.
/// For a good overview of Base64 encoding, see http://en.wikipedia.org/wiki/Base64
/// This SDK will use rfc7515 and encode without using padding.
/// See https://tools.ietf.org/html/rfc7515#appendix-C
/// </remarks>
+ (NSString *)msidBase64UrlEncodedStringFromData:(NSData *)data
{
    return [[data base64EncodedStringWithOptions:0] componentsSeparatedByString:@"="].firstObject;
}


/*! Generate a www-form-urlencoded string of random data */
+ (NSString *)msidUrlFormEncodedStringFromDictionary:(NSDictionary *)dict
{
    __block NSMutableString *encodedString = nil;
    
    [dict enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL __unused *stop)
     {
         if ([NSString msidIsStringNilOrBlank:key])
         {
             return;
         }
         
         NSString *encodedKey = [[key msidTrimmedString] msidWwwFormUrlEncode];
         
         if (!encodedString)
         {
             encodedString = [NSMutableString new];
         }
         else
         {
             [encodedString appendString:@"&"];
         }
         
         [encodedString appendString:encodedKey];
         
         NSString *v = [value description];
         if ([value isKindOfClass:NSUUID.class])
         {
             v = ((NSUUID *)value).UUIDString;
         }
         NSString *encodedValue = [[v msidTrimmedString] msidWwwFormUrlEncode];
         
         if (![NSString msidIsStringNilOrBlank:encodedValue])
         {
             [encodedString appendFormat:@"=%@", encodedValue];
         }
         
     }];
    return encodedString;
}


- (BOOL)msidIsEquivalentWithAnyAlias:(NSArray<NSString *> *)aliases
{
    if (!aliases)
    {
        return NO;
    }

    for (NSString *alias in aliases)
    {
        if ([self caseInsensitiveCompare:alias] == NSOrderedSame)
        {
            return YES;
        }
    }
    return NO;
}


+ (NSString *)msidStringFromOrderedSet:(NSOrderedSet *)set
{
    NSInteger cSet = set.count;
    if (cSet == 0)
    {
        return @"";
    }
    
    return [[set array] componentsJoinedByString:@" "];
}


- (NSURL *)msidUrl
{
    return [[NSURL alloc] initWithString:self];
}

- (NSData *)msidData
{
    return [self dataUsingEncoding:NSUTF8StringEncoding];
}


- (NSOrderedSet<NSString *> *)msidScopeSet
{
    return [NSOrderedSet msidOrderedSetFromString:self];
}

@end
