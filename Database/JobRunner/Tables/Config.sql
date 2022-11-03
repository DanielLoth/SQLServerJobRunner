create table JobRunner.Config (
	JobRunnerName sysname not null,
	TargetJobRunnerExecTimeMilliseconds bigint not null,
	NumRowsPerBatch int not null,
	DeadlockPriority int not null,
	LockTimeoutMilliseconds int not null,
	MaxCommitLatencyMilliseconds bigint not null,
	MaxRedoQueueSize bigint not null,
	MaxProcedureExecTimeViolationCount int not null,
	MaxProcedureExecTimeMilliseconds bigint not null,
	BatchSleepTime char(12) not null,

	constraint UC_JobRunner_JobRunnerName
	primary key clustered (JobRunnerName),

	constraint JobRunner_Config_Has_Valid_DeadlockPriority_CK
	check (DeadlockPriority >= -10 and DeadlockPriority <= 10),

	constraint JobRunner_Config_Has_Valid_LockTimeoutMilliseconds_CK
	check (
		LockTimeoutMilliseconds = -1
		or LockTimeoutMilliseconds = 0
		or LockTimeoutMilliseconds = 1000
		or LockTimeoutMilliseconds = 2000
		or LockTimeoutMilliseconds = 3000
		or LockTimeoutMilliseconds = 4000
		or LockTimeoutMilliseconds = 5000
		or LockTimeoutMilliseconds = 6000
		or LockTimeoutMilliseconds = 7000
		or LockTimeoutMilliseconds = 8000
		or LockTimeoutMilliseconds = 9000
		or LockTimeoutMilliseconds = 10000
		or LockTimeoutMilliseconds = 15000
		or LockTimeoutMilliseconds = 30000
		or LockTimeoutMilliseconds = 60000
		or LockTimeoutMilliseconds = 120000
	),

	constraint JobRunner_Config_Has_Acceptable_NumRowsPerBatch_CK
	check (NumRowsPerBatch >= 1 and NumRowsPerBatch <= 5000),

	/*
	****************************************
	Examples:
	  00:00:00.000 - 0 milliseconds
	  00:00:00.500 - 500 milliseconds
	  00:00:02.000 - 2 seconds
	  00:00:30.000 - 30 seconds
	  00:01:00.000 - 1 minute
	****************************************
	*/
	constraint JobRunner_Config_Has_Valid_BatchSleepTime_CK
	check (BatchSleepTime like '[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]')
);

go
