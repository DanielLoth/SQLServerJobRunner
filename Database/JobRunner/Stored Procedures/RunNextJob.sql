create procedure JobRunner.RunNextJob
	@JobRunnerName sysname,
	@BatchSize int,
	@DeadlockPriority int,
	@LockTimeoutMilliseconds int,
	@MaxProcedureExecTimeViolationCount int,
	@MaxProcedureExecTimeMilliseconds bigint,
	@FoundJobToExecute bit output
as

set nocount, xact_abort on;
set deadlock_priority low;
set lock_timeout -1;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;

declare
	@SchemaName sysname,
	@ProcedureName sysname,
	@CreateOrAlterProcedureQuery nvarchar(4000),
	@StartDtmUtc datetime2(7),
	@EndDtmUtc datetime2(7),
	@ElapsedMilliseconds bigint,
	@ReturnCode int,
	@ErrorNumber int,
	@ErrorMessage nvarchar(4000),
	@ErrorLine int,
	@ErrorProcedure sysname,
	@ErrorSeverity int,
	@ErrorState int,
	@Done bit = 0;

set @FoundJobToExecute = 0;

select top 1
	@FoundJobToExecute = 1,
	@SchemaName = SchemaName,
	@ProcedureName = ProcedureName,
	@CreateOrAlterProcedureQuery = GeneratedProcedureWrapperSql
from JobRunner.RunnableProcedure
where
	JobRunnerName = @JobRunnerName and
	IsEnabled = 1 and
	HasIndicatedDone = 0
order by LastExecutionNumber;

if @FoundJobToExecute = 0 return 0;


begin try
	exec sp_executesql @CreateOrAlterProcedureQuery;
end try
begin catch

	select
		@ErrorNumber = error_number(),
		@ErrorMessage = error_message(),
		@ErrorLine = error_line(),
		@ErrorProcedure = error_procedure(),
		@ErrorSeverity = error_severity(),
		@ErrorState = error_state();

	if @@trancount != 0 rollback;

	update JobRunner.RunnableProcedure
	set
		IsEnabled = 0,
		ErrorNumber = @ErrorNumber,
		ErrorMessage = @ErrorMessage,
		ErrorLine = @ErrorLine,
		ErrorProcedure = @ErrorProcedure,
		ErrorSeverity = @ErrorSeverity,
		ErrorState = @ErrorState
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName;

end catch


set deadlock_priority @DeadlockPriority;

if @LockTimeoutMilliseconds = -1 set lock_timeout -1; /* Wait forever */
else if @LockTimeoutMilliseconds = 0 set lock_timeout 0; /* Don't wait at all */
else if @LockTimeoutMilliseconds = 1000 set lock_timeout 1000;
else if @LockTimeoutMilliseconds = 2000 set lock_timeout 2000;
else if @LockTimeoutMilliseconds = 3000 set lock_timeout 3000;
else if @LockTimeoutMilliseconds = 4000 set lock_timeout 4000;
else if @LockTimeoutMilliseconds = 5000 set lock_timeout 5000;
else if @LockTimeoutMilliseconds = 6000 set lock_timeout 6000;
else if @LockTimeoutMilliseconds = 7000 set lock_timeout 7000;
else if @LockTimeoutMilliseconds = 8000 set lock_timeout 8000;
else if @LockTimeoutMilliseconds = 9000 set lock_timeout 9000;
else if @LockTimeoutMilliseconds = 10000 set lock_timeout 10000;
else if @LockTimeoutMilliseconds = 15000 set lock_timeout 15000;
else if @LockTimeoutMilliseconds = 30000 set lock_timeout 30000;
else if @LockTimeoutMilliseconds = 60000 set lock_timeout 60000;
else if @LockTimeoutMilliseconds = 120000 set lock_timeout 120000;


begin try
	if @@trancount != 0 throw 50000, N'Open transaction detected before invoking job procedure', 1;

	set @StartDtmUtc = getutcdate();

	exec @ReturnCode = [#JobRunnerWrapper] @BatchSize = @BatchSize, @Done = @Done output;
	
	set @EndDtmUtc = getutcdate();
	set @Done = isnull(@Done, 0);

	if @@trancount != 0 throw 50000, N'Open transaction detected after invoking job procedure. Jobs must commit or rollback all transactions.', 1;

	set deadlock_priority low;
	set lock_timeout -1;
end try
begin catch

	select
		@ErrorNumber = error_number(),
		@ErrorMessage = error_message(),
		@ErrorLine = error_line(),
		@ErrorProcedure = error_procedure(),
		@ErrorSeverity = error_severity(),
		@ErrorState = error_state();

	if @@trancount != 0 rollback;

	set deadlock_priority low;
	set lock_timeout -1;

	update JobRunner.RunnableProcedure
	set
		IsEnabled = 0,
		ErrorNumber = @ErrorNumber,
		ErrorMessage = @ErrorMessage,
		ErrorLine = @ErrorLine,
		ErrorProcedure = @ErrorProcedure,
		ErrorSeverity = @ErrorSeverity,
		ErrorState = @ErrorState
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName;

end catch


set @ElapsedMilliseconds = datediff(millisecond, @StartDtmUtc, @EndDtmUtc);



begin try
	begin transaction;

	update JobRunner.RunnableProcedure
	set
		LastExecutionNumber = next value for ExecutionNumber,
		LastExecutedDtmUtc = @StartDtmUtc,
		LastElapsedMilliseconds = @ElapsedMilliseconds,
		LastExitCode = @ReturnCode,
		ExecCount = ExecCount + 1,
		ErrorNumber = 0,
		ErrorMessage = N'',
		ErrorLine = 0,
		ErrorProcedure = N'',
		ErrorSeverity = 0,
		ErrorState = 0,
		HasIndicatedDone = @Done
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName;

	update JobRunner.RunnableProcedure
	set
		ExecTimeViolationCount = ExecTimeViolationCount + 1
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName and
		@ElapsedMilliseconds > @MaxProcedureExecTimeMilliseconds;

	update JobRunner.RunnableProcedure
	set
		IsEnabled = 0
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName and
		(
			ExecTimeViolationCount >= @MaxProcedureExecTimeViolationCount or
			@ReturnCode != 0
		);

	commit;
end try
begin catch
	if @@trancount != 0 rollback;
end catch


return 0;

go
