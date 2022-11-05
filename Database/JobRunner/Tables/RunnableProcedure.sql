create table JobRunner.RunnableProcedure (
	JobRunnerName sysname not null,
	SchemaName sysname not null,
	ProcedureName sysname not null,
	IsEnabled bit not null,
	HasIndicatedDone bit not null
		constraint JobRunner_RunnableProcedure_HasIndicatedDone_DF default 0,
	LastExecutionNumber bigint not null
		constraint JobRunner_RunnableProcedure_LastExecutionNumber_DF default 0,
	LastExecutedDtmUtc datetime2 not null
		constraint JobRunner_RunnableProcedure_LastExecutedDtmUtc_DF default '0001-01-01',
	LastElapsedMilliseconds bigint not null
		constraint JobRunner_RunnableProcedure_LastElapsedMilliseconds_DF default 0,
	LastExitCode int not null
		constraint JobRunner_RunnableProcedure_LastExitCode_DF default 0,
	ExecCount bigint not null
		constraint JobRunner_RunnableProcedure_ExecCount_DF default 0,
	ExecTimeViolationCount int not null
		constraint JobRunner_RunnableProcedure_ExecTimeViolationCount_DF default 0,
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
