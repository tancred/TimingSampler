#import <Foundation/Foundation.h>
#import <stdint.h>
#import <mach/mach_time.h>

static uint64_t GetTimestamp();
static uint64_t TimestampDeltaInNanoseconds(uint64_t delta);


@interface TimingSample : NSObject
@property (copy) NSString *tag;
@property uint64_t delta;
@end

@interface TimingSampler : NSObject
@property (nonatomic,copy) NSString *tag;
@property (nonatomic) uint64_t timestamp;
- (id)initWithTag:(NSString *)tag;
- (void)reset;
- (TimingSample *)sample;
- (void)report;
@end
extern NSString *TimingSampleReportNotificationName;


static void try_timestamp_functions();
static void try_timing_sampler();
static void try_timing_sampler_reporter();


int main() {
	@autoreleasepool {
		try_timestamp_functions();
		try_timing_sampler();
		try_timing_sampler_reporter();
	}
	return 0;
}


static void try_timestamp_functions() {
	uint64_t samples[17];
	int numTries = sizeof(samples) / sizeof(uint64_t);

	NSLog(@"Call mach_absolute_time");
	for (int i=0; i<numTries; i++) {
		uint64_t delta = GetTimestamp();
		(void)mach_absolute_time();
		samples[i] = GetTimestamp() - delta;
	}
	for (int i=0; i<numTries; i++) { NSLog(@"  %llu ns", TimestampDeltaInNanoseconds(samples[i])); }

	NSLog(@"Allocate NSDate");
	for (int i=0; i<numTries; i++) {
		uint64_t delta = GetTimestamp();
		NSDate *d = [[NSDate alloc] init];
		d = nil;
		samples[i] = GetTimestamp() - delta;
	}
	for (int i=0; i<numTries; i++) { NSLog(@"  %llu ns", TimestampDeltaInNanoseconds(samples[i])); }

	NSLog(@"Allocate with pool");
	for (int i=0; i<numTries; i++) {
		uint64_t delta = GetTimestamp();
		@autoreleasepool {
			[NSDate date];
		}
		samples[i] = GetTimestamp() - delta;
	}
	for (int i=0; i<numTries; i++) { NSLog(@"  %llu ns", TimestampDeltaInNanoseconds(samples[i])); }
}


static void try_timing_sampler() {
	uint64_t samples[17];
	int numTries = sizeof(samples) / sizeof(uint64_t);

	NSLog(@"Call mach_absolute_time");
	TimingSampler *sampler = [[TimingSampler alloc] initWithTag:@"mach_absolute_time"];
	for (int i=0; i<numTries; i++) {
		(void)mach_absolute_time();
		TimingSample *sample = [sampler sample];
		samples[i] = sample.delta;
	}
	for (int i=0; i<numTries; i++) { NSLog(@"  %llu ns", samples[i]); }

	NSLog(@"Allocate NSDate");
	sampler = [[TimingSampler alloc] initWithTag:@"Allocate NSDate"];
	for (int i=0; i<numTries; i++) {
		NSDate *d = [[NSDate alloc] init];
		d = nil;
		TimingSample *sample = [sampler sample];
		samples[i] = sample.delta;
	}
	for (int i=0; i<numTries; i++) { NSLog(@"  %llu ns", samples[i]); }

	NSLog(@"Allocate with pool");
	sampler = [[TimingSampler alloc] initWithTag:@"Allocate with pool"];
	for (int i=0; i<numTries; i++) {
		@autoreleasepool {
			[NSDate date];
		}
		TimingSample *sample = [sampler sample];
		samples[i] = sample.delta;
	}
	for (int i=0; i<numTries; i++) { NSLog(@"  %llu ns", samples[i]); }
}


static void try_timing_sampler_reporter() {
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	//queue.maxConcurrentOperationCount = 1;

	id observer = [[NSNotificationCenter defaultCenter] addObserverForName:TimingSampleReportNotificationName object:nil queue:queue usingBlock:^(NSNotification *note) {
		TimingSample *sample = [note object];
		NSLog(@"%@: %llu ns ≈ %llu us ≈ %llu ms", sample.tag, sample.delta, sample.delta / 1000, sample.delta / 1000000);
	}];

	int numTries = 17;

	TimingSampler *sampler = [[TimingSampler alloc] initWithTag:@"mach_absolute_time"];
	for (int i=0; i<numTries; i++) {
		(void)mach_absolute_time();
		[sampler report];
	}

	sampler = [[TimingSampler alloc] initWithTag:@"NSDate-alloc-release"];
	for (int i=0; i<numTries; i++) {
		NSDate *d = [[NSDate alloc] init];
		d = nil;
		[sampler report];
	}

	sampler = [[TimingSampler alloc] initWithTag:@"NSDate-alloc-autorelease-recreate-pool"];
	for (int i=0; i<numTries; i++) {
		@autoreleasepool {
			[NSDate date];
		}
		[sampler report];
	}

	[queue waitUntilAllOperationsAreFinished];
	queue = nil;

	[[NSNotificationCenter defaultCenter] removeObserver:observer];
}


static uint64_t GetTimestamp() {
	return mach_absolute_time();
}

static uint64_t TimestampDeltaInNanoseconds(uint64_t delta) {
	static mach_timebase_info_data_t timebase;
	static dispatch_once_t pred = 0;
	dispatch_once(&pred, ^{
		kern_return_t r = mach_timebase_info(&timebase);
		if (r != err_none) {
			fprintf(stderr, "ERROR: mach_timebase_info() failed\n");
			timebase.numer = 0;
			timebase.denom = 0;
		}
	});
	return delta * timebase.numer / timebase.denom;
}


@implementation TimingSampler

- (id)initWithTag:(NSString *)aTag {
	if (!(self = [super init])) return nil;
	self.tag = aTag;
	self.timestamp = GetTimestamp();
	return self;
}

- (void)reset {
	self.timestamp = GetTimestamp();
}

- (TimingSample *)sample {
	uint64_t x = GetTimestamp();
	TimingSample *sample = [[TimingSample alloc] init];
	sample.tag = self.tag;
	sample.delta = TimestampDeltaInNanoseconds(x - self.timestamp);
	self.timestamp = x;
	return sample;
}

- (void)report {
	[[NSNotificationCenter defaultCenter] postNotificationName:TimingSampleReportNotificationName object:[self sample]];
}

@end

NSString *TimingSampleReportNotificationName = @"TimingSampleReportNotificationName";


@implementation TimingSample
@end
