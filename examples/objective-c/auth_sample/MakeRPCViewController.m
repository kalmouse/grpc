/*
 *
 * Copyright 2015 gRPC authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "MakeRPCViewController.h"

#import <AuthTestService/AuthSample.pbrpc.h>
#import <Google/SignIn.h>
#import <ProtoRPC/ProtoRPC.h>

NSString * const kTestScope = @"https://www.googleapis.com/auth/xapi.zoo";

static NSString * const kTestHostAddress = @"grpc-test.sandbox.googleapis.com";

// Category for RPC errors to create the descriptions as we want them to appear on our view.
@interface NSError (AuthSample)
- (NSString *)UIDescription;
@end

@implementation NSError (AuthSample)
- (NSString *)UIDescription {
  if (self.code == GRPCErrorCodeUnauthenticated) {
    // Authentication error. OAuth2 specifies we'll receive a challenge header.
    // |userInfo[kGRPCHeadersKey]| is the dictionary of response headers.
    NSString *challengeHeader = self.userInfo[kGRPCHeadersKey][@"www-authenticate"] ?: @"";
    return [@"Invalid credentials. Server challenge:\n" stringByAppendingString:challengeHeader];
  } else {
    // Any other error.
    return [NSString stringWithFormat:@"Unexpected RPC error %li: %@",
            (long)self.code, self.localizedDescription];
  }
}
@end

@implementation MakeRPCViewController

- (void)viewWillAppear:(BOOL)animated {

  // Create a service client and a proto request as usual.
  AUTHTestService *client = [[AUTHTestService alloc] initWithHost:kTestHostAddress];

  AUTHRequest *request = [AUTHRequest message];
  request.fillUsername = YES;
  request.fillOauthScope = YES;

  // Create a not-yet-started RPC. We want to set the request headers on this object before starting
  // it.
  ProtoRPC *call =
      [client RPCToUnaryCallWithRequest:request handler:^(AUTHResponse *response, NSError *error) {
        if (response) {
          // This test server responds with the email and scope of the access token it receives.
          self.mainLabel.text = [NSString stringWithFormat:@"Used scope: %@ on behalf of user %@",
                                 response.oauthScope, response.username];

        } else {
          self.mainLabel.text = error.UIDescription;
        }
      }];

  // Set the access token to be used.
  NSString *accessToken = GIDSignIn.sharedInstance.currentUser.authentication.accessToken;
  call.requestHeaders[@"Authorization"] = [@"Bearer " stringByAppendingString:accessToken];

  // Start the RPC.
  [call start];

  self.mainLabel.text = @"Waiting for RPC to complete...";
}

@end
