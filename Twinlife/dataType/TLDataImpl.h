/*
 *  Copyright (c) 2014-2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLData.h"

//
// Interface(): TLData
//

@class DDXMLElement;
@class NSXMLElement;

@interface TLData ()

@property NSString *value;

- (DDXMLElement *)toXml;

- (void)parse:(NSXMLElement *)xml;

@end
