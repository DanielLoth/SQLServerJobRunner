create procedure JobRunner.DeleteJob_internal
	@JobRunnerName sysname,
	@DeleteJobHistory bit
as

set nocount, xact_abort on;
set transaction isolation level read committed;
set deadlock_priority low;
set lock_timeout -1;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;

declare
	@i int = 0,
	@MaxRetryCount int = 50,
	@ReturnCode int = 0,
	@Msg nvarchar(200);

begin try
	while @i < @MaxRetryCount
	begin
		begin try
			set @i += 1;

			set @Msg = N'Attempting to remove SQL Agent job if it exists... (attempt ' + cast(@i as varchar(10)) + N')';
			print @Msg;

			begin transaction;

			if exists (
				select job_id
				from msdb.dbo.sysjobs with (updlock, paglock, serializable)
				where [name] = @JobRunnerName
			)
			begin
				print N'Job already exists... Deleting';

				exec @ReturnCode = msdb.dbo.sp_delete_job
					@job_name = @JobRunnerName,
					@delete_history = @DeleteJobHistory,
					@delete_unused_schedule = 0;

				if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not delete job', 1;
			end
			else
			begin
				print N'Job does not exist. Deletion not required.';
			end

			commit;

			return 0;
		end try
		begin catch
			if @@trancount != 0 rollback;
			if error_number() != 1205 throw; /* 1205 = deadlock */
		end catch
	end
end try
begin catch
	if @@trancount != 0 rollback;
end catch

return 0;
