create procedure JobRunner.RunJobs
	@JobRunnerName sysname
as

set nocount, xact_abort on;
set deadlock_priority normal;
set lock_timeout -1;
set transaction isolation level read committed;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;

/* Fast path exit */
if sys.fn_hadr_is_primary_replica(db_name()) = 0 return 0;





/*
******************************
Control variables
******************************
*/
declare
	@StartDtmUtc datetime2(7) = getutcdate(),
	@LastConfigLoadDtmUtc datetime2(7) = null,
	@LastRunnableCheckDtmUtc datetime2(7) = null,
	@HasConfigRow bit = 0,
	@IsRunnable bit = 0,
	@Delay datetime,
	@Msg nvarchar(2000) = N'';



/*
******************************
Config variables
******************************
*/
declare
	@TargetJobRunnerExecTimeMilliseconds bigint,
	@BatchSize int,
	@DeadlockPriority int,
	@LockTimeoutMilliseconds int,
	@MaxSyncSecondaryCommitLatencyMilliseconds bigint,
	@MaxAsyncSecondaryCommitLatencyMilliseconds bigint,
	@MaxSyncSecondaryRedoQueueSize bigint,
	@MaxAsyncSecondaryRedoQueueSize bigint,
	@MaxProcedureExecutionTimeViolationCount int,
	@MaxProcedureExecutionFailureCount int,
	@MaxProcedureExecutionTimeMilliseconds bigint,
	@BatchSleepMilliseconds int,
	@FoundJobToExecute bit;

/*
******************************
Exception variables
******************************
*/
declare	@ErrorNumber int;

while @TargetJobRunnerExecTimeMilliseconds is null or datediff(millisecond, @StartDtmUtc, getutcdate()) < @TargetJobRunnerExecTimeMilliseconds
begin

	/* Refresh configuration once per second */
	if @LastConfigLoadDtmUtc is null or datediff(millisecond, @LastConfigLoadDtmUtc, getutcdate()) > 1000
	begin
		set @LastConfigLoadDtmUtc = getutcdate();
		set @HasConfigRow = 0;

		select
			@HasConfigRow = 1,
			@BatchSize = [BatchSize],
			@DeadlockPriority = DeadlockPriority,
			@LockTimeoutMilliseconds = LockTimeoutMilliseconds,
			@MaxSyncSecondaryCommitLatencyMilliseconds = MaxSyncSecondaryCommitLatencyMilliseconds,
			@MaxAsyncSecondaryCommitLatencyMilliseconds = MaxAsyncSecondaryCommitLatencyMilliseconds,
			@MaxSyncSecondaryRedoQueueSize = MaxSyncSecondaryRedoQueueSize,
			@MaxAsyncSecondaryRedoQueueSize = MaxAsyncSecondaryRedoQueueSize,
			@MaxProcedureExecutionTimeViolationCount = MaxProcedureExecutionTimeViolationCount,
			@MaxProcedureExecutionFailureCount = MaxProcedureExecutionFailureCount,
			@MaxProcedureExecutionTimeMilliseconds = MaxProcedureExecutionTimeMilliseconds,
			@BatchSleepMilliseconds = BatchSleepMilliseconds,
			@TargetJobRunnerExecTimeMilliseconds = TargetJobRunnerExecTimeMilliseconds
		from JobRunner.Config
		where JobRunnerName = @JobRunnerName;

		if @HasConfigRow = 0
		begin
			set @Msg =
				N'No configuration data for job runner named ''' + @JobRunnerName + N''' - ' +
				N'insert a configuration row into the table "JobRunner.Config" to resolve this error';

			throw 50000, @Msg, 1;
		end
	end

	/* Redetermine runnable status once per second */
	if @LastRunnableCheckDtmUtc is null or datediff(millisecond, @LastRunnableCheckDtmUtc, getutcdate()) > 1000
	begin
		set @LastRunnableCheckDtmUtc = getutcdate();
		set @IsRunnable = 0;

		exec JobRunner.GetRunnableStatus
			@JobRunnerName = @JobRunnerName,
			@MaxSyncSecondaryRedoQueueSize = @MaxSyncSecondaryRedoQueueSize,
			@MaxAsyncSecondaryRedoQueueSize = @MaxAsyncSecondaryRedoQueueSize,
			@MaxSyncSecondaryCommitLatencyMilliseconds = @MaxSyncSecondaryCommitLatencyMilliseconds,
			@MaxAsyncSecondaryCommitLatencyMilliseconds = @MaxAsyncSecondaryCommitLatencyMilliseconds,
			@IsRunnable = @IsRunnable output;

		if @IsRunnable = 0
		begin
			print N'Not runnable';
			return 0;
		end
	end

	begin try
		set @FoundJobToExecute = 0;

		exec JobRunner.RunNextJob
			@JobRunnerName = @JobRunnerName,
			@BatchSize = @BatchSize,
			@DeadlockPriority = @DeadlockPriority,
			@LockTimeoutMilliseconds = @LockTimeoutMilliseconds,
			@MaxProcedureExecutionTimeViolationCount = @MaxProcedureExecutionTimeViolationCount,
			@MaxProcedureExecutionFailureCount = @MaxProcedureExecutionFailureCount,
			@MaxProcedureExecutionTimeMilliseconds = @MaxProcedureExecutionTimeMilliseconds,
			@FoundJobToExecute = @FoundJobToExecute output;

		if @FoundJobToExecute = 0
		begin
			print N'No jobs to execute';
			return 0;
		end
	end try
	begin catch
		if @@trancount != 0 rollback;
		throw;
	end catch

	set @Delay = dateadd(millisecond, @BatchSleepMilliseconds, cast(0x0 as datetime));
	waitfor delay @Delay;
end

return 0;

go
