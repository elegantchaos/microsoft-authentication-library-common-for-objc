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

#import "MSIDAssymetricKeyPair.h"

NS_ASSUME_NONNULL_BEGIN

// TODO: For CodeReviewers: what pattern do you desire?
// - we can make generating an stkJwk a method on MSIDAssymetricKeyPair (not sure about how you feel about adding 'bloat' to the MSIDAssymetricKeyPair class, so added as an extension method here)
// - we can make an MSIDAssymetricKeyPairWithStkJwk that inherits from MSIDAssymetricKeyPair based on the existing example of MSIDAssymetricKeyPairWithCert
// - we can use generics, so for example to generateKeyPairForAttributes could generate from anything that inherits from MSIDAssymetricKeyPair
// - we can require conversion from MSIDAssymetricKeyPair to MSIDAssymetricKeyPairWithStkJwk
@interface MSIDAssymetricKeyPair (StkJwkExtensions)

- (nullable NSString *)generateStkJwk;

@end

NS_ASSUME_NONNULL_END
