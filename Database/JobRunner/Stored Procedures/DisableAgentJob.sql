create procedure JobRunner.DisableAgentJob
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

/* Fast path exit */
if not exists (select 1 from msdb.dbo.sysjobs where [name] = @JobRunnerName)
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
********************************************************************************
Execute

In essence, we're going to make short-and-sharp attempts to acquire exclusive
access to the metadata underlying the job. Done via the 'lock_timeout' option.
For attempts that time out waiting for the lock we simply retry them on a
subsequent iteration.

Given that this procedure is written to execute within the context of a release
via tool such as SqlPackage, we're also going to prioritise this transaction
over others. Done via the 'deadlock_priority' option.
After all, we don't want releases to fail for spurious reasons such as being a
deadlock victim.

Finally, transaction isolation level serializable is a must.
msdb.dbo.sp_update_job is more forgiving than one of its counterparts (namely
msdb.dbo.sp_stop_job, which emits errors that elude try-catch structured error
handling semantics), but we'll play it safe.
We'll also request an update lock from the outset to preclude deadlock risk due
to conversion of Shared locks to Exclusive locks.
********************************************************************************
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
				from msdb.dbo.sysjobs with (paglock, updlock)
				where [name] = @JobRunnerName and [enabled] = 1
			)
			begin
				exec msdb.dbo.sp_update_job @job_name = @JobRunnerName, @enabled = 0;
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
end try
begin catch
	if @@trancount != 0 rollback;
	throw;
end catch

return 0;
