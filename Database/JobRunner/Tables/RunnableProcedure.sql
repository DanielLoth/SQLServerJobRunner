create table JobRunner.RunnableProcedure (
	JobRunnerName sysname not null,
	SchemaName sysname not null,
	ProcedureName sysname not null,
	IsEnabled bit not null,
	LastExecutionNumber bigint not null default 0,
	LastExecutedDtmUtc datetime2 not null constraint RunnableProcedure_LastExecutedDtmUtc_DF default '0001-01-01',
	LastElapsedMilliseconds bigint not null default 0,
	LastExitCode int not null default 0,
	ExecCount bigint not null default 0,
	ExecTimeViolationCount int not null default 0,
	ErrorNumber int not null default 0,
	ErrorMessage nvarchar(4000) not null default N'',
	ErrorLine int not null default 0,
	ErrorProcedure sysname not null default N'',
	ErrorSeverity int not null default 0,
	ErrorState int not null default 0,
	GeneratedProcedureWrapperSql nvarchar(4000) not null default '',

	constraint UC_JobRunner_RunnableProcedure_PK
	primary key clustered (JobRunnerName, SchemaName, ProcedureName),

	constraint U__JobRunner_RunnableProcedure_SchemaName_ProcedureName_AK
	unique (SchemaName, ProcedureName)
);

go
