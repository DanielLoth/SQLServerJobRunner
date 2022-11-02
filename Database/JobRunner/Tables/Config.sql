create table JobRunner.Config (
	RowNumber int not null constraint JobRunner_Config_RowNumber_DF default 1,
	MaxJobRunnerExecTimeSeconds int not null,
	NumRowsPerBatch int not null,
	DeadlockPriority int not null,
	LockTimeoutSeconds int not null,
	MaxSyncSecondaryCommitLatencySeconds int not null,
	MaxRedoQueueSize int not null,
	MaxProcedureExecTimeViolationCount int not null,
	MaxProcedureExecTimeMilliseconds int not null,

	constraint JobRunner_Config_Has_SingleRow_CK check (RowNumber = 1),

	constraint JobRunner_Config_Has_Valid_DeadlockPriority_CK
	check (DeadlockPriority between -10 and 10),

	constraint JobRunner_Config_Has_Valid_LockTimeoutSeconds_CK
	check (LockTimeoutSeconds between -1 and 10 or LockTimeoutSeconds in (15, 30, 60, 120))
);

go
