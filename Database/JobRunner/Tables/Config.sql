create table JobRunner.Config (
	JobRunnerName sysname not null,
	TargetJobRunnerExecTimeMilliseconds bigint not null,
	BatchSize int not null,
	DeadlockPriority int not null,
	LockTimeoutMilliseconds int not null,
	MaxCommitLatencyMilliseconds bigint not null,
	MaxRedoQueueSize bigint not null,
	MaxProcedureExecTimeViolationCount int not null,
	MaxProcedureExecTimeMilliseconds bigint not null,
	BatchSleepMilliseconds int not null default 500,

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

	constraint JobRunner_Config_Has_Acceptable_BatchSize_CK
	check (BatchSize >= 1 and BatchSize <= 5000),

	constraint JobRunner_Config_Has_Acceptable_BatchSleepMilliseconds_CK
	check (BatchSleepMilliseconds >= 0 and BatchSleepMilliseconds <= 10000)
);

go
