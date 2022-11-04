create procedure JobRunner.AddAgentJob
	@JobRunnerName sysname,
	@CategoryName sysname,
	@ServerName sysname,
	@DatabaseName sysname,
	@OwnerLoginName sysname,
	@Mode varchar(20),
	@RecurringSecondsInterval int = -1
as

set nocount, xact_abort on;
set transaction isolation level read committed;

declare
	@JobId uniqueidentifier,
	@FrequencyType int,
	@FrequencyInterval int,
	@FrequencySubDayType int,
	@FrequencySubDayInterval int,
	@ScheduleName sysname = @JobRunnerName,
	@JobStepName sysname = N'Run JobRunner.RunJobs procedure',
	@JobDescription nvarchar(512) = N'Run background job stored procedures',
	@ReturnCode int,
	@i int;

declare	@Command nvarchar(2000) =
	N'if exists ' +
	N'(select 1 from sys.procedures where ' +
	N'object_schema_name(object_id) = N''JobRunner'' ' +
	N'and object_name(object_id) = N''RunJobs'') ' +
	N'exec JobRunner.RunJobs @JobRunnerName = ''' + @JobRunnerName + N''';';


/*
********************
Validate
********************
*/

if @@trancount != 0 throw 50000, N'Running within an open transaction is not allowed', 1;
if not exists (select 1 from msdb.dbo.syscategories where [name] = @CategoryName) throw 50000, N'Category does not exist', 1;
if @Mode not in ('CPUIdle', 'Recurring') throw 50000, N'Invalid @Mode. Use ''CPUIdle'' or ''Recurring''', 1;
if @Mode = 'Recurring' and @RecurringSecondsInterval < 1 throw 50000, N'Invalid @RecurringSecondsInterval - specify a value greater than 0', 1;

set @FrequencyType = case @Mode when 'CPUIdle' then 128 else 4 end; /* 128 = CPU Idle, 4 = daily */
set @FrequencyInterval = case @Mode when 'CPUIdle' then 0 else 1 end; /* 0 and 1 = unused */
set @FrequencySubDayType = case @Mode when 'CPUIdle' then 0 else 2 end; /* 0 = unused, 2 = seconds */
set @FrequencySubDayInterval = case @Mode when 'CPUIdle' then 0 else @RecurringSecondsInterval end;


/*
********************
Execute
********************
*/

begin try

	exec JobRunner.DisableAgentJob @JobRunnerName = @JobRunnerName;
	exec JobRunner.StopAgentJob @JobRunnerName = @JobRunnerName;

	if exists (select 1 from msdb.dbo.sysjobs where [name] = @JobRunnerName)
	begin
		if exists (
			select 1
			from msdb.dbo.sysjobactivity
			where
				job_id = (select job_id from msdb.dbo.sysjobs where [name] = @JobRunnerName) and
				start_execution_date is not null and
				stop_execution_date is null
		)
		begin;
			throw 50000, N'Could not stop job. The job has been left in the disabled state. Re-execute this procedure to try again.', 1;
		end

		exec @ReturnCode = msdb.dbo.sp_update_job
			@job_name = @JobRunnerName,
			@description = @JobDescription,
			@start_step_id = 1,
			@category_name = @CategoryName,
			@owner_login_name = @OwnerLoginName;

		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not update existing job', 1;

		exec @ReturnCode = msdb.dbo.sp_update_jobstep
			@job_name = @JobRunnerName,
			@step_name = @JobStepName,
			@step_id = 1,
			@cmdexec_success_code = 0,
			@on_success_action = 1,
			@on_success_step_id = 0,
			@on_fail_action = 2,
			@on_fail_step_id = 0,
			@retry_attempts = 0,
			@retry_interval = 0,
			@os_run_priority = 0,
			@subsystem = N'TSQL',
			@command = @Command,
			@database_name = @DatabaseName,
			@flags = 0;

		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not update existing jobstep', 1;

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

		exec @ReturnCode = msdb.dbo.sp_update_job @job_name = @JobRunnerName, @enabled = 1;
		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not re-enable existing job', 1;
	end
	else
	begin
		exec @ReturnCode = msdb.dbo.sp_add_job
			@job_name = @JobRunnerName,
			@enabled = 0,
			@description = @JobDescription,
			@start_step_id = 1,
			@category_name = @CategoryName,
			@owner_login_name = @OwnerLoginName;

		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create job', 1;

		exec @ReturnCode = msdb.dbo.sp_add_jobstep
			@job_name = @JobRunnerName,
			@step_name = @JobStepName,
			@step_id = 1,
			@cmdexec_success_code = 0,
			@on_success_action = 1,
			@on_success_step_id = 0,
			@on_fail_action = 2,
			@on_fail_step_id = 0,
			@retry_attempts = 0,
			@retry_interval = 0,
			@os_run_priority = 0,
			@subsystem = N'TSQL',
			@command = @Command,
			@database_name = @DatabaseName,
			@flags = 0;

		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create job step', 1;

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

		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create schedule', 1;

		exec @ReturnCode = msdb.dbo.sp_attach_schedule
			@job_name = @JobRunnerName,
			@schedule_name = @ScheduleName

		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not attach schedule to job', 1;

		exec @ReturnCode = msdb.dbo.sp_add_jobserver
			@job_name = @JobRunnerName,
			@server_name = @ServerName;

		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create jobserver', 1;

		exec @ReturnCode = msdb.dbo.sp_update_job @job_name = @JobRunnerName, @enabled = 1;
		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not enable job after creating it', 1;
	end

end try
begin catch
	if @@trancount != 0 rollback;
	throw;
end catch

go
