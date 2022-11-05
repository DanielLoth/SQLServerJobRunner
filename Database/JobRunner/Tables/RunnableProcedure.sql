create table JobRunner.RunnableProcedure (
	JobRunnerName sysname not null,
	SchemaName sysname not null,
	ProcedureName sysname not null,
	IsEnabled bit not null,
	HasIndicatedDone bit not null
		constraint JobRunner_RunnableProcedure_HasIndicatedDone_DF default 0,
	LastElapsedMilliseconds bigint not null
		constraint JobRunner_RunnableProcedure_LastElapsedMilliseconds_DF default 0,
	AttemptedExecutionCount bigint not null
		constraint JobRunner_RunnableProcedure_AttemptedExecutionCount_DF default 0,
	SuccessfulExecutionCount bigint not null
		constraint JobRunner_RunnableProcedure_SuccessfulExecutionCount_DF default 0,
	FailedExecutionCount bigint not null
		constraint JobRunner_RunnableProcedure_FailedExecutionCount_DF default 0,
	ExecutionTimeViolationCount int not null
		constraint JobRunner_RunnableProcedure_ExecutionTimeViolationCount_DF default 0,
	ErrorNumber int not null
		constraint JobRunner_RunnableProcedure_ErrorNumber_DF default 0,
	ErrorMessage nvarchar(4000) not null
		constraint JobRunner_RunnableProcedure_ErrorMessage_DF default N'',
	ErrorLine int not null
		constraint JobRunner_RunnableProcedure_ErrorLine_DF default 0,
	ErrorProcedure sysname not null
		constraint JobRunner_RunnableProcedure_ErrorProcedure_DF default N'',
	ErrorSeverity int not null
		constraint JobRunner_RunnableProcedure_ErrorSeverity_DF default 0,
	ErrorState int not null
		constraint JobRunner_RunnableProcedure_ErrorState_DF default 0,
	FailedWhileCreatingWrapperProcedure bit not null
		constraint JobRunner_RunnableProcedure_FailedWhileCreatingWrapperProcedure_DF default 0,
	DoneDtmUtc datetime2 not null
		constraint JobRunner_RunnableProcedure_DoneDtmUtc_DF default '9999-12-31',
	LastExecutedDtmUtc datetime2 not null
		constraint JobRunner_RunnableProcedure_LastExecutedDtmUtc_DF default '0001-01-01',
	GeneratedProcedureWrapperSql nvarchar(4000) not null
		constraint JobRunner_RunnableProcedure_GeneratedProcedureWrapperSql_DF default N'',

	constraint UC_JobRunner_RunnableProcedure_PK
	primary key clustered (JobRunnerName, SchemaName, ProcedureName),

	/*
	Just here to ensure that any given stored procedure will be executed
	by no more than one job runner.
	Not strictly necessary though.
	*/
	constraint U__JobRunner_RunnableProcedure_SchemaName_ProcedureName_AK
	unique (SchemaName, ProcedureName)
);

go
