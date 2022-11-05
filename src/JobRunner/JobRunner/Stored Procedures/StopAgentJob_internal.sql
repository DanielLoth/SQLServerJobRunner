create procedure JobRunner.StopAgentJob_internal
	@JobRunnerName sysname
as

set nocount, xact_abort on;
set transaction isolation level read committed;

/*
********************
Validate
********************
*/
if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;

declare @JobId uniqueidentifier = (select job_id from msdb.dbo.sysjobs where [name] = @JobRunnerName);

/* Fast path exit */
if @JobId is null return 0;

/* Fast path exit */
if not exists (
	select 1
	from msdb.dbo.sysjobactivity
	where
		job_id = @JobId and
		start_execution_date is not null and
		stop_execution_date is null
)
begin
	return 0;
end


declare
	@i int = 0,
	@MaxRetryCount int = 100,
	@IterationsBeforeSleepCount int = 10,
	@SleepTimeMilliseconds int = 1000;

declare @Delay datetime = dateadd(millisecond, @SleepTimeMilliseconds, cast(0x0 as datetime));


/*
********************
Execute
********************
*/

set lock_timeout 1000;
set deadlock_priority high;
set transaction isolation level serializable;

begin try
	while @i < @MaxRetryCount
	begin
		begin try
			set @i += 1;

			begin transaction;

			if exists (
				select *
				from msdb.dbo.sysjobactivity with (paglock, updlock)
				where
					job_id = @JobId and
					start_execution_date is not null and
					stop_execution_date is null
			)
			begin
				exec msdb.dbo.sp_stop_job @job_name = @JobRunnerName;
				commit;
			end
			else
			begin
				rollback;
				break;
			end
		end try
		begin catch
			if @@trancount != 0 rollback;

			/* Swallow exceptions. We'll retry */
		end catch

		if @i % @IterationsBeforeSleepCount = 0
		begin
			waitfor delay @Delay;
		end
	end

	/* Final check. */
	set lock_timeout -1;
	if exists (
		select 1
		from msdb.dbo.sysjobactivity
		where
			job_id = @JobId and
			start_execution_date is not null and
			stop_execution_date is null
	)
	begin;
		throw 50000, N'Could not stop job. The job has been left in the disabled state. Re-execute this procedure to try again.', 1;
	end

end try
begin catch
	if @@trancount != 0 rollback;
	throw;
end catch

return 0;
