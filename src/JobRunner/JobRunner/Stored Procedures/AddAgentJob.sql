create procedure JobRunner.AddAgentJob
	@JobRunnerName sysname,
	@CategoryName sysname,
	@ServerName sysname,
	@DatabaseName sysname,
	@OwnerLoginName sysname,
	@Mode nvarchar(20),
	@RecurringSecondsInterval int = -1,
	@DeleteJobHistory bit = 0
as

set nocount, xact_abort on;
set transaction isolation level read committed;
set deadlock_priority low;
set lock_timeout -1;

declare
	@JobId uniqueidentifier,
	@ScheduleName sysname = @JobRunnerName,
	@JobStepName sysname = N'Run JobRunner.RunJobs procedure',
	@JobDescription nvarchar(512) = N'Run background job stored procedures',
	@i int = 0,
	@MaxRetryCount int = 50,
	@ReturnCode int,
	@Msg nvarchar(200);

declare	@Command nvarchar(2000) =
    N'use ' + @DatabaseName + N'; ' +
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
if @Mode not in (N'CPUIdle', N'Recurring') throw 50000, N'Invalid @Mode. Use ''CPUIdle'' or ''Recurring''', 1;
if @Mode = N'Recurring' and @RecurringSecondsInterval < 1 throw 50000, N'Invalid @RecurringSecondsInterval - specify a value greater than 0', 1;


/*
********************
Execute
********************
*/

begin try
	while @i < @MaxRetryCount
	begin
		begin try
			set @i += 1;

			set @Msg = N'Attempting to add SQL Agent job... (attempt ' + cast(@i as nvarchar(10)) + N')';
			print @Msg;

			exec JobRunner.DeleteJob_internal
				@JobRunnerName = @JobRunnerName,
				@DeleteJobHistory = @DeleteJobHistory;

			exec JobRunner.AddOrUpdateSchedule_internal
				@ScheduleName = @ScheduleName,
				@OwnerLoginName = @OwnerLoginName,
				@Mode = @Mode,
				@RecurringSecondsInterval = @RecurringSecondsInterval;

			begin transaction;

			if exists (
				select job_id
				from msdb.dbo.sysjobs with (updlock, paglock, serializable)
				where [name] = @JobRunnerName
			)
			begin
				rollback;
				print N'Job re-discovered after supposedly successful deletion. Re-attempting.';
				continue;
			end

			print N'Adding job...';

			exec @ReturnCode = msdb.dbo.sp_add_job
				@job_name = @JobRunnerName,
				@enabled = 0,
				@description = @JobDescription,
				@start_step_id = 1,
				@category_name = @CategoryName,
				@owner_login_name = @OwnerLoginName;

			if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create job', 1;

			print N'Adding jobstep...';

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
				@database_name = N'master',
				@flags = 0;

			if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create job step', 1;

			print N'Attaching schedule...';

			exec @ReturnCode = msdb.dbo.sp_attach_schedule @job_name = @JobRunnerName, @schedule_name = @ScheduleName
			if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not attach schedule to job', 1;

			print N'Creating job server...';

			exec @ReturnCode = msdb.dbo.sp_add_jobserver @job_name = @JobRunnerName, @server_name = @ServerName;
			if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not create jobserver', 1;

			print N'Enabling job...';

			exec @ReturnCode = msdb.dbo.sp_update_job @job_name = @JobRunnerName, @enabled = 1;
			if @@error != 0 or @ReturnCode != 0 throw 50000, N'Could not enable job after creating it', 1;

			print N'Done. SQL Agent job created and enabled.';

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
	throw;
end catch

go
