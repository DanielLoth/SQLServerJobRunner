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
	@ExceptionWasThrown bit = 0,
	@ErrorNumber int,
	@ErrorMessage nvarchar(4000),
	@ErrorLine int,
	@ErrorProcedure sysname,
	@ErrorSeverity int,
	@ErrorState int,
	@Done bit = 0,
	@Msg nvarchar(500);

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
order by LastExecutedDtmUtc;

if @FoundJobToExecute = 0 return 0;


begin try
	exec sp_executesql @stmt = @CreateOrAlterProcedureQuery;
end try
begin catch

	/*
	Note: This mode of failure normally shouldn't happen.
	It'd only be due to programmer error (a bug) in the wrapper
	procedure generation code.
	*/

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
		/* Skip disabling just in case it's something intermittent */
		/* IsEnabled = 0, */
		FailedWhileCreatingWrapperProcedure = 1,
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

	throw;

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


set @StartDtmUtc = getutcdate();

begin try
	if @@trancount != 0
	begin
		set @Msg =
			N'Open transaction detected before invoking job. ' +
			N'This should not happen, and most likely indicates a programming error (bug)' +
			N'within the "JobRunner.RunNextJob" procedure';

		throw 50000, @Msg, 1;
	end

	exec @ReturnCode = [#JobRunnerWrapper]
		@BatchSize = @BatchSize,
		@Done = @Done output;

	/*
	Technically should not happen.
	SQL Server will raise exception with error number 266 on its own.
	*/
	if @@trancount != 0
	begin
		set @Msg = N'Open transaction detected after invoking job. Jobs must commit or rollback all transactions.';
		throw 50000, @Msg, 1;
	end
	
	if @ReturnCode != 0
	begin
		set @Msg = N'Non-zero return code (' + cast(@ReturnCode as varchar(20)) + N')'; 
		throw 50000, @Msg, 1;
	end

	set @Done = isnull(@Done, 0);
end try
begin catch
	set deadlock_priority low;
	set lock_timeout -1;

	if @@trancount != 0 rollback;

	select
		@ExceptionWasThrown = 1,
		@EndDtmUtc = getutcdate(),
		@ElapsedMilliseconds = datediff(millisecond, @StartDtmUtc, @EndDtmUtc),
		@Done = 0,
		@ErrorNumber = error_number(),
		@ErrorMessage = error_message(),
		@ErrorLine = error_line(),
		@ErrorProcedure = error_procedure(),
		@ErrorSeverity = error_severity(),
		@ErrorState = error_state();

end catch

set @EndDtmUtc = getutcdate();
set @ElapsedMilliseconds = datediff(millisecond, @StartDtmUtc, @EndDtmUtc);

begin try
	begin transaction;

	/* Update columns that should be updated irrespective of success / failure */
	update JobRunner.RunnableProcedure
	set
		LastExecutedDtmUtc = @EndDtmUtc,
		LastElapsedMilliseconds = @ElapsedMilliseconds,
		AttemptedExecutionCount += 1,
		FailedWhileCreatingWrapperProcedure = 0
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName;

	/* Update columns that should be updated on failure */
	update JobRunner.RunnableProcedure
	set
		IsEnabled = 0,
		FailedExecutionCount += 1,
		ErrorNumber = @ErrorNumber,
		ErrorMessage = @ErrorMessage,
		ErrorLine = @ErrorLine,
		ErrorProcedure = @ErrorProcedure,
		ErrorSeverity = @ErrorSeverity,
		ErrorState = @ErrorState
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName and
		@ExceptionWasThrown = 1;

	/* Update columns that should be updated on success */
	update JobRunner.RunnableProcedure
	set
		SuccessfulExecutionCount += 1,
		HasIndicatedDone = @Done,
		DoneDtmUtc =
			case
				when @Done = 1 then @EndDtmUtc
				else '9999-12-31'
			end
	where
		JobRunnerName = @JobRunnerName and
		SchemaName = @SchemaName and
		ProcedureName = @ProcedureName and
		@ExceptionWasThrown = 0;

	update JobRunner.RunnableProcedure
	set
		ExecTimeViolationCount += 1
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
		ExecTimeViolationCount >= @MaxProcedureExecTimeViolationCount;

	commit;
end try
begin catch
	if @@trancount != 0 rollback;
end catch


return 0;

go
