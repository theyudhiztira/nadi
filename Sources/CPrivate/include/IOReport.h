// Private IOReport API from /usr/lib/libIOReport.dylib, used for Energy Model watts.
#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

CF_IMPLICIT_BRIDGING_ENABLED

typedef struct IOReportSubscription *IOReportSubscriptionRef;

CFMutableDictionaryRef IOReportCopyChannelsInGroup(CFStringRef group, CFStringRef subgroup,
                                                   uint64_t a, uint64_t b, uint64_t c);
IOReportSubscriptionRef IOReportCreateSubscription(void *a, CFMutableDictionaryRef desiredChannels,
                                                   CFMutableDictionaryRef *subscribedChannels,
                                                   uint64_t channelID, CFTypeRef b);
CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef subscription,
                                      CFMutableDictionaryRef subscribedChannels, CFTypeRef a);
CFDictionaryRef IOReportCreateSamplesDelta(CFDictionaryRef previous, CFDictionaryRef current, CFTypeRef a);

CFStringRef IOReportChannelGetGroup(CFDictionaryRef channel);
CFStringRef IOReportChannelGetSubGroup(CFDictionaryRef channel);
CFStringRef IOReportChannelGetChannelName(CFDictionaryRef channel);
CFStringRef IOReportChannelGetUnitLabel(CFDictionaryRef channel);
int64_t IOReportSimpleGetIntegerValue(CFDictionaryRef channel, int32_t index);

CF_IMPLICIT_BRIDGING_DISABLED
