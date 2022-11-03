create table JobRunner.Config (
	JobRunnerName sysname not null,
	MaxJobRunnerExecTimeSeconds int not null,
	NumRowsPerBatch int not null,
	DeadlockPriority int not null,
	LockTimeoutSeconds int not null,
	MaxSyncSecondaryCommitLatencySeconds int not null,
	MaxRedoQueueSize int not null,
	MaxProcedureExecTimeViolationCount int not null,
	MaxProcedureExecTimeMilliseconds int not null,

	constraint UC_JobRunner_JobRunnerName
	primary key clustered (JobRunnerName),

	constraint JobRunner_Config_Has_Valid_DeadlockPriority_CK
	check (DeadlockPriority >= -10 and DeadlockPriority <= 10),

	constraint JobRunner_Config_Has_Valid_LockTimeoutSeconds_CK
	check (
		LockTimeoutSeconds >= -1 and LockTimeoutSeconds <= 10
		or LockTimeoutSeconds = 15
		or LockTimeoutSeconds = 30
		or LockTimeoutSeconds = 60
		or LockTimeoutSeconds = 120
	)
);

go
