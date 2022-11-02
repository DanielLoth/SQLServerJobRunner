create procedure JobRunner.AddAgentJob
	@JobNamePrefix nvarchar(50),
	@CategoryName sysname,
	@ServerName sysname,
	@DatabaseName sysname,
	@OwnerLoginName sysname
as

set nocount, xact_abort on;

declare
	@JobId uniqueidentifier,
	@CategoryId int,
	@JobName sysname,
	@ReturnCode int;

declare	@Command nvarchar(2000) =
	N'if exists ' +
	N'(select 1 from sys.procedures where ' +
	N'object_schema_name(object_id) = N''JobRunner'' ' +
	N'and object_name(object_id) = N''RunJobs'') exec JobRunner.RunJobs;';


/*
********************
Validate
********************
*/

if len(@DatabaseName) + len(@JobNamePrefix) > 128 throw 50000, N'Job name is too long (more than 128 characters)', 1;
if not exists (select 1 from msdb.dbo.syscategories where [name] = @CategoryName) throw 50000, N'Category does not exist', 1;

set @JobName = @JobNamePrefix + @DatabaseName;
select @JobId = job_id from msdb.dbo.sysjobs where [name] = @JobName;

if exists (select 1 from msdb.dbo.sysjobsteps where job_id = @JobId and command = @Command)
begin
	print N'Job already exists with appropriate job step command';
	return 0;
end


/*
********************
Execute
********************
*/

begin try

	set transaction isolation level repeatable read;

	begin transaction;

	select @CategoryId = category_id from msdb.dbo.syscategories where [name] = @CategoryName;
	if @CategoryId is null throw 50000, N'Job category does not exist.', 1;

	select @JobId = job_id from msdb.dbo.sysjobs where [name] = @JobName;

	if @JobId is not null
	begin
		exec @ReturnCode = msdb.dbo.sp_delete_job @job_id = @JobId;
		if @@error != 0 or @ReturnCode != 0 throw 50000, N'Job already exists, but could not be deleted prior to attempted replacement', 1;
	end

	set @JobId = null;
	exec @ReturnCode = msdb.dbo.sp_add_job
		@job_name = @JobName,
		@enabled = 1,
		@description = N'Run background job stored procedures',
		@start_step_id = 1,
		@category_id = @CategoryId,
		@owner_login_name = @OwnerLoginName,
		@job_id = @JobId output;

	if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create job', 1;

	exec @ReturnCode = msdb.dbo.sp_add_jobstep
		@job_id = @JobId,
		@step_name = N'Run JobRunner.RunJobs procedure (if it exists)',
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

	exec @ReturnCode = msdb.dbo.sp_add_jobschedule
		@job_id = @JobId,
		@name = N'Run periodically (but only if not already running)',
		@enabled = 1,
		@freq_type = 4, /* 4 = Daily */
		@freq_interval = 1, /* 1 = Once (but unused in this case) */
		@freq_subday_type = 2, /* 2 = seconds */
		@freq_subday_interval = 20, /* Run every 20 seconds, if not already running */
		@freq_relative_interval = 0,
		@freq_recurrence_factor = 0,
		@active_start_date = 20220101,
		@active_end_date = 99991231,
		@active_start_time = 0,
		@active_end_time = 235959;

	if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create job schedule', 1;

	exec @ReturnCode = msdb.dbo.sp_add_jobserver
		@job_id = @JobId,
		@server_name = @ServerName;

	if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create jobserver', 1;

	commit;

end try
begin catch
	if @@trancount != 0 rollback;
	throw;
end catch

go
