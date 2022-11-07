create procedure JobRunner.AddOrUpdateSchedule_internal
	@ScheduleName sysname,
	@OwnerLoginName sysname,
	@Mode nvarchar(20),
	@RecurringSecondsInterval int
as

set nocount, xact_abort on;
set transaction isolation level read committed;
set deadlock_priority low;
set lock_timeout -1;

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;

declare
	@JobId uniqueidentifier,
	@FrequencyType int,
	@FrequencyInterval int,
	@FrequencySubDayType int,
	@FrequencySubDayInterval int,
	@ReturnCode int = 0,
	@i int = 0,
	@MaxRetryCount int = 50;

set @FrequencyType = case @Mode when N'CPUIdle' then 128 else 4 end; /* 128 = CPU Idle, 4 = daily */
set @FrequencyInterval = case @Mode when N'CPUIdle' then 0 else 1 end; /* 0 and 1 = unused */
set @FrequencySubDayType = case @Mode when N'CPUIdle' then 0 else 2 end; /* 0 = unused, 2 = seconds */
set @FrequencySubDayInterval = case @Mode when N'CPUIdle' then 0 else @RecurringSecondsInterval end;

begin try
	while @i < @MaxRetryCount
	begin
		begin try
			set @i += 1;

			print N'Checking for schedule...';

			begin transaction;
			
			if exists (
				select schedule_id
				from msdb.dbo.sysschedules with (updlock, paglock, serializable)
				where [name] = @ScheduleName
			)
			begin
				print N'Schedule exists... Updating';

				exec @ReturnCode = msdb.dbo.sp_update_schedule
					@name = @ScheduleName,
					@enabled = 1,
					@freq_type = @FrequencyType,
					@freq_interval = @FrequencyInterval,
					@freq_subday_type = @FrequencySubDayType,
					@freq_subday_interval = @FrequencySubDayInterval,
					@freq_relative_interval = 0,
					@freq_recurrence_factor = 0,
					@active_start_date = 20220101,
					@active_end_date = 99991231,
					@active_start_time = 0,
					@active_end_time = 235959;

				if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not update existing job schedule', 1;
			end
			else
			begin
				print N'Schedule does not exist... Adding';

				exec @ReturnCode = msdb.dbo.sp_add_schedule
					@schedule_name = @ScheduleName,
					@enabled = 1,
					@freq_type = @FrequencyType,
					@freq_interval = @FrequencyInterval,
					@freq_subday_type = @FrequencySubDayType,
					@freq_subday_interval = @FrequencySubDayInterval,
					@freq_relative_interval = 0,
					@freq_recurrence_factor = 0,
					@active_start_date = 20220101,
					@active_end_date = 99991231,
					@active_start_time = 0,
					@active_end_time = 235959,
					@owner_login_name = @OwnerLoginName;

				if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not update existing job schedule', 1;
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
