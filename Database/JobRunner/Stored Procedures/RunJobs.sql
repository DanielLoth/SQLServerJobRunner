create procedure JobRunner.RunJobs
	@JobRunnerName sysname
as

set nocount, xact_abort on;
set deadlock_priority low;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;



/*
******************************
Database primary node check
******************************
*/

declare
	@DatabaseName sysname = db_name(),
	@IsPrimary bit;

set @IsPrimary = sys.fn_hadr_is_primary_replica(@DatabaseName);
if @IsPrimary = 0 return 0;



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
	@Msg nvarchar(2000) = N'';



/*
******************************
Config variables
******************************
*/
declare
	@TargetJobRunnerExecTimeMilliseconds bigint,
	@NumRowsPerBatch int,
	@DeadlockPriority int,
	@LockTimeoutMilliseconds int,
	@MaxCommitLatencyMilliseconds bigint,
	@MaxRedoQueueSize bigint,
	@MaxProcedureExecTimeViolationCount int,
	@MaxProcedureExecTimeMilliseconds bigint,
	@BatchSleepTime char(12);



while datediff(millisecond, @StartDtmUtc, getutcdate()) < @TargetJobRunnerExecTimeMilliseconds
begin

	/* Refresh configuration once per second */
	if @LastConfigLoadDtmUtc is null or datediff(millisecond, @LastConfigLoadDtmUtc, getutcdate()) > 1000
	begin
		set @LastConfigLoadDtmUtc = getutcdate();

		select
			@HasConfigRow = 1,
			@NumRowsPerBatch = NumRowsPerBatch,
			@DeadlockPriority = DeadlockPriority,
			@LockTimeoutMilliseconds = LockTimeoutMilliseconds,
			@MaxCommitLatencyMilliseconds = MaxCommitLatencyMilliseconds,
			@MaxRedoQueueSize = MaxRedoQueueSize,
			@MaxProcedureExecTimeViolationCount = MaxProcedureExecTimeViolationCount,
			@MaxProcedureExecTimeMilliseconds = MaxProcedureExecTimeMilliseconds,
			@BatchSleepTime = BatchSleepTime
		from JobRunner.Config
		where JobRunnerName = @JobRunnerName;

		if @HasConfigRow = 0
		begin
			set @Msg =
				N'No configuration data for job runner named ''' + @JobRunnerName + ''' - ' +
				N'insert a configuration row into the table "JobRunner.Config" to resolve this error';

			throw 50000, @Msg, 1;
		end
	end

	/* Redetermine runnable status once per second */
	if @LastRunnableCheckDtmUtc is null or datediff(millisecond, @LastRunnableCheckDtmUtc, getutcdate()) > 1000
	begin
		set @LastRunnableCheckDtmUtc = getutcdate();

		exec JobRunner.GetRunnableStatus
			@JobRunnerName = @JobRunnerName,
			@DatabaseName = @DatabaseName,
			@IsPrimary = @IsPrimary,
			@MaxRedoQueueSize = @MaxRedoQueueSize,
			@MaxCommitLatencyMilliseconds = @MaxCommitLatencyMilliseconds,
			@IsRunnable = @IsRunnable output;

		if @IsRunnable = 0 return 0;
	end

	/* TODO: Run */

	waitfor delay @BatchSleepTime;
end



/*
********************
Set lock timeout
********************
*/

--if @LockTimeoutMilliseconds = -1 set lock_timeout -1; /* Wait forever */
--else if @LockTimeoutMilliseconds = 0 set lock_timeout 0; /* Don't wait at all */
--else if @LockTimeoutMilliseconds = 1000 set lock_timeout 1000;
--else if @LockTimeoutMilliseconds = 2000 set lock_timeout 2000;
--else if @LockTimeoutMilliseconds = 3000 set lock_timeout 3000;
--else if @LockTimeoutMilliseconds = 4000 set lock_timeout 4000;
--else if @LockTimeoutMilliseconds = 5000 set lock_timeout 5000;
--else if @LockTimeoutMilliseconds = 6000 set lock_timeout 6000;
--else if @LockTimeoutMilliseconds = 7000 set lock_timeout 7000;
--else if @LockTimeoutMilliseconds = 8000 set lock_timeout 8000;
--else if @LockTimeoutMilliseconds = 9000 set lock_timeout 9000;
--else if @LockTimeoutMilliseconds = 10000 set lock_timeout 10000;
--else if @LockTimeoutMilliseconds = 15000 set lock_timeout 15000;
--else if @LockTimeoutMilliseconds = 30000 set lock_timeout 30000;
--else if @LockTimeoutMilliseconds = 60000 set lock_timeout 60000;
--else if @LockTimeoutMilliseconds = 120000 set lock_timeout 120000;

go
